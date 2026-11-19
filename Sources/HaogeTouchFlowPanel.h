#pragma once
#import <UIKit/UIKit.h>
@interface HaogeTouchFlowPanel : NSObject
+ (instancetype)haoge_touchflow_shared;
- (void)haoge_touchflow_showBinding:(NSDictionary *)binding trigger:(NSString *)trigger scene:(UIWindowScene *)scene sourceWindow:(UIWindow *)sourceWindow;
- (BOOL)haoge_touchflow_isVisible;
- (UIWindow *)haoge_touchflow_panelWindow;
- (void)haoge_touchflow_dismiss;
// Point in `window`'s coordinate space. Returns YES when the tap was outside the
// panel sheet and the panel was closed because of it.
- (BOOL)haoge_touchflow_handleOutsideTapInWindow:(UIWindow *)window point:(CGPoint)point;
@end
