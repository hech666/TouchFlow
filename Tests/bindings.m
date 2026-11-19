#import <Foundation/Foundation.h>
#import "../Sources/HaogeTouchFlowShared.h"
#import "../Sources/HaogeTouchFlowActions.h"
int main(void) {
 @autoreleasepool {
  NSCAssert(haoge_touchflow_triggerIDs().count==13,@"13 triggers");
  NSCAssert(haoge_touchflow_triggerTitles().count==13,@"13 titles");
  NSCAssert([NSSet setWithArray:haoge_touchflow_triggerIDs()].count==13,@"unique trigger identities");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{}),@"missing binding stays inactive");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"action":@"none"}),@"none never reserves gestures");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{@"enabled":@"YES",@"action":@"lock"}),@"non-number enable rejected");
  NSCAssert(!haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"action":@42}),@"non-string action rejected");
  NSCAssert(haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"action":@"lock"}),@"valid binding recognized");
  NSCAssert(haoge_touchflow_binding(@{@"bindings":@42},@"bottomLeft").count==0,@"invalid bindings container rejected");
  NSCAssert(haoge_touchflow_binding(@{@"bindings":@{@"bottomLeft":@[]}},@"bottomLeft").count==0,@"invalid binding row rejected");
  NSMutableSet *seen=[NSMutableSet set];
  for (NSDictionary *entry in haoge_touchflow_actionCatalog()) {
   NSString *identifier=entry[@"identifier"];
   NSCAssert(identifier.length && ![seen containsObject:identifier],@"unique action id");[seen addObject:identifier];
   NSCAssert([haoge_touchflow_actionTitle(identifier) isEqual:entry[@"title"]],@"UI title matches runtime catalog");
   NSCAssert(haoge_touchflow_actionNeedsValue(identifier)==[entry[@"needsValue"] boolValue],@"parameter contract matches");
  }
  NSCAssert(seen.count==19,@"18 actions plus none");
  NSArray *added=@[@"respring",@"screenRecording",@"kayokoClipboard",@"wechatPay",@"alipayPay",@"wechatScan",@"alipayScan"];
  NSMutableArray *panelRows=[NSMutableArray array];
  for (NSString *identifier in added) {
   NSCAssert([seen containsObject:identifier] && !haoge_touchflow_actionNeedsValue(identifier),@"new actions are available without typed parameters");
   NSCAssert(haoge_touchflow_bindingEnabled(@{@"enabled":@YES,@"action":identifier}),@"new direct binding recognized");
   [panelRows addObject:@{@"action":identifier}];
  }
  NSArray *normalized=haoge_touchflow_panelItems(panelRows);
  NSCAssert(normalized.count==added.count,@"new panel rows survive validation");
  for (NSUInteger i=0;i<added.count;i++) NSCAssert([normalized[i][@"action"] isEqual:added[i]],@"new panel action ordering preserved");
  NSDictionary *links=@{@"wechatScan":@"weixin://scanqrcode",@"wechatPay":@"weixin://widget/pay",@"alipayScan":@"alipay://platformapi/startapp?saId=10000007",@"alipayPay":@"alipay://platformapi/startapp?appId=20000056"};
  for (NSString *identifier in links) {
   NSCAssert([haoge_touchflow_actionURL(identifier).absoluteString isEqual:links[identifier]],@"app URL matches the requested entry exactly");
   NSCAssert(!haoge_touchflow_actionNeedsValue(identifier),@"built-in app entries require no value");
  }
  NSCAssert(!haoge_touchflow_actionURL(@"openURL") && !haoge_touchflow_actionURL(@"unknown"),@"custom and unknown actions cannot acquire built-in URLs");
  NSCAssert(haoge_touchflow_actionNeedsValue(@"openApp") && haoge_touchflow_actionNeedsValue(@"runShortcut") && haoge_touchflow_actionNeedsValue(@"openURL"),@"required inputs");
  NSURLComponents *url=[NSURLComponents componentsWithString:@"shortcuts://run-shortcut"];
  NSString *name=@"音乐 & 灯光 #1";url.queryItems=@[[NSURLQueryItem queryItemWithName:@"name" value:name]];
  NSCAssert([NSURLComponents componentsWithURL:url.URL resolvingAgainstBaseURL:NO].queryItems.count==1,@"shortcut name cannot add query parameters");
  NSCAssert([[NSURLComponents componentsWithURL:url.URL resolvingAgainstBaseURL:NO].queryItems.firstObject.value isEqual:name],@"shortcut unicode round trip");
  puts("PASS Foundation binding validation, unique catalogs, and encoded shortcut queries");
 }
 return 0;
}
