#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <spawn.h>
#import <unistd.h>
#import <sys/wait.h>
#import <errno.h>
#import <string.h>

static NSUInteger haoge_touchflow_test_starts,haoge_touchflow_test_stops,haoge_touchflow_test_spawns,haoge_touchflow_test_notifications;
static BOOL haoge_touchflow_test_active,haoge_touchflow_test_executable=YES,haoge_touchflow_test_microphone=YES;
static int haoge_touchflow_test_spawnError=0;
static NSString *haoge_touchflow_test_notification,*haoge_touchflow_test_path;
static void (^haoge_touchflow_test_completion)(NSError *);

@interface RPScreenRecorder : NSObject
+ (instancetype)sharedRecorder;
- (bool)systemRecording;
- (void)startSystemRecordingWithMicrophoneEnabled:(bool)microphone handler:(void (^)(NSError *))handler;
- (void)stopSystemRecording:(void (^)(NSError *))handler;
@end
@implementation RPScreenRecorder
+ (instancetype)sharedRecorder { static id recorder;static dispatch_once_t once;dispatch_once(&once,^{recorder=[self new];});return recorder; }
- (bool)systemRecording { return haoge_touchflow_test_active; }
- (void)startSystemRecordingWithMicrophoneEnabled:(bool)microphone handler:(void (^)(NSError *))handler {
    haoge_touchflow_test_starts++;haoge_touchflow_test_microphone=microphone;haoge_touchflow_test_active=YES;haoge_touchflow_test_completion=[handler copy];
}
- (void)stopSystemRecording:(void (^)(NSError *))handler {
    haoge_touchflow_test_stops++;haoge_touchflow_test_active=NO;haoge_touchflow_test_completion=[handler copy];
}
@end

static void *haoge_touchflow_test_dlopen(const char *path,int mode) { (void)path;(void)mode;return (void *)1; }
static int haoge_touchflow_test_access(const char *path,int mode) {
    haoge_touchflow_test_path=[NSString stringWithUTF8String:path];
    NSCAssert(mode==X_OK,@"test checks executable permission");
    return haoge_touchflow_test_executable?0:-1;
}
static int haoge_touchflow_test_spawn(pid_t *pid,const char *path,const posix_spawn_file_actions_t *actions,const posix_spawnattr_t *attributes,char *const argv[],char *const env[]) {
    (void)actions;(void)attributes;(void)env;
    NSCAssert([[NSString stringWithUTF8String:path] hasSuffix:@"/sbreload"],@"only sbreload is executed");
    NSCAssert(strcmp(argv[0],"sbreload")==0 && argv[1]==NULL,@"no killall or extra arguments");
    haoge_touchflow_test_spawns++;*pid=12345;return haoge_touchflow_test_spawnError;
}
static pid_t haoge_touchflow_test_waitpid(pid_t pid,int *status,int options) { (void)options;*status=0;return pid; }
static void haoge_touchflow_test_post(CFNotificationCenterRef center,CFStringRef name,const void *object,CFDictionaryRef info,Boolean immediate) {
    NSCAssert(center==CFNotificationCenterGetDarwinNotifyCenter() && !object && !info && immediate,@"Darwin show notification contract");
    haoge_touchflow_test_notifications++;haoge_touchflow_test_notification=[(__bridge NSString *)name copy];
}
#define dlopen haoge_touchflow_test_dlopen
#define access haoge_touchflow_test_access
#define posix_spawn haoge_touchflow_test_spawn
#define waitpid haoge_touchflow_test_waitpid
#define CFNotificationCenterPostNotification haoge_touchflow_test_post
#import "../Sources/HaogeTouchFlowExtendedActions.m"
#undef dlopen
#undef access
#undef posix_spawn
#undef waitpid
#undef CFNotificationCenterPostNotification

static void haoge_touchflow_test_finish(NSError *error) {
    NSCAssert(haoge_touchflow_test_completion!=nil,@"system callback was supplied");
    haoge_touchflow_test_completion(error);haoge_touchflow_test_completion=nil;
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:0.05];
    while (until.timeIntervalSinceNow>0) [[NSRunLoop mainRunLoop] runUntilDate:until];
}
int main(void) { @autoreleasepool {
    NSCAssert(NSThread.isMainThread,@"runtime test on main thread");
    NSCAssert(!haoge_touchflow_performExtendedAction(@"unknown"),@"unknown is rejected");
    NSCAssert(!haoge_touchflow_signature([NSObject new],@selector(description),"v",@[]),@"wrong return ABI rejected");
    NSCAssert(!haoge_touchflow_signature([NSObject new],@selector(description),"@",@[@"@"]),@"wrong argument count rejected");
    NSCAssert(haoge_touchflow_performExtendedAction(@"screenRecording"),@"start system recording");
    NSCAssert(haoge_touchflow_test_starts==1 && !haoge_touchflow_test_microphone,@"one start with microphone off");
    NSCAssert(haoge_touchflow_performExtendedAction(@"screenRecording") && haoge_touchflow_test_stops==0,@"busy request does not immediately stop");
    haoge_touchflow_test_finish(nil);
    NSCAssert(haoge_touchflow_performExtendedAction(@"screenRecording") && haoge_touchflow_test_stops==1,@"active system recording is stopped");
    haoge_touchflow_test_finish(nil);
    NSCAssert(haoge_touchflow_performExtendedAction(@"screenRecording") && haoge_touchflow_test_starts==2,@"restart after completed stop");
    haoge_touchflow_test_active=NO;
    haoge_touchflow_test_finish([NSError errorWithDomain:@"MockReplayKit" code:1 userInfo:nil]);
    NSCAssert(haoge_touchflow_performExtendedAction(@"screenRecording") && haoge_touchflow_test_starts==3,@"error completion releases busy state");
    haoge_touchflow_test_finish(nil);
    NSCAssert(haoge_touchflow_performExtendedAction(@"kayokoClipboard"),@"Kayoko accepted");
    NSCAssert(haoge_touchflow_test_notifications==1 && [haoge_touchflow_test_notification isEqual:@"codes.aurora.kayoko.core.show"],@"exact original Kayoko notification");
    haoge_touchflow_test_executable=NO;
    NSCAssert(!haoge_touchflow_performExtendedAction(@"respring") && !haoge_touchflow_test_spawns,@"missing sbreload never spawns");
    haoge_touchflow_test_executable=YES;
    NSCAssert(haoge_touchflow_performExtendedAction(@"respring") && haoge_touchflow_test_spawns==1,@"available sbreload uses spawn");
    haoge_touchflow_test_spawnError=EACCES;
    NSCAssert(!haoge_touchflow_performExtendedAction(@"respring"),@"spawn error returned");
    NSCAssert([haoge_touchflow_test_path hasSuffix:@"/sbreload"],@"jailbreak path resolved");
    puts("PASS extended actions: real objc dispatch against mocks, ABI guards, system-recording toggle/busy/error, exact Kayoko notification, sbreload path/arguments/errors; no device action executed");
} return 0; }
