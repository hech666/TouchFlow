#import "HaogeTouchFlowActions.h"
NSArray<NSDictionary *> *haoge_touchflow_actionCatalog(void) {
    static NSArray *catalog; static dispatch_once_t once;
    dispatch_once(&once, ^{
        catalog = @[
            @{@"identifier":@"controlCenter",@"title":@"打开控制中心",@"detail":@"系统控制中心",@"needsValue":@NO},
            @{@"identifier":@"lock",@"title":@"锁定屏幕",@"detail":@"模拟锁屏按键",@"needsValue":@NO},
            @{@"identifier":@"appSwitcher",@"title":@"打开多任务",@"detail":@"显示应用切换器",@"needsValue":@NO},
            @{@"identifier":@"respring",@"title":@"注销 SpringBoard",@"detail":@"重新载入桌面，不重启手机",@"needsValue":@NO},
            @{@"identifier":@"screenshot",@"title":@"系统截图",@"detail":@"使用系统截图入口",@"needsValue":@NO},
            @{@"identifier":@"screenRecording",@"title":@"开始／停止录屏",@"detail":@"再次执行停止系统录屏并保存到照片",@"needsValue":@NO},
            @{@"identifier":@"kayokoClipboard",@"title":@"kayoko剪切板",@"detail":@"需要安装并启用 Kayoko",@"needsValue":@NO},
            @{@"identifier":@"wechatPay",@"title":@"微信付款码",@"detail":@"打开微信付款码页面",@"needsValue":@NO,@"url":@"weixin://widget/pay"},
            @{@"identifier":@"alipayPay",@"title":@"支付宝付款码",@"detail":@"打开支付宝付款码页面",@"needsValue":@NO,@"url":@"alipay://platformapi/startapp?appId=20000056"},
            @{@"identifier":@"wechatScan",@"title":@"微信扫一扫",@"detail":@"打开微信扫码页面",@"needsValue":@NO,@"url":@"weixin://scanqrcode"},
            @{@"identifier":@"alipayScan",@"title":@"支付宝扫一扫",@"detail":@"打开支付宝扫码页面",@"needsValue":@NO,@"url":@"alipay://platformapi/startapp?saId=10000007"},
            @{@"identifier":@"flashlight",@"title":@"切换手电筒",@"detail":@"开关手电筒",@"needsValue":@NO},
            @{@"identifier":@"playPause",@"title":@"播放／暂停",@"detail":@"控制当前媒体播放",@"needsValue":@NO},
            @{@"identifier":@"nextTrack",@"title":@"下一曲",@"detail":@"切换下一首媒体",@"needsValue":@NO},
            @{@"identifier":@"previousTrack",@"title":@"上一曲",@"detail":@"切换上一首媒体",@"needsValue":@NO},
            @{@"identifier":@"openApp",@"title":@"打开应用",@"detail":@"填写应用的 Bundle ID",@"needsValue":@YES,@"valueHint":@"例如 com.tencent.xin"},
            @{@"identifier":@"runShortcut",@"title":@"运行快捷指令",@"detail":@"填写快捷指令的完整名称",@"needsValue":@YES,@"valueHint":@"快捷指令名称"},
            @{@"identifier":@"openURL",@"title":@"打开链接／URL Scheme",@"detail":@"填写完整 URL",@"needsValue":@YES,@"valueHint":@"例如 https://example.com 或 prefs:root=General"}
        ];
    }); return catalog;
}
NSString *haoge_touchflow_actionTitle(NSString *identifier) {
    for (NSDictionary *item in haoge_touchflow_actionCatalog()) if ([item[@"identifier"] isEqual:identifier]) return item[@"title"];
    return @"未知动作";
}
BOOL haoge_touchflow_actionNeedsValue(NSString *identifier) {
    for (NSDictionary *item in haoge_touchflow_actionCatalog()) if ([item[@"identifier"] isEqual:identifier]) return [item[@"needsValue"] boolValue];
    return NO;
}

NSURL *haoge_touchflow_actionURL(NSString *identifier) {
    // The catalog keeps the user-provided URL and its query key unchanged.
    for (NSDictionary *entry in haoge_touchflow_actionCatalog()) {
        if (![entry[@"identifier"] isEqual:identifier]) continue;
        NSString *url=[entry[@"url"] isKindOfClass:NSString.class]?entry[@"url"]:nil;
        return url.length?[NSURL URLWithString:url]:nil;
    }
    return nil;
}
