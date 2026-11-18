#import <Foundation/Foundation.h>
#import "../Sources/HaogeTouchFlowShared.h"
#import "../Sources/HaogeTouchFlowPanelModel.h"
#import <math.h>
int main(void) {
 @autoreleasepool {
  NSDictionary *legacy=@{@"enabled":@YES,@"action":@"screenshot",@"value":@""};
  NSCAssert(haoge_touchflow_bindingEnabled(legacy),@"old bindings still active");
  NSCAssert(!haoge_touchflow_hasPanelMode(legacy),@"missing mode remains direct");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"mode":@"panel",@"panelItems":@[]}),@"empty panel not captured");
  NSDictionary *valid=@{@"id":@"a",@"action":@"controlCenter",@"title":@"控制中心"};
  NSDictionary *panelOnly=@{@"enabled":@YES,@"mode":@"panel",@"panelItems":@[valid]};
  NSCAssert(haoge_touchflow_bindingEnabled(panelOnly) && haoge_touchflow_hasPanelMode(panelOnly),@"panel mode requires panel items, not legacy action");
   NSCAssert([haoge_touchflow_bindingSummary(legacy) containsString:@"截图"],@"legacy direct summary remains available");
   NSCAssert(haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"mode":@"panel",@"panelItems":@[valid]}),@"panel can enable without direct action");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{@"enabled":@NO,@"mode":@"panel",@"panelItems":@[valid]}),@"master binding switch honored");
  NSCAssert(haoge_touchflow_panelItems(@42).count==0,@"invalid list");
  NSCAssert(haoge_touchflow_panelItems(@[@42,NSNull.null,@{},@{@"action":@42},@{@"action":@"none"},@{@"action":@"unknown"}]).count==0,@"bad actions skipped");
  NSCAssert(haoge_touchflow_panelItems(@[@{@"action":@"openApp"},@{@"action":@"openURL",@"value":@"example"},@{@"action":@"runShortcut",@"value":@"  "}]).count==0,@"required params validated");
  NSArray *items=haoge_touchflow_panelItems(@[valid,@{@"id":@"a",@"action":@"lock"},@{@"action":@"screenshot"}]);
  NSCAssert(items.count==3,@"independent duplicate actions keep order");
  NSCAssert(![items[0][@"id"] isEqual:items[1][@"id"]],@"unique IDs for duplicates");
  NSCAssert([items[0][@"action"] isEqual:@"controlCenter"] && [items[2][@"action"] isEqual:@"screenshot"],@"stable item order");
  NSCAssert([haoge_touchflow_panelItems(items) isEqual:items],@"normalization is idempotent");
  NSMutableArray *many=[NSMutableArray array];for (int i=0;i<100;i++) [many addObject:valid];
  NSCAssert(haoge_touchflow_panelItems(many).count==30,@"strict 30 item cap");
  NSMutableArray *longText=[NSMutableArray array];for (int i=0;i<5000;i++) [longText addObject:@"a"];
  NSString *str=[longText componentsJoinedByString:@""];
  NSDictionary *trimmed=haoge_touchflow_panelItems(@[@{@"action":@"openURL",@"value":[@"https://example.com/" stringByAppendingString:str],@"title":str,@"symbol":str}]).firstObject;
  NSCAssert([trimmed[@"value"] length]==4096 && [trimmed[@"title"] length]==80 && [trimmed[@"symbol"] length]==128,@"bounded user strings");
  for (NSDictionary *field in haoge_touchflow_panelSettings()) {
   NSString *key=field[@"key"];double lo=[field[@"min"] doubleValue],hi=[field[@"max"] doubleValue],def=[field[@"default"] doubleValue];
   NSCAssert(fabs(haoge_touchflow_panelNumber(@{},key)-def)<1e-6,@"missing uses default");
   NSCAssert(fabs(haoge_touchflow_panelNumber(@{key:@(NAN)},key)-def)<1e-6,@"NaN uses default");
   NSCAssert(fabs(haoge_touchflow_panelNumber(@{key:@(-1000)},key)-lo)<1e-6,@"minimum clamp");
   NSCAssert(fabs(haoge_touchflow_panelNumber(@{key:@10000},key)-hi)<1e-6,@"maximum clamp");
  }
  puts("PASS panel model: legacy compatibility, order, IDs, parameters, 30-item cap, bounds and defaults");
 }
 return 0;
}
