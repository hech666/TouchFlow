#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPreferences.h"

@interface HaogeTouchFlowConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void haoge_touchflow_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    HaogeTouchFlowConfig *config = (__bridge HaogeTouchFlowConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config haoge_touchflow_reload];
    });
}

@implementation HaogeTouchFlowConfig

+ (instancetype)haoge_touchflow_shared {
    static HaogeTouchFlowConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.haoge.touchflow.preferences", DISPATCH_QUEUE_SERIAL);
        [self haoge_touchflow_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, haoge_touchflow_preferencesDidChange,
            (__bridge CFStringRef)HaogeTouchFlowPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self haoge_touchflow_reload]; });
    }
    return self;
}

- (void)haoge_touchflow_reload {
    self.snapshot = haoge_touchflow_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HaogeTouchFlowPreferencesChanged object:self];
    });
}

- (id)haoge_touchflow_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (NSDictionary *)haoge_touchflow_snapshot { return self.snapshot ?: @{}; }

- (BOOL)haoge_touchflow_isEnabled {
    id value = [self haoge_touchflow_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
