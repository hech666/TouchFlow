#import "HaogeTouchFlowPanel.h"
#import "HaogeTouchFlowPanelModel.h"
#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
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
    UIApplication *application = UIApplication.sharedApplication;
    NSArray *windows = haoge_touchflow_panelObject(application, @"windows");
    for (UIWindow *window in windows) {
        if (window.isKeyWindow && haoge_touchflow_isApplicationScene(window.windowScene)) return window.windowScene;
    }
    Class homeWindowClass = NSClassFromString(@"SBHomeScreenWindow");
    if (homeWindowClass) {
        for (UIWindow *window in windows) {
            if ([window isKindOfClass:homeWindowClass] && haoge_touchflow_isApplicationScene(window.windowScene)) return window.windowScene;
        }
    }

    // SpringBoard's own application scene can be attached while another app is active.
    UIWindowScene *active = nil;
    UIWindowScene *inactive = nil;
    for (UIScene *candidate in application.connectedScenes) {
        if (![candidate isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *scene = (UIWindowScene *)candidate;
        if (!haoge_touchflow_isApplicationScene(scene)) continue;
        if ([scene.session.persistentIdentifier isEqualToString:@"com.apple.springboard"]) return scene;
        if (!active && scene.activationState == UISceneActivationStateForegroundActive) active = scene;
        if (!inactive && scene.activationState == UISceneActivationStateForegroundInactive) inactive = scene;
    }
    if (haoge_touchflow_isApplicationScene(sourceWindow.windowScene) && sourceWindow.windowScene.activationState == UISceneActivationStateForegroundActive) return sourceWindow.windowScene;
    if (haoge_touchflow_isApplicationScene(sourceScene) && sourceScene.activationState == UISceneActivationStateForegroundActive) return sourceScene;
    return active ?: inactive;
}
static UIView *haoge_touchflow_panelHitTest(UIWindow *window, SEL selector, CGPoint point, UIEvent *event) {
    (void)selector;
    if (window.hidden || window.alpha <= 0.01 || !window.userInteractionEnabled) return nil;
    UIView *root = window.rootViewController.viewIfLoaded;
    if (!root) return nil;
    return [root hitTest:[root convertPoint:point fromView:window] withEvent:event];
}

@interface HaogeTouchFlowPanelWindow : UIWindow
@end
@implementation HaogeTouchFlowPanelWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return haoge_touchflow_panelHitTest(self, _cmd, point, event);
}
@end

static Class haoge_touchflow_panelWindowClass(void) {
    static Class windowClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        windowClass = HaogeTouchFlowPanelWindow.class;
        Class base = NSClassFromString(@"SBFTouchPassThroughWindow");
        if (!base && [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            dlopen("/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation", RTLD_LAZY);
            base = NSClassFromString(@"SBFTouchPassThroughWindow");
        }
        if (![base isSubclassOfClass:UIWindow.class]) return;
        SEL hitTest = @selector(hitTest:withEvent:);
        Method method = class_getInstanceMethod(UIWindow.class, hitTest);
        if (!method) return;
        Class candidate = objc_allocateClassPair(base, "HaogeTouchFlowSystemPanelWindow", 0);
        if (!candidate) return;
        if (!class_addMethod(candidate, hitTest, (IMP)haoge_touchflow_panelHitTest, method_getTypeEncoding(method))) {
            objc_disposeClassPair(candidate);
            return;
        }
        objc_registerClassPair(candidate);
        windowClass = candidate;
    });
    return windowClass;
}

@interface HaogeTouchFlowPanelController : UIViewController <UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *haoge_touchflow_items;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_settings;
@property (nonatomic, copy) NSString *haoge_touchflow_title;
@property (nonatomic, copy) void (^haoge_touchflow_selection)(NSDictionary *);
@property (nonatomic, copy) void (^haoge_touchflow_close)(void);
@property (nonatomic, strong) UIControl *haoge_touchflow_dimmer;
@property (nonatomic, strong) UIVisualEffectView *haoge_touchflow_sheet;
@property (nonatomic, strong) UIScrollView *haoge_touchflow_scroll;
@property (nonatomic, strong) UILabel *haoge_touchflow_heading;
@property (nonatomic, strong) UIButton *haoge_touchflow_closeButton;
@property (nonatomic, strong) UIView *haoge_touchflow_grabber;
@property (nonatomic, strong) NSMutableArray<UIButton *> *haoge_touchflow_buttons;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *haoge_touchflow_icons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *haoge_touchflow_labels;
@property (nonatomic, assign) BOOL haoge_touchflow_shown;
- (void)haoge_touchflow_animateIn;
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
    self.haoge_touchflow_grabber=[UIView new];self.haoge_touchflow_grabber.backgroundColor=UIColor.tertiaryLabelColor;
    self.haoge_touchflow_grabber.layer.cornerRadius=2.5;[content addSubview:self.haoge_touchflow_grabber];
    self.haoge_touchflow_heading=[UILabel new];self.haoge_touchflow_heading.text=self.haoge_touchflow_title?:@"快捷面板";
    self.haoge_touchflow_heading.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];self.haoge_touchflow_heading.textColor=UIColor.labelColor;
    self.haoge_touchflow_heading.accessibilityTraits=UIAccessibilityTraitHeader;[content addSubview:self.haoge_touchflow_heading];
    self.haoge_touchflow_closeButton=[UIButton buttonWithType:UIButtonTypeSystem];
    [self.haoge_touchflow_closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.haoge_touchflow_closeButton.accessibilityLabel=@"关闭快捷面板";
    [self.haoge_touchflow_closeButton addTarget:self action:@selector(haoge_touchflow_closePressed) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.haoge_touchflow_closeButton];
    self.haoge_touchflow_scroll=[UIScrollView new];self.haoge_touchflow_scroll.alwaysBounceVertical=YES;
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
        icon.backgroundColor=[UIColor.secondarySystemFillColor colorWithAlphaComponent:0.6];icon.clipsToBounds=YES;
        UILabel *label=[UILabel new];label.text=haoge_touchflow_panelItemTitle(item);label.textColor=UIColor.labelColor;
        label.font=[UIFont systemFontOfSize:haoge_touchflow_panelNumber(settings,@"panelTextSize")];label.numberOfLines=2;
        label.textAlignment=NSTextAlignmentCenter;label.adjustsFontSizeToFitWidth=YES;label.minimumScaleFactor=0.75;
        label.hidden=!haoge_touchflow_panelFlag(settings,@"panelShowsLabels",YES);
        icon.isAccessibilityElement=NO;label.isAccessibilityElement=NO;
        [button addSubview:icon];[button addSubview:label];[self.haoge_touchflow_scroll addSubview:button];
        [self.haoge_touchflow_buttons addObject:button];[self.haoge_touchflow_icons addObject:icon];[self.haoge_touchflow_labels addObject:label];
    }];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_panned:)];
    pan.delegate=self;[self.haoge_touchflow_sheet addGestureRecognizer:pan];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];CGRect bounds=self.view.bounds;
    self.haoge_touchflow_dimmer.frame=bounds;
    CGFloat margin=12,width=MAX(1,CGRectGetWidth(bounds)-2*margin);
    CGFloat bottom=MAX(self.view.safeAreaInsets.bottom,12),top=MAX(self.view.safeAreaInsets.top,20);
    CGFloat height=MIN(haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelHeight"),MAX(150,CGRectGetHeight(bounds)-top-20));
    self.haoge_touchflow_sheet.bounds=CGRectMake(0,0,width,height);
    self.haoge_touchflow_sheet.center=CGPointMake(CGRectGetMidX(bounds),CGRectGetHeight(bounds)-height*0.5-8);
    self.haoge_touchflow_grabber.frame=CGRectMake((width-36)/2,9,36,5);
    self.haoge_touchflow_heading.frame=CGRectMake(18,22,MAX(1,width-78),34);
    self.haoge_touchflow_closeButton.frame=CGRectMake(width-56,16,44,44);
    CGFloat usable=MAX(1,height-62-MIN(bottom,38));self.haoge_touchflow_scroll.frame=CGRectMake(8,62,MAX(1,width-16),usable);
    NSInteger columns=(NSInteger)haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelColumns");
    CGFloat cellWidth=CGRectGetWidth(self.haoge_touchflow_scroll.bounds)/(CGFloat)columns;
    CGFloat rowHeight=MAX(haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelRowHeight"),haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelIconSize")+36);
    CGFloat size=MIN(haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelIconSize"),MAX(18,cellWidth-12));
    [self.haoge_touchflow_buttons enumerateObjectsUsingBlock:^(UIButton *button,NSUInteger index,BOOL *stop) {
        (void)stop;button.frame=CGRectMake((index%(NSUInteger)columns)*cellWidth,(index/(NSUInteger)columns)*rowHeight,cellWidth,rowHeight);
        UIImageView *icon=self.haoge_touchflow_icons[index];icon.frame=CGRectMake((cellWidth-size)/2,4,size,size);
        icon.layer.cornerRadius=size*0.5*haoge_touchflow_panelNumber(self.haoge_touchflow_settings,@"panelIconCornerPercent")/100;
        icon.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:size*0.53 weight:UIImageSymbolWeightMedium];
        self.haoge_touchflow_labels[index].frame=CGRectMake(3,size+8,MAX(1,cellWidth-6),MAX(1,rowHeight-size-10));
    }];
    NSInteger rows=(self.haoge_touchflow_buttons.count+(NSUInteger)columns-1)/(NSUInteger)columns;
    self.haoge_touchflow_scroll.contentSize=CGSizeMake(CGRectGetWidth(self.haoge_touchflow_scroll.bounds),rows*rowHeight);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
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
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    CGPoint p=[touch locationInView:self.haoge_touchflow_sheet];(void)gesture;
    return p.y<20; // Only the grabber drags. Buttons and scrolling retain their touches.
}
- (void)haoge_touchflow_panned:(UIPanGestureRecognizer *)pan {
    if (pan.state!=UIGestureRecognizerStateEnded) return;
    if ([pan translationInView:self.view].y>40 || [pan velocityInView:self.view].y>400) [self haoge_touchflow_closePressed];
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
- (void)haoge_touchflow_showBinding:(NSDictionary *)binding trigger:(NSString *)trigger scene:(UIWindowScene *)scene sourceWindow:(UIWindow *)sourceWindow {
    NSAssert(NSThread.isMainThread,@"Panel UI must run on main");
    if (self.haoge_touchflow_dismissing) return;
    if (self.haoge_touchflow_window) { [self haoge_touchflow_dismiss];return; }
    HaogeTouchFlowConfig *config=[HaogeTouchFlowConfig haoge_touchflow_shared];
    if (![config haoge_touchflow_isEnabled] || haoge_touchflow_panelLocked()) return;
    if (!haoge_touchflow_hasPanelMode(binding) || !haoge_touchflow_bindingEnabled(binding)) return;
    scene = haoge_touchflow_applicationScene(scene, sourceWindow);
    if (!scene) {
        NSLog(@"[TouchFlow] No application window scene for panel trigger %@", trigger);
        return;
    }
    NSArray *items=haoge_touchflow_panelItems(binding[@"panelItems"]);if (!items.count) return;
    self.haoge_touchflow_generation++;self.haoge_touchflow_trigger=[trigger copy];
    self.haoge_touchflow_cancelledAction=NO;
    NSUInteger index=[haoge_touchflow_triggerIDs() indexOfObject:trigger];
    HaogeTouchFlowPanelController *controller=[HaogeTouchFlowPanelController new];
    controller.haoge_touchflow_items=items;controller.haoge_touchflow_settings=[config haoge_touchflow_snapshot];
    controller.haoge_touchflow_title=index==NSNotFound?@"快捷面板":haoge_touchflow_triggerTitles()[index];
    __weak typeof(self) weakSelf=self;
    controller.haoge_touchflow_close=^{[weakSelf haoge_touchflow_dismiss];};
    controller.haoge_touchflow_selection=^(NSDictionary *item) { [weakSelf haoge_touchflow_select:item]; };
    Class windowClass = haoge_touchflow_panelWindowClass();
    UIWindow *window = [[windowClass alloc] initWithWindowScene:scene];
    if (!window && windowClass != HaogeTouchFlowPanelWindow.class) {
        window = [[HaogeTouchFlowPanelWindow alloc] initWithWindowScene:scene];
    }
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
    window.hidden = NO;
    // Some SpringBoard scenes deliver appearance callbacks a run-loop turn later.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.haoge_touchflow_window != window || self.haoge_touchflow_dismissing) return;
        [controller haoge_touchflow_animateIn];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, controller.haoge_touchflow_heading);
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
