#pragma once

#import <Foundation/Foundation.h>

@interface HaogeTouchFlowConfig : NSObject
+ (instancetype)haoge_touchflow_shared;
- (BOOL)haoge_touchflow_isEnabled;
- (id)haoge_touchflow_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)haoge_touchflow_reload;
- (NSDictionary *)haoge_touchflow_snapshot;
@end
