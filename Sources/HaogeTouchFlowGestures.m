#import "HaogeTouchFlowGestures.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowPanel.h"
#import "HaogeTouchFlowGeometry.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface HaogeTouchFlowBottomSession : NSObject {
@public
    HaogeTouchFlowBottomHold haoge_touchflow_hold;
}
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, copy) NSString *haoge_touchflow_farTrigger;
@property (nonatomic, strong) NSDictionary *haoge_touchflow_snapshot;
@property (nonatomic, weak) UIView *haoge_touchflow_view;
@property (nonatomic, assign) BOOL haoge_touchflow_fired;
@property (nonatomic, assign) BOOL haoge_touchflow_nearEnabled;
@property (nonatomic, assign) double haoge_touchflow_nearDistance;
@property (nonatomic, assign) double haoge_touchflow_farDistance;
@property (nonatomic, assign) BOOL haoge_touchflow_invalidated;
@end
@implementation HaogeTouchFlowBottomSession
@end

static char haoge_touchflow_windowKey, haoge_touchflow_desktopKey, haoge_touchflow_bottomSessionKey;
static id haoge_touchflow_object(id target, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return [target respondsToSelector:selector] ? ((id (*)(id,SEL))objc_msgSend)(target,selector) : nil;
}
static BOOL haoge_touchflow_bool(id target, NSString *name, BOOL fallback) {
    SEL selector = NSSelectorFromString(name);
    return [target respondsToSelector:selector] ? ((BOOL (*)(id,SEL))objc_msgSend)(target,selector) : fallback;
}
static BOOL haoge_touchflow_locked(void) {
    id manager = haoge_touchflow_object(NSClassFromString(@"SBLockScreenManager"), @"sharedInstance");
    if ([manager respondsToSelector:NSSelectorFromString(@"isUILocked")]) return haoge_touchflow_bool(manager,@"isUILocked",YES);
    if ([manager respondsToSelector:NSSelectorFromString(@"isLocked")]) return haoge_touchflow_bool(manager,@"isLocked",YES);
    return YES; // Unknown lock state never grants unlocked actions.
}

@interface HaogeTouchFlowBindingRecognizer : UIGestureRecognizer
@property (nonatomic, copy) NSString *haoge_touchflow_region; // status or bottom
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, copy) NSString *haoge_touchflow_prefix;
@property (nonatomic, assign) CGPoint haoge_touchflow_origin;
@property (nonatomic, assign) NSUInteger haoge_touchflow_generation;
@property (nonatomic, assign) BOOL haoge_touchflow_fired;
@end
@interface HaogeTouchFlowGestures () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSHashTable<HaogeTouchFlowBindingRecognizer *> *haoge_touchflow_recognizers;
@property (nonatomic, strong) NSHashTable<UILongPressGestureRecognizer *> *haoge_touchflow_desktopRecognizers;
@property (nonatomic, strong) NSHashTable<UIGestureRecognizer *> *haoge_touchflow_claimedRecognizers;
@property (nonatomic, strong) NSHashTable<UIWindow *> *haoge_touchflow_windows;
@property (nonatomic, assign) BOOL haoge_touchflow_refreshing;
@property (nonatomic, assign) BOOL haoge_touchflow_started;
@property (nonatomic, strong) UIImpactFeedbackGenerator *haoge_touchflow_feedback;
@property (nonatomic, strong) HaogeTouchFlowConfig *haoge_touchflow_config;
- (NSDictionary *)haoge_touchflow_snapshot;
- (BOOL)haoge_touchflow_allowed;
- (BOOL)haoge_touchflow_enabledTrigger:(NSString *)trigger;
- (NSString *)haoge_touchflow_statusPrefixForPoint:(CGPoint)point view:(UIView *)view;
- (NSString *)haoge_touchflow_bottomTriggerForPoint:(CGPoint)point view:(UIView *)view;
- (double)haoge_touchflow_number:(NSString *)key fallback:(double)fallback min:(double)lo max:(double)hi;
- (void)haoge_touchflow_fire:(NSString *)trigger view:(UIView *)view;
- (void)haoge_touchflow_refresh;
- (void)haoge_touchflow_recognized:(HaogeTouchFlowBindingRecognizer *)recognizer;
- (void)haoge_touchflow_desktopPressed:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation HaogeTouchFlowBindingRecognizer
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.count != 1 || event.allTouches.count != 1 || self.state != UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateFailed; return;
    }
    HaogeTouchFlowGestures *manager = [HaogeTouchFlowGestures haoge_touchflow_shared];
    self.haoge_touchflow_origin = [touches.anyObject locationInView:self.view];
    self.haoge_touchflow_trigger = nil; self.haoge_touchflow_fired = NO;
    self.haoge_touchflow_generation++;
    if ([self.haoge_touchflow_region isEqual:@"bottom"]) {
        self.haoge_touchflow_trigger = [manager haoge_touchflow_bottomTriggerForPoint:self.haoge_touchflow_origin view:self.view];
        if (!self.haoge_touchflow_trigger) self.state = UIGestureRecognizerStateFailed;
        return;
    }
    self.haoge_touchflow_prefix = [manager haoge_touchflow_statusPrefixForPoint:self.haoge_touchflow_origin view:self.view];
    if (!self.haoge_touchflow_prefix) { self.state = UIGestureRecognizerStateFailed; return; }
    NSString *longTrigger = [self.haoge_touchflow_prefix stringByAppendingString:@"LongPress"];
    if (![manager haoge_touchflow_enabledTrigger:longTrigger]) return;
    NSUInteger generation = self.haoge_touchflow_generation;
    double duration = [manager haoge_touchflow_number:@"longPressDuration" fallback:0.55 min:0.35 max:1.2];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.haoge_touchflow_generation != generation || strongSelf.state != UIGestureRecognizerStatePossible) return;
        if (![manager haoge_touchflow_enabledTrigger:longTrigger]) { strongSelf.state = UIGestureRecognizerStateFailed; return; }
        strongSelf.haoge_touchflow_trigger = longTrigger; strongSelf.haoge_touchflow_fired = YES;
        strongSelf.state = UIGestureRecognizerStateBegan;
    });
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    if (self.state == UIGestureRecognizerStateFailed || self.state == UIGestureRecognizerStateCancelled) return;
    CGPoint point = [touches.anyObject locationInView:self.view];
    double dx = point.x - self.haoge_touchflow_origin.x, dy = point.y - self.haoge_touchflow_origin.y;
    HaogeTouchFlowGestures *manager = [HaogeTouchFlowGestures haoge_touchflow_shared];
    if (![manager haoge_touchflow_allowed]) { self.state = self.state == UIGestureRecognizerStatePossible ? UIGestureRecognizerStateFailed : UIGestureRecognizerStateCancelled; return; }
    if (self.haoge_touchflow_fired) { self.state = UIGestureRecognizerStateChanged; return; }
    if ([self.haoge_touchflow_region isEqual:@"bottom"]) {
        double threshold = [manager haoge_touchflow_number:@"bottomDistance" fallback:110 min:60 max:200];
        if (haoge_touchflow_upward(dx,dy,threshold)) { self.haoge_touchflow_fired = YES; self.state = UIGestureRecognizerStateBegan; }
        else if (fabs(dx) > 40 && fabs(dx) > -dy) self.state = UIGestureRecognizerStateFailed;
        return;
    }
    double threshold = [manager haoge_touchflow_number:@"statusDistance" fallback:60 min:30 max:140];
    if (haoge_touchflow_horizontal(dx,dy,threshold)) {
        NSString *trigger = [self.haoge_touchflow_prefix stringByAppendingString:dx < 0 ? @"SwipeLeft" : @"SwipeRight"];
        if (![manager haoge_touchflow_enabledTrigger:trigger]) { self.state = UIGestureRecognizerStateFailed; return; }
        self.haoge_touchflow_generation++; self.haoge_touchflow_trigger = trigger;
        self.haoge_touchflow_fired = YES; self.state = UIGestureRecognizerStateBegan;
    } else if (hypot(dx,dy) > 12) {
        self.haoge_touchflow_generation++; // Movement invalidates long press, keeps horizontal recognition.
        if (fabs(dy) > 24 && fabs(dy) > fabs(dx)) self.state = UIGestureRecognizerStateFailed;
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches; (void)event; self.haoge_touchflow_generation++;
    self.state = self.haoge_touchflow_fired ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches; (void)event; self.haoge_touchflow_generation++;
    self.state = self.state == UIGestureRecognizerStatePossible ? UIGestureRecognizerStateFailed : UIGestureRecognizerStateCancelled;
}
- (void)reset {
    [super reset]; self.haoge_touchflow_generation++; self.haoge_touchflow_fired = NO;
    self.haoge_touchflow_trigger = nil; self.haoge_touchflow_prefix = nil;
}
@end

@implementation HaogeTouchFlowGestures
+ (instancetype)haoge_touchflow_shared {
    static HaogeTouchFlowGestures *instance; static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; }); return instance;
}
- (instancetype)init {
    if ((self = [super init])) {
        _haoge_touchflow_recognizers = [NSHashTable weakObjectsHashTable];
        _haoge_touchflow_desktopRecognizers = [NSHashTable weakObjectsHashTable];
        _haoge_touchflow_claimedRecognizers = [NSHashTable weakObjectsHashTable];
        _haoge_touchflow_windows = [NSHashTable weakObjectsHashTable];
        _haoge_touchflow_config = [HaogeTouchFlowConfig haoge_touchflow_shared];
        _haoge_touchflow_feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    } return self;
}
- (NSDictionary *)haoge_touchflow_snapshot { return [self.haoge_touchflow_config haoge_touchflow_snapshot]; }
- (BOOL)haoge_touchflow_allowed {
    if (![self.haoge_touchflow_config haoge_touchflow_isEnabled]) return NO;
    id allow = [self haoge_touchflow_snapshot][@"allowLocked"];
    return !haoge_touchflow_locked() || ([allow isKindOfClass:[NSNumber class]] && [allow boolValue]);
}
- (BOOL)haoge_touchflow_enabledTrigger:(NSString *)trigger {
    if (!trigger.length || ![self haoge_touchflow_allowed]) return NO;
    NSDictionary *binding=haoge_touchflow_binding([self haoge_touchflow_snapshot],trigger);
    return !(haoge_touchflow_hasPanelMode(binding) && haoge_touchflow_locked()) && haoge_touchflow_bindingEnabled(binding);
}
- (double)haoge_touchflow_number:(NSString *)key fallback:(double)fallback min:(double)lo max:(double)hi {
    id value = [self haoge_touchflow_snapshot][key];
    return haoge_touchflow_finiteClamp([value isKindOfClass:[NSNumber class]] ? [value doubleValue] : fallback,fallback,lo,hi);
}
- (BOOL)haoge_touchflow_portrait:(UIView *)view {
    UIWindowScene *scene = view.window.windowScene;
    return scene ? UIInterfaceOrientationIsPortrait(scene.interfaceOrientation)
                 : UIScreen.mainScreen.bounds.size.height >= UIScreen.mainScreen.bounds.size.width;
}
- (NSString *)haoge_touchflow_statusPrefixForPoint:(CGPoint)point view:(UIView *)view {
    if (!view || ![self haoge_touchflow_allowed] || ![self haoge_touchflow_portrait:view]) return nil;
    UIStatusBarManager *status = view.window.windowScene.statusBarManager;
    if (status.isStatusBarHidden) return nil;
    double height = status ? CGRectGetHeight(status.statusBarFrame) : 0;
    height = fmax(height, view.safeAreaInsets.top);
    if (height < 20) height = 44;
    if (point.y < CGRectGetMinY(view.bounds) || point.y > CGRectGetMinY(view.bounds) + fmin(height,80)) return nil;
    int side = haoge_touchflow_side(point.x-CGRectGetMinX(view.bounds),CGRectGetWidth(view.bounds),
        [self haoge_touchflow_number:@"sidePercent" fallback:25 min:10 max:33]);
    return side < 0 ? @"statusLeft" : (side > 0 ? @"statusRight" : nil);
}
- (NSString *)haoge_touchflow_bottomSideForPoint:(CGPoint)point view:(UIView *)view {
    if (!view || ![self haoge_touchflow_allowed] || ![self haoge_touchflow_portrait:view] || !isfinite(point.y)) return nil;
    double height = fmax(54,view.safeAreaInsets.bottom+20);
    if (point.y < CGRectGetMaxY(view.bounds)-height || point.y > CGRectGetMaxY(view.bounds)+1) return nil;
    int side = haoge_touchflow_side(point.x-CGRectGetMinX(view.bounds),CGRectGetWidth(view.bounds),
        [self haoge_touchflow_number:@"sidePercent" fallback:25 min:10 max:33]);
    return side < 0 ? @"bottomLeft" : (side > 0 ? @"bottomRight" : nil);
}
- (NSString *)haoge_touchflow_bottomTriggerForPoint:(CGPoint)point view:(UIView *)view {
    NSString *trigger = [self haoge_touchflow_bottomSideForPoint:point view:view];
    return [self haoge_touchflow_enabledTrigger:trigger] ? trigger : nil;
}
static BOOL haoge_touchflow_holdBindingReady(NSDictionary *binding) {
    if (!haoge_touchflow_bindingEnabled(binding)) return NO;
    if (haoge_touchflow_hasPanelMode(binding)) return YES;
    for (NSDictionary *entry in haoge_touchflow_actionCatalog()) {
        if (![entry[@"identifier"] isEqual:binding[@"action"]]) continue;
        if (![entry[@"needsValue"] boolValue]) return YES;
        id value = binding[@"value"];
        if (![value isKindOfClass:[NSString class]]) return NO;
        NSUInteger length = [[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length];
        return length > 0 && length <= 4096;
    }
    return NO;
}
- (void)haoge_touchflow_fire:(NSString *)trigger view:(UIView *)view {
    NSAssert(NSThread.isMainThread,@"TouchFlow gestures run on main");
    if (![self haoge_touchflow_enabledTrigger:trigger]) return;
    NSDictionary *binding=haoge_touchflow_binding([self haoge_touchflow_snapshot],trigger);
    if (haoge_touchflow_hasPanelMode(binding) && haoge_touchflow_locked()) return;
    id haptics = [self haoge_touchflow_snapshot][@"haptics"];
    if (!haptics || ([haptics isKindOfClass:[NSNumber class]] && [haptics boolValue])) [self.haoge_touchflow_feedback impactOccurred];
    if (haoge_touchflow_hasPanelMode(binding)) {
        __weak UIWindow *sourceWindow = view.window;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *current = haoge_touchflow_binding([self haoge_touchflow_snapshot], trigger);
            if (!haoge_touchflow_hasPanelMode(current) || ![self haoge_touchflow_enabledTrigger:trigger]) return;
            UIWindow *window = sourceWindow;
            [[HaogeTouchFlowPanel haoge_touchflow_shared] haoge_touchflow_showBinding:current trigger:trigger scene:window.windowScene sourceWindow:window];
        });
    } else haoge_touchflow_executeBinding(binding);
}
- (void)haoge_touchflow_start {
    if (self.haoge_touchflow_started) return;
    self.haoge_touchflow_started = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_refresh)
        name:HaogeTouchFlowPreferencesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(haoge_touchflow_refresh)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [self haoge_touchflow_refresh];
}
- (void)haoge_touchflow_attachSystemWindow:(UIWindow *)window {
    if (!NSThread.isMainThread) { __weak UIWindow *weakWindow = window; dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_touchflow_attachSystemWindow:weakWindow]; }); return; }
    if (![window isKindOfClass:[UIWindow class]] || objc_getAssociatedObject(window,&haoge_touchflow_windowKey)) return;
    [self.haoge_touchflow_windows addObject:window];
    NSMutableArray<UIGestureRecognizer *> *recognizers = [NSMutableArray array];
    HaogeTouchFlowBindingRecognizer *press = [[HaogeTouchFlowBindingRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_recognized:)];
    press.haoge_touchflow_region = @"status"; [self.haoge_touchflow_recognizers addObject:press]; [recognizers addObject:press];
    for (NSString *prefix in @[@"statusLeft",@"statusRight"]) {
        UITapGestureRecognizer *single = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_tapped:)];
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_tapped:)];
        doubleTap.numberOfTapsRequired = 2;
        single.name = [prefix stringByAppendingString:@"Tap"]; doubleTap.name = [prefix stringByAppendingString:@"DoubleTap"];
        [single requireGestureRecognizerToFail:doubleTap];
        [single requireGestureRecognizerToFail:press]; [doubleTap requireGestureRecognizerToFail:press];
        [recognizers addObjectsFromArray:@[single,doubleTap]];
    }
    HaogeTouchFlowBindingRecognizer *bottom = [[HaogeTouchFlowBindingRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_recognized:)];
    bottom.haoge_touchflow_region = @"bottom"; [self.haoge_touchflow_recognizers addObject:bottom]; [recognizers addObject:bottom];
    // Set association before adding recognizers: system manager registration can re-enter hooks.
    objc_setAssociatedObject(window,&haoge_touchflow_windowKey,recognizers,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UIGestureRecognizer *gesture in recognizers) {
        gesture.delegate = self; gesture.cancelsTouchesInView = NO;
        gesture.delaysTouchesBegan = NO; gesture.delaysTouchesEnded = NO;
        [window addGestureRecognizer:gesture];
    }
    [self haoge_touchflow_refresh];
}
- (void)haoge_touchflow_attachDesktop:(UIView *)view {
    if (!view || !NSThread.isMainThread || objc_getAssociatedObject(view,&haoge_touchflow_desktopKey)) return;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_touchflow_desktopPressed:)];
    longPress.allowableMovement = 12; longPress.delegate = self; longPress.cancelsTouchesInView = NO;
    [self.haoge_touchflow_desktopRecognizers addObject:longPress];
    objc_setAssociatedObject(view,&haoge_touchflow_desktopKey,longPress,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view addGestureRecognizer:longPress]; [self haoge_touchflow_refresh];
}
- (void)haoge_touchflow_refresh {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_touchflow_refresh]; }); return; }
    if (self.haoge_touchflow_refreshing) return;
    self.haoge_touchflow_refreshing = YES;
    @try {
        // Inspect only SpringBoard-owned system gesture windows; never create an overlay window.
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                NSString *name = NSStringFromClass(window.class);
                if ([name containsString:@"SystemGesture"]) [self haoge_touchflow_attachSystemWindow:window];
            }
        }
        id manager = haoge_touchflow_object(NSClassFromString(@"SBSystemGestureManager"),@"sharedInstance");
        id window = haoge_touchflow_object(manager,@"windowForSystemGestures");
        if ([window isKindOfClass:[UIWindow class]]) [self haoge_touchflow_attachSystemWindow:window];
        BOOL enabled = [self.haoge_touchflow_config haoge_touchflow_isEnabled];
        for (HaogeTouchFlowBindingRecognizer *recognizer in self.haoge_touchflow_recognizers) recognizer.enabled = enabled;
        for (UIWindow *candidate in self.haoge_touchflow_windows) {
            NSArray *gestures = objc_getAssociatedObject(candidate,&haoge_touchflow_windowKey);
            for (UIGestureRecognizer *recognizer in gestures) {
                if ([recognizer isKindOfClass:[UITapGestureRecognizer class]])
                    recognizer.enabled = enabled && haoge_touchflow_bindingEnabled(haoge_touchflow_binding([self haoge_touchflow_snapshot],recognizer.name));
            }
        }
        for (UILongPressGestureRecognizer *recognizer in self.haoge_touchflow_desktopRecognizers) {
            recognizer.minimumPressDuration = [self haoge_touchflow_number:@"longPressDuration" fallback:0.55 min:0.35 max:1.2];
            recognizer.enabled = enabled && haoge_touchflow_bindingEnabled(haoge_touchflow_binding([self haoge_touchflow_snapshot],@"desktopLongPress"));
        }
    } @finally { self.haoge_touchflow_refreshing = NO; }
}
- (void)haoge_touchflow_tapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateRecognized) [self haoge_touchflow_fire:recognizer.name view:recognizer.view];
}
- (void)haoge_touchflow_recognized:(HaogeTouchFlowBindingRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) [self haoge_touchflow_fire:recognizer.haoge_touchflow_trigger view:recognizer.view];
}
- (void)haoge_touchflow_desktopPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan && !haoge_touchflow_locked()) [self haoge_touchflow_fire:@"desktopLongPress" view:recognizer.view];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if (![self haoge_touchflow_allowed] || [[HaogeTouchFlowPanel haoge_touchflow_shared] haoge_touchflow_isVisible]) return NO;
    UIView *view = gesture.view;
    if ([gesture isKindOfClass:[HaogeTouchFlowBindingRecognizer class]]) {
        HaogeTouchFlowBindingRecognizer *bindingRecognizer = (id)gesture;
        if ([bindingRecognizer.haoge_touchflow_region isEqual:@"bottom"]) {
            // Unlocked bottom gestures are arbitrated by SBFluidSwitcher hooks;
            // the window recognizer is reserved for the lock-screen path.
            if (!haoge_touchflow_locked()) return NO;
            return [self haoge_touchflow_bottomTriggerForPoint:[touch locationInView:view] view:view] != nil;
        }
        NSString *prefix = [self haoge_touchflow_statusPrefixForPoint:[touch locationInView:view] view:view];
        if (!prefix) return NO;
        for (NSString *suffix in @[@"LongPress",@"SwipeLeft",@"SwipeRight"])
            if ([self haoge_touchflow_enabledTrigger:[prefix stringByAppendingString:suffix]]) return YES;
        return NO;
    }
    if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
        NSString *prefix = [self haoge_touchflow_statusPrefixForPoint:[touch locationInView:view] view:view];
        return prefix.length && [gesture.name hasPrefix:prefix] && [self haoge_touchflow_enabledTrigger:gesture.name];
    }
    if ([self.haoge_touchflow_desktopRecognizers containsObject:(id)gesture]) {
        if (haoge_touchflow_locked() || ![self haoge_touchflow_enabledTrigger:@"desktopLongPress"]) return NO;
        id controller = haoge_touchflow_object(NSClassFromString(@"SBIconController"),@"sharedInstance");
        if (haoge_touchflow_bool(controller,@"areHomeScreenIconsOccluded",NO) ||
            haoge_touchflow_bool(controller,@"isShowingHomeScreenOverlay",NO) ||
            haoge_touchflow_bool(haoge_touchflow_object(controller,@"iconManager"),@"isEditing",NO)) return NO;
        for (UIView *candidate = touch.view; candidate && candidate != view; candidate = candidate.superview) {
            if ([candidate isKindOfClass:[UIControl class]]) return NO;
            NSString *name = NSStringFromClass(candidate.class);
            for (NSString *part in @[@"IconView",@"Widget",@"Dock",@"PageControl",@"Search",@"FolderIcon"])
                if ([name rangeOfString:part options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
        }
        return YES;
    }
    return NO;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    return [self haoge_touchflow_allowed];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)first shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)second {
    (void)first; (void)second;
    // Bottom system lifecycle is explicitly reserved only in configured side regions.
    // Allowing other recognizers preserves system downward pulls and ordinary desktop taps.
    return YES;
}
- (BOOL)haoge_touchflow_claimBottomFromManager:(id)manager gesture:(UIGestureRecognizer *)gesture {
    if ([[HaogeTouchFlowPanel haoge_touchflow_shared] haoge_touchflow_isVisible] || ![gesture isKindOfClass:[UIPanGestureRecognizer class]] || haoge_touchflow_locked()) return NO;
    if (gesture != haoge_touchflow_object(manager,@"homeGestureBottomEdgeRecognizer")) return NO;
    if (![self haoge_touchflow_allowed] || !gesture.view) return NO;
    SEL modeSelector = NSSelectorFromString(@"_currentUnlockedEnvironmentMode");
    if ([manager respondsToSelector:modeSelector]) {
        NSInteger mode = ((NSInteger (*)(id,SEL))objc_msgSend)(manager,modeSelector);
        if (mode != 1 && mode != 3) return NO;
    }
    UIView *view = gesture.view;
    CGPoint location = [gesture locationInView:view];
    CGPoint translation = [(UIPanGestureRecognizer *)gesture translationInView:view];
    CGPoint start = CGPointMake(location.x-translation.x,location.y-translation.y);
    NSDictionary *snapshot = [self haoge_touchflow_snapshot];
    NSString *trigger = [self haoge_touchflow_bottomSideForPoint:start view:view];
    if (!trigger) return NO;
    NSString *far = [trigger isEqualToString:@"bottomLeft"] ? @"bottomLeftFar" : @"bottomRightFar";
    BOOL dual = haoge_touchflow_holdBindingReady(haoge_touchflow_binding(snapshot,far));
    BOOL near = dual ? haoge_touchflow_holdBindingReady(haoge_touchflow_binding(snapshot,trigger))
                     : [self haoge_touchflow_enabledTrigger:trigger];
    if (!near && !dual) return NO;
    HaogeTouchFlowBottomSession *session = [HaogeTouchFlowBottomSession new];
    session.haoge_touchflow_trigger = trigger;
    session.haoge_touchflow_farTrigger = dual ? far : nil;
    session.haoge_touchflow_nearEnabled = near;
    session.haoge_touchflow_snapshot = dual ? snapshot : nil;
    session.haoge_touchflow_view = view;
    if (dual) {
        session.haoge_touchflow_nearDistance = [self haoge_touchflow_number:@"bottomDistance"
            fallback:HaogeTouchFlowBottomNearDefault min:HaogeTouchFlowBottomNearMin max:HaogeTouchFlowBottomNearMax];
        session.haoge_touchflow_farDistance = [self haoge_touchflow_number:@"bottomFarDistance"
            fallback:HaogeTouchFlowBottomFarDefault min:HaogeTouchFlowBottomFarMin max:HaogeTouchFlowBottomFarMax];
    }
    if ([self haoge_touchflow_snapshot] != snapshot) return NO;
    objc_setAssociatedObject(gesture,&haoge_touchflow_bottomSessionKey,session,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.haoge_touchflow_claimedRecognizers addObject:gesture];
    return YES;
}
- (BOOL)haoge_touchflow_updateClaimedBottom:(UIGestureRecognizer *)gesture ended:(BOOL)ended cancelled:(BOOL)cancelled {
    HaogeTouchFlowBottomSession *session = objc_getAssociatedObject(gesture,&haoge_touchflow_bottomSessionKey);
    if (!session) return NO;
    // Our began was consumed: always consume its matching terminal callback,
    // even if preferences or in-flight eligibility changed.
    if (ended || cancelled) {
        objc_setAssociatedObject(gesture,&haoge_touchflow_bottomSessionKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.haoge_touchflow_claimedRecognizers removeObject:gesture];
    }
    if (cancelled) return YES;
    UIView *view = gesture.view;
    if (session.haoge_touchflow_farTrigger) {
        NSDictionary *snapshot = session.haoge_touchflow_snapshot;
        if (session.haoge_touchflow_invalidated || !view || view != session.haoge_touchflow_view ||
            [self haoge_touchflow_snapshot] != snapshot || haoge_touchflow_locked() ||
            ![self haoge_touchflow_portrait:view] || [[HaogeTouchFlowPanel haoge_touchflow_shared] haoge_touchflow_isVisible]) {
            session.haoge_touchflow_invalidated = YES;
            return YES;
        }
        CGPoint translation = [(UIPanGestureRecognizer *)gesture translationInView:view];
        HaogeTouchFlowBottomBand band = haoge_touchflow_bottomSample(&session->haoge_touchflow_hold,
            translation.x,translation.y,session.haoge_touchflow_nearDistance,session.haoge_touchflow_farDistance,
            CACurrentMediaTime(),ended);
        NSString *trigger = band == HaogeTouchFlowBottomFar ? session.haoge_touchflow_farTrigger :
            (band == HaogeTouchFlowBottomNear && session.haoge_touchflow_nearEnabled ? session.haoge_touchflow_trigger : nil);
        if (trigger) {
            __weak UIView *weakView = view;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIView *currentView = weakView;
                if (!currentView || [self haoge_touchflow_snapshot] != snapshot || haoge_touchflow_locked() ||
                    [[HaogeTouchFlowPanel haoge_touchflow_shared] haoge_touchflow_isVisible]) return;
                [self haoge_touchflow_fire:trigger view:currentView];
            });
        }
        return YES;
    }
    NSString *trigger = session.haoge_touchflow_trigger;
    if (!session.haoge_touchflow_fired && [self haoge_touchflow_enabledTrigger:trigger]) {
        CGPoint translation = [(UIPanGestureRecognizer *)gesture translationInView:view];
        if (haoge_touchflow_upward(translation.x,translation.y,
                [self haoge_touchflow_number:@"bottomDistance" fallback:110 min:60 max:200])) {
            session.haoge_touchflow_fired = YES;
            [self haoge_touchflow_fire:trigger view:view];
        }
    }
    return YES;
}
- (BOOL)haoge_touchflow_shouldReserveLockBottom:(UIGestureRecognizer *)gesture touch:(UITouch *)touch {
    if (!haoge_touchflow_locked() || ![self haoge_touchflow_allowed]) return NO;
    Class coverPan = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");
    if (!coverPan || ![gesture isKindOfClass:coverPan] || ![gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) return NO;
    if (((UIScreenEdgePanGestureRecognizer *)gesture).edges != UIRectEdgeBottom) return NO;
    return [self haoge_touchflow_bottomTriggerForPoint:[touch locationInView:gesture.view] view:gesture.view] != nil;
}
- (BOOL)haoge_touchflow_shouldSuppressStatusPull:(UIGestureRecognizer *)gesture {
    // Only a recognized horizontal/long gesture suppresses a competing system pull.
    for (HaogeTouchFlowBindingRecognizer *ours in self.haoge_touchflow_recognizers) {
        if (![ours.haoge_touchflow_region isEqual:@"status"] || !ours.haoge_touchflow_fired) continue;
        if (ours.state != UIGestureRecognizerStateBegan && ours.state != UIGestureRecognizerStateChanged) continue;
        if (ours.view.window == gesture.view.window) return YES;
    }
    return NO;
}
@end
