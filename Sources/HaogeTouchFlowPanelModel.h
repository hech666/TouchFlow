#pragma once
#import <Foundation/Foundation.h>
#import "HaogeTouchFlowActions.h"
// Added in v2 without changing the v1 direct-action fields.
// bindings[id]: mode="direct"(default)|"panel"; panelItems=[{id,action,value,title,symbol}].
// Runtime and Preferences share these functions, not Objective-C singleton classes.
NSArray<NSDictionary *> *haoge_touchflow_panelItems(id input);
BOOL haoge_touchflow_hasPanelMode(NSDictionary *binding);
NSString *haoge_touchflow_bindingSummary(NSDictionary *binding);
NSString *haoge_touchflow_actionSymbol(NSString *action);
NSString *haoge_touchflow_panelItemTitle(NSDictionary *item);
NSArray<NSDictionary *> *haoge_touchflow_panelSettings(void);
double haoge_touchflow_panelNumber(NSDictionary *values,NSString *key);
BOOL haoge_touchflow_panelFlag(NSDictionary *values,NSString *key,BOOL fallback);
