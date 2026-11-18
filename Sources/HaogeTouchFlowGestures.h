#pragma once
#import <UIKit/UIKit.h>
@interface HaogeTouchFlowGestures : NSObject
+ (instancetype)haoge_touchflow_shared;
- (void)haoge_touchflow_start;
- (void)haoge_touchflow_attachSystemWindow:(UIWindow *)window;
- (void)haoge_touchflow_attachDesktop:(UIView *)view;
- (BOOL)haoge_touchflow_claimBottomFromManager:(id)manager gesture:(UIGestureRecognizer *)gesture;
- (BOOL)haoge_touchflow_updateClaimedBottom:(UIGestureRecognizer *)gesture ended:(BOOL)ended cancelled:(BOOL)cancelled;
- (BOOL)haoge_touchflow_shouldReserveLockBottom:(UIGestureRecognizer *)gesture touch:(UITouch *)touch;
- (BOOL)haoge_touchflow_shouldSuppressStatusPull:(UIGestureRecognizer *)gesture;
@end
