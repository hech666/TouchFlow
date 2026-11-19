#import "HaogeTouchFlowPanelModel.h"
#import <math.h>
BOOL haoge_touchflow_hasPanelMode(NSDictionary *binding) {
    return [binding[@"mode"] isKindOfClass:[NSString class]] && [binding[@"mode"] isEqual:@"panel"];
}
NSArray<NSDictionary *> *haoge_touchflow_panelItems(id input) {
    if (![input isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *out=[NSMutableArray array]; NSMutableSet *ids=[NSMutableSet set],*actions=[NSMutableSet set];
    NSSet *keys=[NSSet setWithArray:@[@"id",@"action",@"value",@"title",@"symbol"]];
    for (id row in input) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSString *action=[row[@"action"] isKindOfClass:[NSString class]]?row[@"action"]:nil;
        BOOL supported=NO;
        for (NSDictionary *entry in haoge_touchflow_actionCatalog())
            if ([entry[@"identifier"] isEqual:action] && ![action isEqual:@"none"]) { supported=YES;break; }
        if (!supported || [actions containsObject:action]) continue;
        NSMutableDictionary *item=[NSMutableDictionary dictionary];
        for (NSString *key in keys) {
            id value=row[key];
            NSUInteger limit=[key isEqual:@"value"]?4096:([key isEqual:@"title"]?80:128);
            if ([value isKindOfClass:[NSString class]]) item[key]=[value substringToIndex:MIN([value length],limit)];
        }
        NSString *value=[item[@"value"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (haoge_touchflow_actionNeedsValue(action) && !value.length) continue;
        if ([action isEqual:@"openURL"] && ![NSURL URLWithString:value].scheme.length) continue;
        if (value) item[@"value"]=value;
        [actions addObject:action];
        NSString *identity=item[@"id"];
        if (!identity.length || [ids containsObject:identity]) identity=[NSString stringWithFormat:@"item-%lu",(unsigned long)out.count];
        while ([ids containsObject:identity]) identity=[identity stringByAppendingString:@"-"];
        item[@"id"]=identity;[ids addObject:identity];[out addObject:[item copy]];
        if (out.count==30) break;
    }
    return out;
}
NSString *haoge_touchflow_bindingSummary(NSDictionary *binding) {
    if (haoge_touchflow_hasPanelMode(binding)) return [NSString stringWithFormat:@"快捷面板 · %lu 项",(unsigned long)haoge_touchflow_panelItems(binding[@"panelItems"]).count];
    return haoge_touchflow_actionTitle([binding[@"action"] isKindOfClass:[NSString class]]?binding[@"action"]:@"none");
}
NSString *haoge_touchflow_panelItemTitle(NSDictionary *item) {
    NSString *title=[item[@"title"] isKindOfClass:[NSString class]]?item[@"title"]:nil;
    if (title.length) return title;
    if (haoge_touchflow_actionNeedsValue(item[@"action"])) {
        NSString *value=[item[@"value"] isKindOfClass:[NSString class]]?item[@"value"]:nil;
        if (value.length && [item[@"action"] isEqual:@"runShortcut"]) return value;
    }
    return haoge_touchflow_actionTitle(item[@"action"]);
}
NSString *haoge_touchflow_actionSymbol(NSString *action) {
    NSDictionary *symbols=@{@"controlCenter":@"switch.2",@"lock":@"lock.fill",@"appSwitcher":@"rectangle.stack.fill",@"respring":@"arrow.clockwise",@"screenshot":@"camera.viewfinder",@"screenRecording":@"record.circle",@"kayokoClipboard":@"doc.on.clipboard.fill",@"wechatPay":@"creditcard.fill",@"alipayPay":@"creditcard",@"wechatScan":@"qrcode.viewfinder",@"alipayScan":@"viewfinder",@"flashlight":@"flashlight.on.fill",@"playPause":@"playpause.fill",@"nextTrack":@"forward.end.fill",@"previousTrack":@"backward.end.fill",@"openApp":@"app.fill",@"runShortcut":@"square.stack.3d.up.fill",@"openURL":@"link"};
    return symbols[action]?:@"square.grid.2x2.fill";
}
NSArray<NSDictionary *> *haoge_touchflow_panelSettings(void) {
    return @[
        @{@"key":@"panelHeight",@"title":@"面板高度",@"default":@360,@"min":@180,@"max":@700,@"step":@1,@"unit":@"pt"},
        @{@"key":@"panelColumns",@"title":@"每行列数",@"default":@4,@"min":@3,@"max":@6,@"step":@1,@"unit":@"列"},
        @{@"key":@"panelIconSize",@"title":@"图标大小",@"default":@40,@"min":@24,@"max":@60,@"step":@1,@"unit":@"pt"},
        @{@"key":@"panelTextSize",@"title":@"名称字号",@"default":@11,@"min":@9,@"max":@18,@"step":@1,@"unit":@"pt"},
        @{@"key":@"panelRowHeight",@"title":@"每行高度",@"default":@88,@"min":@64,@"max":@130,@"step":@1,@"unit":@"pt"},
        @{@"key":@"panelCornerRadius",@"title":@"面板圆角",@"default":@30,@"min":@0,@"max":@48,@"step":@1,@"unit":@"pt"},
        @{@"key":@"panelDimAlpha",@"title":@"背景变暗程度",@"default":@0.18,@"min":@0,@"max":@0.6,@"step":@0.01,@"unit":@""},
        @{@"key":@"panelOpenDuration",@"title":@"展开动画时长",@"default":@0.28,@"min":@0.1,@"max":@0.8,@"step":@0.01,@"unit":@"秒"},
        @{@"key":@"panelCloseDuration",@"title":@"收起动画时长",@"default":@0.18,@"min":@0.1,@"max":@0.6,@"step":@0.01,@"unit":@"秒"}
    ];
}
double haoge_touchflow_panelNumber(NSDictionary *values,NSString *key) {
    for (NSDictionary *field in haoge_touchflow_panelSettings()) {
        if (![field[@"key"] isEqual:key]) continue;
        id number=values[key];double value=[number isKindOfClass:[NSNumber class]]?[number doubleValue]:[field[@"default"] doubleValue];
        if (!isfinite(value)) value=[field[@"default"] doubleValue];
        value=fmax([field[@"min"] doubleValue],fmin(value,[field[@"max"] doubleValue]));
        double step=[field[@"step"] doubleValue]; return round(value/step)*step;
    }
    return 0;
}
BOOL haoge_touchflow_panelFlag(NSDictionary *values,NSString *key,BOOL fallback) {
    return [values[key] isKindOfClass:[NSNumber class]]?[values[key] boolValue]:fallback;
}
