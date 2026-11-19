#import "HaogeTouchFlowPanel.h"
#import "HaogeTouchFlowPanelModel.h"
#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import <QuartzCore/QuartzCore.h>

static BOOL haoge_touchflow_panelLocked(void) {
    Class cls=NSClassFromString(@"SBLockScreenManager"); SEL shared=NSSelectorFromString(@"sharedInstance");
    id manager=[cls respondsToSelector:shared]?((id (*)(id,SEL))objc_msgSend)(cls,shared):nil;
    for (NSString *name in @[@"isUILocked",@"isLocked"]) {
        SEL sel=NSSelectorFromString(name);
        if ([manager respondsToSelector:sel]) return ((BOOL (*)(id,SEL))objc_msgSend)(manager,sel);
    }
    return YES;
}
static id haoge_touchflow_panelObject(id target,NSString *selectorName) {
    SEL selector=NSSelectorFromString(selectorName);
    return [target respondsToSelector:selector]?((id (*)(id,SEL))objc_msgSend)(target,selector):nil;
}
static BOOL haoge_touchflow_isApplicationScene(UIWindowScene *scene) {
    // ForegroundActive is zero. Explicitly reject nil before inspecting scalar properties.
    if (![scene isKindOfClass:[UIWindowScene class]] || scene.activationState == UISceneActivationStateUnattached) return NO;
    NSString *role = scene.session.role;
    return [role isEqualToString:UIWindowSceneSessionRoleApplication] || [role hasSuffix:@"Application"];
}

static UIWindowScene *haoge_touchflow_applicationScene(UIWindowScene *sourceScene, UIWindow *sourceWindow) {
    // The gesture recognizer is attached to the visible system window. Prefer its
    // foreground scene, otherwise an overlay is put on SpringBoard's inactive
    // home scene and stops receiving touches while a third-party app is active.
    if (haoge_touchflow_isApplicationScene(sourceWindow.windowScene) && sourceWindow.windowScene.activationState==UISceneActivationStateForegroundActive) return sourceWindow.windowScene;
    if (haoge_touchflow_isApplicationScene(sourceScene) && sourceScene.activationState==UISceneActivationStateForegroundActive) return sourceScene;
    UIApplication *application = UIApplication.sharedApplication;
    NSArray *windows = haoge_touchflow_panelObject(application, @"windows");
    for (UIWindow *window in windows) {
        if (window.isKeyWindow && !window.hidden && haoge_touchflow_isApplicationScene(window.windowScene) && window.windowScene.activationState==UISceneActivationStateForegroundActive) return window.windowScene;
    }
    Class homeWindowClass = NSClassFromString(@"SBHomeScreenWindow");
    if (homeWindowClass) {
        for (UIWindow *window in windows) {
            if ([window isKindOfClass:homeWindowClass] && !window.hidden && haoge_touchflow_isApplicationScene(window.windowScene) && window.windowScene.activationState==UISceneActivationStateForegroundActive) return window.windowScene;
        }
    }

    UIWindowScene *active=nil,*inactive=nil,*springboard=nil;
    for(UIScene *candidate in application.connectedScenes){
        if(![candidate isKindOfClass:UIWindowScene.class])continue;UIWindowScene *candidateScene=(UIWindowScene *)candidate;
        if(!haoge_touchflow_isApplicationScene(candidateScene))continue;
        if([candidateScene.session.persistentIdentifier isEqualToString:@"com.apple.springboard"])springboard=candidateScene;
        if(!active&&candidateScene.activationState==UISceneActivationStateForegroundActive)active=candidateScene;
        if(!inactive&&candidateScene.activationState==UISceneActivationStateForegroundInactive)inactive=candidateScene;
    }
    return active?:springboard?:inactive;
}
@interface HaogeTouchFlowPanelWindow : UIWindow
@end
@implementation HaogeTouchFlowPanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
@end
// The original OneStepX panel window subclasses SpringBoard's SBFTouchPassThroughWindow,
// which keeps receiving touches even while a third-party app is foreground. A plain
// UIWindow owned by the SpringBoard process stops being hit-tested once an app is
// active, so outside taps never reach the dimmer inside apps. Recreate that subclass
// at runtime because the private class is not available to link.
static BOOL haoge_touchflow_panelWindowCanKey(id self, SEL _cmd) { (void)self;(void)_cmd;return YES; }
static UIView *haoge_touchflow_panelWindowHitTest(id self, SEL _cmd, CGPoint point, UIEvent *event) {
    UIWindow *window=(UIWindow *)self;
    if (window.hidden || window.alpha<=0.01 || !window.userInteractionEnabled) return nil;
    UIView *rootView=window.rootViewController.view;
    if (!rootView) return nil;
    return [rootView hitTest:[rootView convertPoint:point fromView:window] withEvent:event];
}
static Class haoge_touchflow_panelWindowClass(void) {
    static Class cls;static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class base=NSClassFromString(@"SBFTouchPassThroughWindow");
        if (base && [base isSubclassOfClass:[UIWindow class]]) {
            Class dynamic=objc_allocateClassPair(base,"HaogeTouchFlowPanelPassThroughWindow",0);
            if (dynamic) {
                Method hit=class_getInstanceMethod([UIView class],@selector(hitTest:withEvent:));
                class_addMethod(dynamic,@selector(hitTest:withEvent:),(IMP)haoge_touchflow_panelWindowHitTest,
                    hit?method_getTypeEncoding(hit):"@24@0:8{CGPoint=dd}16@32");
                class_addMethod(dynamic,@selector(canBecomeKeyWindow),(IMP)haoge_touchflow_panelWindowCanKey,"B@:");
                objc_registerClassPair(dynamic);cls=dynamic;
            }
        }
        if (!cls) cls=[HaogeTouchFlowPanelWindow class];
    });
    return cls;
}

@interface HaogeTouchFlowPanelController : UIViewController <UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *haoge_touchflow_items;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_settings;
@property (nonatomic, copy) void (^haoge_touchflow_selection)(NSDictionary *);
@property (nonatomic, copy) void (^haoge_touchflow_close)(void);
@property (nonatomic, strong) UIControl *haoge_touchflow_dimmer;
@property (nonatomic, strong) UIVisualEffectView *haoge_touchflow_sheet;
@property (nonatomic, strong) UIScrollView *haoge_touchflow_scroll;
@property (nonatomic, strong) NSMutableArray<UIButton *> *haoge_touchflow_buttons;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *haoge_touchflow_icons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *haoge_touchflow_labels;
@property (nonatomic, assign) BOOL haoge_touchflow_shown;
- (void)haoge_touchflow_animateIn;
- (BOOL)haoge_touchflow_shouldDismissForPoint:(CGPoint)point;
- (void)haoge_touchflow_outsideTapped:(UITapGestureRecognizer *)gesture;
@end
@implementation HaogeTouchFlowPanelController
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];self.view.backgroundColor=UIColor.clearColor;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSDictionary *settings=self.haoge_touchflow_settings;
    NSString *appearance=[settings[@"panelAppearance"] isKindOfClass:[NSString class]]?settings[@"panelAppearance"]:@"system";
    if ([appearance isEqual:@"light"]) self.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;
    else if ([appearance isEqual:@"dark"]) self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.haoge_touchflow_dimmer=[[UIControl alloc] initWithFrame:self.view.bounds];
    self.haoge_touchflow_dimmer.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:haoge_touchflow_panelNumber(settings,@"panelDimAlpha")];
    [self.haoge_touchflow_dimmer addTarget:self action:@selector(haoge_touchflow_closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.haoge_touchflow_dimmer];
    self.haoge_touchflow_sheet=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    self.haoge_touchflow_sheet.clipsToBounds=YES;self.haoge_touchflow_sheet.layer.cornerCurve=kCACornerCurveContinuous;
    self.haoge_touchflow_sheet.layer.cornerRadius=haoge_touchflow_panelNumber(settings,@"panelCornerRadius");
    [self.view addSubview:self.haoge_touchflow_sheet];
    UIView *content=self.haoge_touchflow_sheet.contentView;
    self.haoge_touchflow_scroll=[UIScrollView new];self.haoge_touchflow_scroll.alwaysBounceVertical=NO;
    self.haoge_touchflow_scroll.scrollEnabled=NO;self.haoge_touchflow_scroll.bounces=NO;
    self.haoge_touchflow_scroll.showsVerticalScrollIndicator=NO;
    self.haoge_touchflow_scroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
    [content addSubview:self.haoge_touchflow_scroll];
    self.haoge_touchflow_buttons=[NSMutableArray array];self.haoge_touchflow_icons=[NSMutableArray array];self.haoge_touchflow_labels=[NSMutableArray array];
    [self.haoge_touchflow_items enumerateObjectsUsingBlock:^(NSDictionary *item,NSUInteger index,BOOL *stop) {
        (void)stop;UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];button.tag=(NSInteger)index;
        button.accessibilityLabel=haoge_touchflow_panelItemTitle(item);
        [button addTarget:self action:@selector(haoge_touchflow_itemPressed:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *icon=[UIImageView new];NSString *symbol=[item[@"symbol"] isKindOfClass:[NSString class]]?item[@"symbol"]:nil;
        icon.image=[UIImage systemImageNamed:symbol.length?symbol:haoge_touchflow_actionSymbol(item[@"action"])];
        if (!icon.image) icon.image=[UIImage systemImageNamed:haoge_touchflow_actionSymbol(item[@"action"])];
        icon.contentMode=UIViewContentModeScaleAspectFit;icon.tintColor=UIColor.systemBlueColor;
        icon.backgroundColor=UIColor.clearColor;icon.clipsToBounds=NO;
        UILabel *label=[UILabel new];label.text=haoge_touchflow_panelItemTitle(item);label.textColor=UIColor.labelColor;
        label.font=[UIFont systemFontOfSize:haoge_touchflow_panelNumber(settings,@"panelTextSize")];label.numberOfLines=2;
        label.textAlignment=NSTextAlignmentCenter;label.adjustsFontSizeToFitWidth=YES;label.minimumScaleFactor=0.75;
        label.hidden=!haoge_touchflow_panelFlag(settings,@"panelShowsLabels",YES);
        icon.isAccessibilityElement=NO;label.isAccessibilityElement=NO;
        [button addSubview:icon];[button addSubview:label];[self.haoge_touchflow_scroll addSubview:button];
        [self.haoge_touchflow_buttons addObject:button];[self.haoge_touchflow_icons addObject:icon];[self.haoge_touchflow_labels addObject:label];
    }];
    UITapGestureRecognizer *outsideTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_outsideTapped:)];
    outsideTap.delegate=self;outsideTap.cancelsTouchesInView=NO;[self.view addGestureRecognizer:outsideTap];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];CGRect bounds=self.view.bounds;
    self.haoge_touchflow_dimmer.frame=bounds;
    CGFloat margin=12,width=MAX(1,CGRectGetWidth(bounds)-2*margin);
    CGFloat top=MAX(self.view.safeAreaInsets.top,20);
    CGFloat configuredRow=haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelRowHeight");
    CGFloat columnsCount=haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelColumns");
    NSInteger columns=(NSInteger)columnsCount;
    NSInteger rows=(self.haoge_touchflow_buttons.count+(NSUInteger)columns-1)/(NSUInteger)columns;
    // Fixed grid, never scrolling: grow the sheet until every row is visible, capped by the screen.
    CGFloat height=MIN(MAX(150,CGRectGetHeight(bounds)-top-20),MAX(haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelHeight"),rows*configuredRow+24));
    self.haoge_touchflow_sheet.bounds=CGRectMake(0,0,width,height);
    self.haoge_touchflow_sheet.center=CGPointMake(CGRectGetMidX(bounds),CGRectGetHeight(bounds)-height*0.5-8);
    CGFloat usable=MAX(1,height-24);self.haoge_touchflow_scroll.frame=CGRectMake(8,12,MAX(1,width-16),usable);
    CGFloat cellWidth=CGRectGetWidth(self.haoge_touchflow_scroll.bounds)/(CGFloat)columns;
    CGFloat rowHeight=MIN(configuredRow,usable/(CGFloat)MAX(1,rows));
    CGFloat gridHeight=rowHeight*(CGFloat)rows;
    CGFloat gridTop=MAX(0,(usable-gridHeight)*0.5);
    CGFloat size=MIN(haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelIconSize"),MAX(18,cellWidth-12));
    size=MIN(size,MAX(16,rowHeight-22));
    [self.haoge_touchflow_buttons enumerateObjectsUsingBlock:^(UIButton *button,NSUInteger index,BOOL *stop) {
        (void)stop;button.frame=CGRectMake((index%(NSUInteger)columns)*cellWidth,gridTop+(index/(NSUInteger)columns)*rowHeight,cellWidth,rowHeight);
        UIImageView *icon=self.haoge_touchflow_icons[index];icon.frame=CGRectMake((cellWidth-size)/2,4,size,size);
        icon.layer.cornerRadius=0;
        icon.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:size*0.53 weight:UIImageSymbolWeightMedium];
        self.haoge_touchflow_labels[index].frame=CGRectMake(3,size+8,MAX(1,cellWidth-6),MAX(1,rowHeight-size-10));
    }];
    self.haoge_touchflow_scroll.contentSize=CGSizeMake(CGRectGetWidth(self.haoge_touchflow_scroll.bounds),usable);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"[TouchFlowPanel] controller appeared window=%@ hidden=%d frame=%@",self.view.window,self.view.window.hidden,NSStringFromCGRect(self.view.frame));
    [self haoge_touchflow_animateIn];
}
- (void)haoge_touchflow_animateIn {
    if (self.haoge_touchflow_shown || !self.view.window || self.view.window.hidden) return;
    self.haoge_touchflow_shown = YES;
    [self.view layoutIfNeeded];self.haoge_touchflow_dimmer.alpha=0;
    self.haoge_touchflow_sheet.transform=CGAffineTransformMakeTranslation(0,CGRectGetHeight(self.haoge_touchflow_sheet.bounds)+30);
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled()?0.01:haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelOpenDuration") delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.haoge_touchflow_sheet.transform=CGAffineTransformIdentity;self.haoge_touchflow_dimmer.alpha=1;
    } completion:nil];self.haoge_touchflow_shown=YES;
}
- (void)haoge_touchflow_closePressed { if (self.haoge_touchflow_close) self.haoge_touchflow_close(); }
- (void)haoge_touchflow_itemPressed:(UIButton *)button {
    if (button.tag<0 || (NSUInteger)button.tag>=self.haoge_touchflow_items.count) return;
    if (self.haoge_touchflow_selection) self.haoge_touchflow_selection(self.haoge_touchflow_items[(NSUInteger)button.tag]);
}
- (BOOL)haoge_touchflow_shouldDismissForPoint:(CGPoint)point {
    return !CGRectContainsPoint(self.haoge_touchflow_sheet.frame,point);
}
- (void)haoge_touchflow_handleOutsideTapAtPoint:(CGPoint)point {
    if ([self haoge_touchflow_shouldDismissForPoint:point]) [self haoge_touchflow_closePressed];
}
- (void)haoge_touchflow_outsideTapped:(UITapGestureRecognizer *)gesture {
    [self haoge_touchflow_handleOutsideTapAtPoint:[gesture locationInView:self.view]];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    (void)gesture;
    CGPoint point=[touch locationInView:self.view];
    return [self haoge_touchflow_shouldDismissForPoint:point];
}
@end

@interface HaogeTouchFlowPanel ()
@property (nonatomic, strong) UIWindow *haoge_touchflow_window;
@property (nonatomic, strong) HaogeTouchFlowPanelController *haoge_touchflow_controller;
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, assign) BOOL haoge_touchflow_dismissing;
@property (nonatomic, assign) NSUInteger haoge_touchflow_generation;
@property (nonatomic, assign) BOOL haoge_touchflow_cancelledAction;
- (void)haoge_touchflow_cancelForNotification:(NSNotification *)note;
@end
static void haoge_touchflow_panelLockChanged(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    (void)center;(void)name;(void)object;(void)info;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(__bridge HaogeTouchFlowPanel *)observer haoge_touchflow_cancelForNotification:nil];
    });
}
@implementation HaogeTouchFlowPanel
+ (instancetype)haoge_touchflow_shared {
    static HaogeTouchFlowPanel *panel;static dispatch_once_t once;
    dispatch_once(&once, ^{ panel=[self new]; });return panel;
}
- (instancetype)init {
    if ((self=[super init])) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_cancelForNotification:)
            name:HaogeTouchFlowPreferencesChanged object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_cancelForNotification:)
            name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_cancelForNotification:)
            name:UISceneWillDeactivateNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_cancelForNotification:)
            name:UISceneDidDisconnectNotification object:nil];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge const void *)self,
            haoge_touchflow_panelLockChanged,CFSTR("com.apple.springboard.lockstate"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    }return self;
}
- (void)haoge_touchflow_cancelForNotification:(NSNotification *)note {
    if ([note.object isKindOfClass:[UIWindowScene class]] && note.object!=self.haoge_touchflow_window.windowScene) return;
    self.haoge_touchflow_cancelledAction=YES;
    [self haoge_touchflow_dismiss];
}
- (BOOL)haoge_touchflow_isVisible { return self.haoge_touchflow_window!=nil; }
- (UIWindow *)haoge_touchflow_panelWindow { return self.haoge_touchflow_window; }
- (void)haoge_touchflow_showBinding:(NSDictionary *)binding trigger:(NSString *)trigger scene:(UIWindowScene *)scene sourceWindow:(UIWindow *)sourceWindow {
    NSAssert(NSThread.isMainThread,@"Panel UI must run on main");
    NSDictionary *snapshot=[[HaogeTouchFlowConfig haoge_touchflow_shared] haoge_touchflow_snapshot];
    NSDictionary *currentBinding=haoge_touchflow_binding(snapshot,trigger);
    NSLog(@"[TouchFlowPanel] request trigger=%@ enabled=%d mode=%@ count=%lu source=%@ sourceScene=%@ sourceRole=%@ sourceState=%ld",
        trigger,[[snapshot objectForKey:@"enabled"] boolValue],currentBinding[@"mode"],
        (unsigned long)haoge_touchflow_panelItems(currentBinding[@"panelItems"]).count,
        NSStringFromClass(sourceWindow.class),sourceWindow.windowScene.session.persistentIdentifier,
        sourceWindow.windowScene.session.role,(long)sourceWindow.windowScene.activationState);
    if (self.haoge_touchflow_dismissing) { NSLog(@"[TouchFlowPanel] drop: dismissing"); return; }
    if (self.haoge_touchflow_window) { NSLog(@"[TouchFlowPanel] close previous window"); [self haoge_touchflow_dismiss];return; }
    HaogeTouchFlowConfig *config=[HaogeTouchFlowConfig haoge_touchflow_shared];
    if (![config haoge_touchflow_isEnabled]) { NSLog(@"[TouchFlowPanel] drop: global disabled"); return; }
    if (haoge_touchflow_panelLocked()) { NSLog(@"[TouchFlowPanel] drop: device locked"); return; }
    if (!haoge_touchflow_hasPanelMode(currentBinding)) { NSLog(@"[TouchFlowPanel] drop: mode=%@",currentBinding[@"mode"]); return; }
    if (!haoge_touchflow_bindingEnabled(currentBinding)) { NSLog(@"[TouchFlowPanel] drop: binding disabled or empty"); return; }
    scene = haoge_touchflow_applicationScene(scene, sourceWindow);
    if (!scene) { NSLog(@"[TouchFlowPanel] drop: no app scene"); return; }
    NSArray *items=haoge_touchflow_panelItems(currentBinding[@"panelItems"]);
    if (!items.count) { NSLog(@"[TouchFlowPanel] drop: no valid panel items"); return; }
    NSLog(@"[TouchFlowPanel] accepted scene=%@ role=%@ state=%ld level=%f",
        scene.session.persistentIdentifier,scene.session.role,(long)scene.activationState,10000011.0);
    self.haoge_touchflow_generation++;self.haoge_touchflow_trigger=[trigger copy];
    self.haoge_touchflow_cancelledAction=NO;
    HaogeTouchFlowPanelController *controller=[HaogeTouchFlowPanelController new];
    controller.haoge_touchflow_items=items;controller.haoge_touchflow_settings=[config haoge_touchflow_snapshot];
    __weak typeof(self) weakSelf=self;
    controller.haoge_touchflow_close=^{[weakSelf haoge_touchflow_dismiss];};
    controller.haoge_touchflow_selection=^(NSDictionary *item) { [weakSelf haoge_touchflow_select:item]; };
    Class windowClass=haoge_touchflow_panelWindowClass();
    UIWindow *window=((UIWindow *(*)(id,SEL,id))objc_msgSend)([windowClass alloc],@selector(initWithWindowScene:),scene);
    NSLog(@"[TouchFlowPanel] windowClass=%@ window=%@ scene=%@ bounds=%@",NSStringFromClass(window.class),window,scene,NSStringFromCGRect(scene.coordinateSpace.bounds));
    if (!window) {
        NSLog(@"[TouchFlow] Panel window creation failed for %@", trigger);
        self.haoge_touchflow_trigger = nil;
        return;
    }
    window.frame = scene.coordinateSpace.bounds;
    window.windowLevel = 10000011.0;
    window.backgroundColor = UIColor.clearColor;
    window.alpha = 1;
    window.userInteractionEnabled = YES;
    window.rootViewController = controller;
    self.haoge_touchflow_window = window;
    self.haoge_touchflow_controller = controller;
    // Becomes key like the reference plugin so the panel window itself receives
    // touches even while a third-party app is foreground.
    window.hidden = NO;
    [window makeKeyAndVisible];
    // Some SpringBoard scenes deliver appearance callbacks a run-loop turn later.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.haoge_touchflow_window != window || self.haoge_touchflow_dismissing) return;
        NSLog(@"[TouchFlowPanel] presented window=%@ hidden=%d frame=%@",window,window.hidden,NSStringFromCGRect(window.frame));
        [controller haoge_touchflow_animateIn];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, controller.haoge_touchflow_scroll);
    });
}
- (NSDictionary *)haoge_touchflow_currentItem:(NSDictionary *)item trigger:(NSString *)trigger {
    HaogeTouchFlowConfig *config=[HaogeTouchFlowConfig haoge_touchflow_shared];
    if (![config haoge_touchflow_isEnabled] || haoge_touchflow_panelLocked()) return nil;
    NSDictionary *binding=haoge_touchflow_binding([config haoge_touchflow_snapshot],trigger);
    if (!haoge_touchflow_bindingEnabled(binding) || !haoge_touchflow_hasPanelMode(binding)) return nil;
    for (NSDictionary *current in haoge_touchflow_panelItems(binding[@"panelItems"]))
        if ([current[@"id"] isEqual:item[@"id"]]) return current;
    return nil;
}
- (void)haoge_touchflow_select:(NSDictionary *)item {
    if (self.haoge_touchflow_dismissing || !self.haoge_touchflow_window) return;
    NSString *trigger=self.haoge_touchflow_trigger;
    NSDictionary *current=[self haoge_touchflow_currentItem:item trigger:trigger];
    if (!current) { [self haoge_touchflow_dismiss];return; }
    [self haoge_touchflow_closeWithCompletion:^{
        if (self.haoge_touchflow_cancelledAction) return;
        NSDictionary *latest=[self haoge_touchflow_currentItem:current trigger:trigger];if (!latest) return;
        NSMutableDictionary *action=[latest mutableCopy];action[@"enabled"]=@YES;
        haoge_touchflow_executeBinding(action);
    }];
}
- (void)haoge_touchflow_dismiss { [self haoge_touchflow_closeWithCompletion:nil]; }
- (BOOL)haoge_touchflow_handleOutsideTapInWindow:(UIWindow *)window point:(CGPoint)point {
    if (!window || !self.haoge_touchflow_window || !self.haoge_touchflow_controller) return NO;
    HaogeTouchFlowPanelController *controller=self.haoge_touchflow_controller;
    UIView *root=controller.view;
    if (!root || !controller.haoge_touchflow_sheet) return NO;
    // The tapped window and the panel window are siblings. convertPoint:toView:nil
    // yields window coordinates; fromView:nil interprets them in the panel window's
    // coordinate space, which stays exact across scenes and orientations.
    CGPoint local=[root convertPoint:[window convertPoint:point toView:nil] fromView:nil];
    CGRect sheetFrame=controller.haoge_touchflow_sheet.frame;
    if (CGRectContainsPoint(sheetFrame,local)) return NO;
    [self haoge_touchflow_dismiss];
    return YES;
}
- (void)haoge_touchflow_closeWithCompletion:(void (^)(void))completion {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_touchflow_closeWithCompletion:completion]; });return; }
    if (self.haoge_touchflow_dismissing || !self.haoge_touchflow_window) return;
    self.haoge_touchflow_dismissing=YES;NSUInteger generation=self.haoge_touchflow_generation;
    self.haoge_touchflow_window.userInteractionEnabled=NO;
    HaogeTouchFlowPanelController *controller=self.haoge_touchflow_controller;
    NSTimeInterval duration=UIAccessibilityIsReduceMotionEnabled()?0.01:haoge_touchflow_panelNumber(controller.haoge_touchflow_settings,@"panelCloseDuration");
    [UIView animateWithDuration:duration animations:^{
        controller.haoge_touchflow_sheet.transform=CGAffineTransformMakeTranslation(0,CGRectGetHeight(controller.haoge_touchflow_sheet.bounds)+30);
        controller.haoge_touchflow_dimmer.alpha=0;
    } completion:^(BOOL finished) {
        (void)finished;if (generation!=self.haoge_touchflow_generation) return;
        self.haoge_touchflow_window.hidden=YES;self.haoge_touchflow_window.rootViewController=nil;
        self.haoge_touchflow_window=nil;self.haoge_touchflow_controller=nil;self.haoge_touchflow_trigger=nil;
        self.haoge_touchflow_dismissing=NO;if (completion) completion();
    }];
}
@end
