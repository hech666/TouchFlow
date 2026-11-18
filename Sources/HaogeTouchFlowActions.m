#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowShared.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>

static id haoge_touchflow_singleton(NSString *className) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(@"sharedInstance");
    return [cls respondsToSelector:selector] ? ((id (*)(id,SEL))objc_msgSend)(cls,selector) : nil;
}
static BOOL haoge_touchflow_callVoid(id target,NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector]) return NO;
    ((void (*)(id,SEL))objc_msgSend)(target,selector); return YES;
}
static BOOL haoge_touchflow_openURL(NSURL *url) {
    if (!url.scheme.length) return NO;
    UIApplication *app = UIApplication.sharedApplication;
    SEL selector = NSSelectorFromString(@"applicationOpenURL:");
    if ([app respondsToSelector:selector]) {
        ((void (*)(id,SEL,id))objc_msgSend)(app,selector,url); return YES;
    }
    [app openURL:url options:@{} completionHandler:^(BOOL success) {
        if (!success) NSLog(@"[TouchFlow] URL handler unavailable for scheme %@",url.scheme);
    }]; return YES;
}
static BOOL haoge_touchflow_flashlight(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ dlopen("/System/Library/PrivateFrameworks/SpringBoardUI.framework/SpringBoardUI",RTLD_LAZY); });
    id controller = haoge_touchflow_singleton(@"SBUIFlashlightController");
    SEL levelSelector = NSSelectorFromString(@"level");
    if ([controller respondsToSelector:levelSelector]) {
        NSInteger level = ((NSInteger (*)(id,SEL))objc_msgSend)(controller,levelSelector);
        SEL selector = NSSelectorFromString(level > 0 ? @"turnFlashlightOffForReason:" : @"turnFlashlightOnForReason:");
        if ([controller respondsToSelector:selector]) {
            ((void (*)(id,SEL,id))objc_msgSend)(controller,selector,@"Control Center");
            if (!level) {
                SEL setLevel = NSSelectorFromString(@"setLevel:");
                if ([controller respondsToSelector:setLevel]) ((void (*)(id,SEL,NSInteger))objc_msgSend)(controller,setLevel,4);
            }
            return YES;
        }
    }
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device.hasTorch || !device.torchAvailable) return NO;
    NSError *error = nil;
    if (![device lockForConfiguration:&error]) return NO;
    @try {
        if (device.torchActive) [device setTorchMode:AVCaptureTorchModeOff];
        else [device setTorchModeOnWithLevel:1.0 error:&error];
    } @finally { [device unlockForConfiguration]; }
    return error == nil;
}
static BOOL haoge_touchflow_media(NSInteger command) {
    typedef Boolean (*HaogeTouchFlowMediaCommand)(unsigned int,CFDictionaryRef);
    static HaogeTouchFlowMediaCommand send; static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);
        if (handle) send = (HaogeTouchFlowMediaCommand)dlsym(handle,"MRMediaRemoteSendCommand");
    });
    if (!send) return NO;
    return send((unsigned int)command,NULL);
}
static BOOL haoge_touchflow_perform(NSString *action,NSString *value) {
    UIApplication *app = UIApplication.sharedApplication;
    if ([action isEqual:@"controlCenter"]) {
        id controller = haoge_touchflow_singleton(@"SBControlCenterController");
        SEL selector = NSSelectorFromString(@"presentAnimated:completion:");
        if (![controller respondsToSelector:selector]) return NO;
        ((void (*)(id,SEL,BOOL,id))objc_msgSend)(controller,selector,YES,nil); return YES;
    }
    if ([action isEqual:@"lock"]) return haoge_touchflow_callVoid(app,@"_simulateLockButtonPress");
    if ([action isEqual:@"appSwitcher"]) {
        id controller = haoge_touchflow_singleton(@"SBUIController");
        return haoge_touchflow_callVoid(controller,@"handleHomeButtonDoublePressDown") || haoge_touchflow_callVoid(controller,@"handleMenuDoubleTap");
    }
    if ([action isEqual:@"screenshot"]) {
        if (haoge_touchflow_callVoid(app,@"takeScreenshot")) return YES;
        SEL selector = NSSelectorFromString(@"_takeScreenshotAndEdit:");
        if (![app respondsToSelector:selector]) return NO;
        ((void (*)(id,SEL,BOOL))objc_msgSend)(app,selector,NO); return YES;
    }
    if ([action isEqual:@"flashlight"]) return haoge_touchflow_flashlight();
    if ([action isEqual:@"playPause"]) return haoge_touchflow_media(2);
    if ([action isEqual:@"nextTrack"]) return haoge_touchflow_media(4);
    if ([action isEqual:@"previousTrack"]) return haoge_touchflow_media(5);
    if ([action isEqual:@"openApp"]) {
        if ([value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"] invertedSet]].location != NSNotFound) return NO;
        SEL selector = NSSelectorFromString(@"launchApplicationWithIdentifier:suspended:");
        if (![app respondsToSelector:selector]) return NO;
        ((void (*)(id,SEL,id,BOOL))objc_msgSend)(app,selector,value,NO); return YES;
    }
    if ([action isEqual:@"runShortcut"]) {
        NSURLComponents *parts = [NSURLComponents componentsWithString:@"shortcuts://run-shortcut"];
        parts.queryItems = @[[NSURLQueryItem queryItemWithName:@"name" value:value]];
        return haoge_touchflow_openURL(parts.URL);
    }
    if ([action isEqual:@"openURL"]) return haoge_touchflow_openURL([NSURL URLWithString:value]);
    return NO;
}
void haoge_touchflow_executeBinding(NSDictionary *binding) {
    if (!NSThread.isMainThread) { NSDictionary *copy = [binding copy]; dispatch_async(dispatch_get_main_queue(), ^{ haoge_touchflow_executeBinding(copy); }); return; }
    if (![binding isKindOfClass:[NSDictionary class]] || !haoge_touchflow_bindingEnabled(binding)) return;
    NSString *action = binding[@"action"];
    BOOL found = NO;
    for (NSDictionary *entry in haoge_touchflow_actionCatalog()) if ([entry[@"identifier"] isEqual:action]) { found = YES; break; }
    if (!found || [action isEqual:@"none"]) return;
    NSString *value = [binding[@"value"] isKindOfClass:[NSString class]] ? binding[@"value"] : @"";
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (haoge_touchflow_actionNeedsValue(action) && (!value.length || value.length > 4096)) return;
    @try {
        if (!haoge_touchflow_perform(action,value)) NSLog(@"[TouchFlow] Action unavailable: %@",action);
    } @catch (NSException *exception) { NSLog(@"[TouchFlow] Action %@ failed: %@",action,exception.name); }
}
