#import <UIKit/UIKit.h>
#import "HaogeTouchFlowGestures.h"
#import "HaogeTouchFlowConfig.h"
extern void haoge_touchflow_installHooks(void);

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_start];
}
%end

%ctor {
    @autoreleasepool {
        [HaogeTouchFlowConfig haoge_touchflow_shared];
        haoge_touchflow_installHooks();
        dispatch_async(dispatch_get_main_queue(), ^{
            [[HaogeTouchFlowGestures haoge_touchflow_shared] haoge_touchflow_start];
        });
    }
}
