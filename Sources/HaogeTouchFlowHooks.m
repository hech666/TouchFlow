#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "HaogeTouchFlowGestures.h"
#import "HaogeTouchFlowConfig.h"

static void (*haoge_touchflow_origWindow)(id,SEL);
static void (*haoge_touchflow_origAdd)(id,SEL,id,NSInteger);
static void (*haoge_touchflow_origDesktopWindow)(id,SEL);
static void (*haoge_touchflow_origDesktopSuperview)(id,SEL);
static BOOL (*haoge_touchflow_origLockDelegate)(id,SEL,id,id);
static void (*haoge_touchflow_origStatusPull)(id,SEL,id);
// Original code proves sender=x2, gesture=x3 and two floating arguments=d0/d1.
typedef void (*HaogeTouchFlowFluidIMP)(id,SEL,id,double,double,id);
static HaogeTouchFlowFluidIMP haoge_touchflow_origBegan,haoge_touchflow_origUpdated,haoge_touchflow_origEnded,haoge_touchflow_origCancelled;

static void haoge_touchflow_attachManagerWindow(id manager) {
    SEL selector = NSSelectorFromString(@"windowForSystemGestures");
    if ([manager respondsToSelector:selector]) {
        id window = ((id (*)(id,SEL))objc_msgSend)(manager,selector);
        if ([window isKindOfClass:[UIWindow class]])
            [[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_attachSystemWindow:window];
    }
}
static void haoge_touchflow_windowHook(id self,SEL cmd) {
    haoge_touchflow_origWindow(self,cmd); haoge_touchflow_attachManagerWindow(self);
}
static void haoge_touchflow_addHook(id self,SEL cmd,id recognizer,NSInteger type) {
    haoge_touchflow_origAdd(self,cmd,recognizer,type); haoge_touchflow_attachManagerWindow(self);
}
static void haoge_touchflow_desktopWindowHook(id self,SEL cmd) {
    haoge_touchflow_origDesktopWindow(self,cmd);
    [[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_attachDesktop:self];
}
static void haoge_touchflow_desktopSuperviewHook(id self,SEL cmd) {
    haoge_touchflow_origDesktopSuperview(self,cmd);
    [[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_attachDesktop:self];
}
static BOOL haoge_touchflow_lockDelegateHook(id self,SEL cmd,id gesture,id touch) {
    if ([[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_shouldReserveLockBottom:gesture touch:touch]) return NO;
    return haoge_touchflow_origLockDelegate(self,cmd,gesture,touch);
}
static void haoge_touchflow_statusPullHook(id self,SEL cmd,id gesture) {
    if (![[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_shouldSuppressStatusPull:gesture])
        haoge_touchflow_origStatusPull(self,cmd,gesture);
}
static void haoge_touchflow_beganHook(id self,SEL cmd,id sender,double distance,double velocity,id gesture) {
    if ([[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_claimBottomFromManager:self gesture:gesture]) return;
    haoge_touchflow_origBegan(self,cmd,sender,distance,velocity,gesture);
}
static void haoge_touchflow_updatedHook(id self,SEL cmd,id sender,double distance,double velocity,id gesture) {
    if ([[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_updateClaimedBottom:gesture ended:NO cancelled:NO]) return;
    haoge_touchflow_origUpdated(self,cmd,sender,distance,velocity,gesture);
}
static void haoge_touchflow_endedHook(id self,SEL cmd,id sender,double distance,double velocity,id gesture) {
    if ([[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_updateClaimedBottom:gesture ended:YES cancelled:NO]) return;
    haoge_touchflow_origEnded(self,cmd,sender,distance,velocity,gesture);
}
static void haoge_touchflow_cancelledHook(id self,SEL cmd,id sender,double distance,double velocity,id gesture) {
    if ([[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_updateClaimedBottom:gesture ended:NO cancelled:YES]) return;
    haoge_touchflow_origCancelled(self,cmd,sender,distance,velocity,gesture);
}
static BOOL haoge_touchflow_hook(NSString *className,NSString *name,IMP replacement,IMP *original,BOOL fluid) {
    Class cls = NSClassFromString(className); SEL selector = NSSelectorFromString(name);
    Method method = cls ? class_getInstanceMethod(cls,selector) : NULL;
    if (!method) { NSLog(@"[TouchFlow] Missing %@ %@",className,name); return NO; }
    if (fluid) {
        // Decline an ABI changed by another OS. Struct/float encodings are not interchangeable.
        if (method_getNumberOfArguments(method) != 6) return NO;
        const char *type = method_getArgumentType(method,3); if (!type || type[0] != 'd') return NO;
        type = method_getArgumentType(method,4); if (!type || type[0] != 'd') return NO;
        type = method_getArgumentType(method,5); if (!type || type[0] != '@') return NO;
    }
    MSHookMessageEx(cls,selector,replacement,original); return YES;
}
void haoge_touchflow_installHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        haoge_touchflow_hook(@"SBSystemGestureManager",@"_configureForNewSystemGestureWindowIfNecessary",(IMP)haoge_touchflow_windowHook,(IMP *)&haoge_touchflow_origWindow,NO);
        haoge_touchflow_hook(@"SBSystemGestureManager",@"addGestureRecognizer:withType:",(IMP)haoge_touchflow_addHook,(IMP *)&haoge_touchflow_origAdd,NO);
        haoge_touchflow_hook(@"SBRootFolderView",@"didMoveToWindow",(IMP)haoge_touchflow_desktopWindowHook,(IMP *)&haoge_touchflow_origDesktopWindow,NO);
        haoge_touchflow_hook(@"SBRootFolderView",@"didMoveToSuperview",(IMP)haoge_touchflow_desktopSuperviewHook,(IMP *)&haoge_touchflow_origDesktopSuperview,NO);
        haoge_touchflow_hook(@"SBCoverSheetSystemGesturesDelegate",@"gestureRecognizer:shouldReceiveTouch:",(IMP)haoge_touchflow_lockDelegateHook,(IMP *)&haoge_touchflow_origLockDelegate,NO);
        haoge_touchflow_hook(@"SBControlCenterController",@"_handleStatusBarPullDownGesture:",(IMP)haoge_touchflow_statusPullHook,(IMP *)&haoge_touchflow_origStatusPull,NO);
        NSArray *names = @[@"grabberTongueBeganPulling:withDistance:andVelocity:andGesture:",@"grabberTongueUpdatedPulling:withDistance:andVelocity:andGesture:",@"grabberTongueEndedPulling:withDistance:andVelocity:andGesture:",@"grabberTongueCanceledPulling:withDistance:andVelocity:andGesture:"];
        Class manager = NSClassFromString(@"SBFluidSwitcherGestureManager");
        BOOL complete = manager != Nil;
        for (NSString *name in names) {
            Method method = manager ? class_getInstanceMethod(manager,NSSelectorFromString(name)) : NULL;
            if (!method || method_getNumberOfArguments(method)!=6) { complete = NO; break; }
            const char *type = method_getArgumentType(method,3); if (!type || type[0]!='d') complete=NO;
            type = method_getArgumentType(method,4); if (!type || type[0]!='d') complete=NO;
            type = method_getArgumentType(method,5); if (!type || type[0]!='@') complete=NO;
        }
        // Intercept an entire lifecycle or none; never suppress began without a matching end hook.
        if (complete) {
            haoge_touchflow_hook(@"SBFluidSwitcherGestureManager",names[0],(IMP)haoge_touchflow_beganHook,(IMP *)&haoge_touchflow_origBegan,YES);
            haoge_touchflow_hook(@"SBFluidSwitcherGestureManager",names[1],(IMP)haoge_touchflow_updatedHook,(IMP *)&haoge_touchflow_origUpdated,YES);
            haoge_touchflow_hook(@"SBFluidSwitcherGestureManager",names[2],(IMP)haoge_touchflow_endedHook,(IMP *)&haoge_touchflow_origEnded,YES);
            haoge_touchflow_hook(@"SBFluidSwitcherGestureManager",names[3],(IMP)haoge_touchflow_cancelledHook,(IMP *)&haoge_touchflow_origCancelled,YES);
        } else NSLog(@"[TouchFlow] Bottom lifecycle ABI unavailable; unlocked bottom hooks skipped.");
    });
}
