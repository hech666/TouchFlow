#pragma once
#import <UIKit/UIKit.h>
@interface HaogeTouchFlowPanelItemsController : UITableViewController
+ (instancetype)haoge_touchflow_controllerWithTrigger:(NSString *)trigger;
@end
@interface HaogeTouchFlowPanelActionPickerController : UITableViewController
+ (instancetype)haoge_touchflow_controllerForTrigger:(NSString *)trigger existingItems:(NSArray<NSDictionary *> *)items;
@end
@interface HaogeTouchFlowPanelAppearanceController : UITableViewController
@end
