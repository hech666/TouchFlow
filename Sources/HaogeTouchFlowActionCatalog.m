#import "HaogeTouchFlowActions.h"
NSArray<NSDictionary *> *haoge_touchflow_actionCatalog(void) {
    static NSArray *catalog; static dispatch_once_t once;
    dispatch_once(&once, ^{
        catalog = @[
            @{@"identifier":@"none",@"title":@"不执行动作",@"detail":@"保留系统手势",@"needsValue":@NO},
            @{@"identifier":@"controlCenter",@"title":@"打开控制中心",@"detail":@"系统控制中心",@"needsValue":@NO},
            @{@"identifier":@"lock",@"title":@"锁定屏幕",@"detail":@"模拟锁屏按键",@"needsValue":@NO},
            @{@"identifier":@"appSwitcher",@"title":@"打开多任务",@"detail":@"显示应用切换器",@"needsValue":@NO},
            @{@"identifier":@"screenshot",@"title":@"系统截图",@"detail":@"使用系统截图入口",@"needsValue":@NO},
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
    return @"不执行动作";
}
BOOL haoge_touchflow_actionNeedsValue(NSString *identifier) {
    for (NSDictionary *item in haoge_touchflow_actionCatalog()) if ([item[@"identifier"] isEqual:identifier]) return [item[@"needsValue"] boolValue];
    return NO;
}
