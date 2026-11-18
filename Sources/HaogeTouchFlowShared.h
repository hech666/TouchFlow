#pragma once
#import <Foundation/Foundation.h>

// One independent binding per trigger. Values below are the configuration contract.
static NSString * const HaogeTouchFlowBindingsKey = @"bindings";
static inline NSArray<NSString *> *haoge_touchflow_triggerIDs(void) {
    return @[@"statusLeftTap", @"statusLeftDoubleTap", @"statusLeftLongPress",
             @"statusLeftSwipeLeft", @"statusLeftSwipeRight", @"statusRightTap",
             @"statusRightDoubleTap", @"statusRightLongPress", @"statusRightSwipeLeft",
             @"statusRightSwipeRight", @"bottomLeft", @"bottomRight", @"desktopLongPress"];
}
static inline NSArray<NSString *> *haoge_touchflow_triggerTitles(void) {
    return @[@"状态栏左侧单击", @"状态栏左侧双击", @"状态栏左侧长按",
             @"状态栏左侧左滑", @"状态栏左侧右滑", @"状态栏右侧单击",
             @"状态栏右侧双击", @"状态栏右侧长按", @"状态栏右侧左滑",
             @"状态栏右侧右滑", @"底部左侧上滑", @"底部右侧上滑", @"桌面空白处长按"];
}
// Dictionary schema: bindings[triggerID] = { enabled: BOOL, action: NSString, value: NSString }.
// Global keys: enabled=NO, haptics=YES, allowLocked=NO, bottomDistance=110,
// statusDistance=60, sidePercent=25 (10..33), longPressDuration=0.55 (0.35..1.2).
// "none" never reserves a gesture. Every module must treat malformed dictionaries as disabled.
static inline NSDictionary *haoge_touchflow_binding(NSDictionary *snapshot, NSString *trigger) {
    id bindings = snapshot[HaogeTouchFlowBindingsKey];
    id binding = [bindings isKindOfClass:[NSDictionary class]] ? bindings[trigger] : nil;
    return [binding isKindOfClass:[NSDictionary class]] ? binding : @{};
}
static inline BOOL haoge_touchflow_bindingEnabled(NSDictionary *binding) {
    id enabled = binding[@"enabled"], action = binding[@"action"];
    return [enabled isKindOfClass:[NSNumber class]] && [enabled boolValue] &&
        [action isKindOfClass:[NSString class]] && [action length] && ![action isEqual:@"none"];
}
