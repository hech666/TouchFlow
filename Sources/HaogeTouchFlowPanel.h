#pragma once
#import <UIKit/UIKit.h>
@interface HaogeTouchFlowPanel : NSObject
+ (instancetype)haoge_touchflow_shared;
- (void)haoge_touchflow_showBinding:(NSDictionary *)binding trigger:(NSString *)trigger scene:(UIWindowScene *)scene sourceWindow:(UIWindow *)sourceWindow;
- (BOOL)haoge_touchflow_isVisible;
- (void)haoge_touchflow_dismiss;
@end
