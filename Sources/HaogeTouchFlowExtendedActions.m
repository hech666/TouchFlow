#import "HaogeTouchFlowExtendedActions.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <string.h>
#import <spawn.h>
#import <unistd.h>
#import <sys/wait.h>
#import <errno.h>
#import "HaogeTouchFlowPaths.h"

extern char **environ;

// Validate private ABI before casting objc_msgSend. Foundation encodes C++ bool
// as B; older Objective-C BOOL runtimes may use c instead.
static BOOL haoge_touchflow_signature(id target, SEL selector, const char *result, NSArray<NSString *> *arguments) {
    if (![target respondsToSelector:selector]) return NO;
    NSMethodSignature *signature=[target methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments!=arguments.count+2) return NO;
    if (!strchr(result,signature.methodReturnType[0])) return NO;
    for (NSUInteger i=0;i<arguments.count;i++) {
        const char *type=[signature getArgumentTypeAtIndex:i+2];
        if (!strchr(arguments[i].UTF8String,type[0])) return NO;
    }
    return YES;
}
static id haoge_touchflow_sharedObject(NSString *name, NSString *method) {
    Class cls=NSClassFromString(name); SEL selector=NSSelectorFromString(method);
    if (!haoge_touchflow_signature(cls,selector,"@",@[])) return nil;
    return ((id (*)(id,SEL))objc_msgSend)(cls,selector);
}
static BOOL haoge_touchflow_respring(void) {
    // OneStepX 0x14814: sbreload, resolved through the jailbreak root.
    // Do not substitute its separate killall/-9 action that kills background apps.
    NSString *tool=haoge_touchflow_resourcePath(@"/usr/bin/sbreload");
    if (access(tool.fileSystemRepresentation,X_OK)!=0) return NO;
    pid_t pid=0;
    char *arguments[]={(char *)"sbreload",NULL};
    int result=posix_spawn(&pid,tool.fileSystemRepresentation,NULL,NULL,arguments,environ);
    if (result) { NSLog(@"[TouchFlow] sbreload spawn failed: %d",result);return NO; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        int status=0;
        while (waitpid(pid,&status,0)==-1 && errno==EINTR) {}
    });
    return YES;
}
static BOOL haoge_touchflow_toggleRecording(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ dlopen("/System/Library/Frameworks/ReplayKit.framework/ReplayKit",RTLD_LAZY); });
    id recorder=haoge_touchflow_sharedObject(@"RPScreenRecorder",@"sharedRecorder");
    SEL state=NSSelectorFromString(@"systemRecording");
    if (!haoge_touchflow_signature(recorder,state,"Bc",@[])) return NO;
    BOOL recording=((BOOL (*)(id,SEL))objc_msgSend)(recorder,state);
    SEL selector=NSSelectorFromString(recording?@"stopSystemRecording:":@"startSystemRecordingWithMicrophoneEnabled:handler:");
    if (!haoge_touchflow_signature(recorder,selector,"v",recording?@[@"@"]:@[@"Bc",@"@"])) return NO;
    // OneStepX's original two completion blocks are both v16@?0@"NSError"8.
    // The system stop operation owns saving to Photos; no in-app capture API.
    static BOOL busy=NO;
    static NSUInteger generation=0;
    if (busy) return YES;
    busy=YES; NSUInteger request=++generation;
    void (^completion)(NSError *)=^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (request==generation) busy=NO;
            if (error) NSLog(@"[TouchFlow] System recording %@ failed: %@",recording?@"stop":@"start",error);
        });
    };
    // Do not leave the action permanently busy after a service interruption.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(10*NSEC_PER_SEC)),dispatch_get_main_queue(), ^{
        if (request==generation) busy=NO;
    });
    if (recording) ((void (*)(id,SEL,id))objc_msgSend)(recorder,selector,completion);
    else ((void (*)(id,SEL,BOOL,id))objc_msgSend)(recorder,selector,NO,completion);
    return YES;
}
static BOOL haoge_touchflow_showKayoko(void) {
    // Exact notification from Kayoko v33 NotificationKeys.h; no second copy of
    // Kayoko's UI and no modification of its keyboard or automatic-paste logic.
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("codes.aurora.kayoko.core.show"),NULL,NULL,true);
    return YES;
}

BOOL haoge_touchflow_performExtendedAction(NSString *action) {
    if (!NSThread.isMainThread) return NO;
    if ([action isEqualToString:@"respring"]) return haoge_touchflow_respring();
    if ([action isEqualToString:@"screenRecording"]) return haoge_touchflow_toggleRecording();
    if ([action isEqualToString:@"kayokoClipboard"]) return haoge_touchflow_showKayoko();
    return NO;
}
