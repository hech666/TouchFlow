#import "HaogeTouchFlowPanel.h"
#import "HaogeTouchFlowPanelModel.h"
#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import <objc/message.h>
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
static UIWindowScene *haoge_touchflow_activeApplicationScene(UIWindow *sourceWindow) {
    UIWindowScene *scene=sourceWindow.windowScene;
    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState==UISceneActivationStateForegroundActive) return scene;
    NSSet<UIScene *> *scenes=UIApplication.sharedApplication.connectedScenes;
    // Prefer the SpringBoard application scene identified by the original binary.
    for (UIScene *candidate in scenes) {
        if (![candidate isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene=(UIWindowScene *)candidate;
        if (windowScene.activationState!=UISceneActivationStateForegroundActive) continue;
        if ([windowScene.session.persistentIdentifier isEqual:@"com.apple.springboard"]) return windowScene;
        for (UIWindow *window in windowScene.windows) {
            if (!window.isKeyWindow) continue;
            if ([windowScene.session.role hasSuffix:@"Application"] || [windowScene.session.role isEqual:UISceneSessionRoleApplication]) return windowScene;
        }
    }
    // Finally accept the active application role for OS versions whose session identifier differs.
    for (UIScene *candidate in scenes) {
        if (![candidate isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene=(UIWindowScene *)candidate;
        if (windowScene.activationState==UISceneActivationStateForegroundActive &&
            ([windowScene.session.role hasSuffix:@"Application"] || [windowScene.session.role isEqual:UISceneSessionRoleApplication])) return windowScene;
    }
    return nil;
}
@interface HaogeTouchFlowPanelWindow : UIWindow
@end
@implementation HaogeTouchFlowPanelWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha<=0.01 || !self.userInteractionEnabled) return nil;
    UIView *root=self.rootViewController.view;
    return [root hitTest:[root convertPoint:point fromView:self] withEvent:event];
}
@end

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
- (void)haoge_touchflow_animateIn {
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
@property (nonatomic, strong) HaogeTouchFlowPanelWindow *haoge_touchflow_window;
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
    scene=haoge_touchflow_activeApplicationScene(sourceWindow);
    if (!scene || scene.activationState!=UISceneActivationStateForegroundActive ||
        !haoge_touchflow_hasPanelMode(binding) || !haoge_touchflow_bindingEnabled(binding)) return;
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
    UIWindow *anchor=sourceWindow;
    if (!anchor || anchor.windowScene!=scene) {
        for (UIWindow *candidate in scene.windows) if (candidate.isKeyWindow) { anchor=candidate;break; }
    }
    HaogeTouchFlowPanelWindow *window=[[HaogeTouchFlowPanelWindow alloc] initWithWindowScene:scene];
    window.frame=scene.coordinateSpace.bounds;
    // OneStepX's recovered controller uses level 10000011; remain above SB but never become key.
    window.windowLevel=10000011.0;
    window.backgroundColor=UIColor.clearColor;window.rootViewController=controller;
    if (anchor && anchor.windowScene==scene) window.windowScene=anchor.windowScene;
    self.haoge_touchflow_window=window;self.haoge_touchflow_controller=controller;
    window.hidden=NO; // Never makeKeyWindow: avoid displacing SpringBoard's keyboard/key state.
    [controller haoge_touchflow_animateIn];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,controller.haoge_touchflow_heading);
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
