# 接口参考与代码来源

输入参考包：OneStepX 1.1-0，SHA-256 `3324f056835522093268d3f5b0ddf383b28d8881c69af78bf2087b5e83daf9c7`。证据位于此前交付的 `OneStepX_SourceRecovery_v1`。

| TouchFlow 部分 | 原二进制地址／证据 | 使用方式 |
|---|---|---|
| 系统手势窗口 | `0x9438`、`0x94ac` | 在 SBSystemGestureManager 窗口创建／注册后附加识别器 |
| 桌面附加 | `0x9520`、`0x9560` | SBRootFolderView 生命周期 |
| 桌面排除触摸 | `0x66e8` | 图标、控件及 Widget/Dock/Search 等祖先排除策略 |
| 锁屏底部 | `0x9b00` | bottom cover-sheet edge pan 的 shouldReceiveTouch 仲裁 |
| 解锁底部 | `0x9f24`、`0xa254`、`0xa43c`、`0xa548` | 四阶段回调；x2/x3 对象、d0/d1 double 的 ABI；新实现动态校验 |
| 控制中心 | `0x12cec` | SBControlCenterController sharedInstance / presentAnimated:completion: |
| 锁屏、多任务 | `0x12d98`、`0x12dd4`，常量 `0x295a0`/`0x295d0` | _simulateLockButtonPress、SBUIController、handleHomeButtonDoublePressDown / handleMenuDoubleTap |
| 启动应用、URL | `0x12a78`、`0x12b14` | selector 检查及私有／公开 URL 回退 |
| 截图 | `0x14904` | UIApplication takeScreenshot / _takeScreenshotAndEdit: |
| 手电筒 | `0x13d74`、`0x13c30` | SBUIFlashlightController 和 AVCaptureDevice 回退 |
| 媒体控制 | `0x132b8`、`0x13300`、`0x13bc4` | MediaRemote 命令 2／4／5 |

TouchFlow 没有原插件完整性校验、原包身份判断、原自定义类、原机器码裁剪或原二进制加载依赖。这里是依据接口行为编写的独立首版，并非宣称还原作者原源码或完整复刻所有原功能。Apple 私有接口在不同设备／系统上需实测。


## v2 快捷面板数据与实现（2026-11-18）

`bindings[trigger]` 在既有 `enabled/action/value` 之外新增：

```plist
{
  enabled = true;
  mode = panel;                     // 缺省或 direct：继续用原 action/value
  action = screenshot;              // 直接模式数据保留，切模式不删除
  value = "";
  panelItems = ({
    id = "UUID";
    action = controlCenter;
    value = "";
    title = "";                     // 可选自定义名称
    symbol = "";                    // 可选 SF Symbol 名
  });
}
```

面板项有白名单、30 项上限、重复 ID 自动改名、字符串长度限制及需要参数动作验证；项次序就是显示次序。手势频繁读取的 `panelItems` 在配置重载时归一化为只读内存快照，并派生 `_haoge_touchflow_panelReady`，不回写旧配置文件。旧 binding 没有 `mode` 时按原来的 direct action 执行；empty/corrupt panel list 不会抢手势。

v2 面板使用匹配触发手势的活动 `UIWindowScene` 创建普通 `UIWindow`，不调用 `makeKeyWindow`，底部毛玻璃圆角面板、可滚动网格、点背景/关闭键/拖 grabber 可收起。单实例、dismissing gate、动画完成后执行一个已重新校验的动作；前后台、scene lifecycle、偏好变更、锁屏通知会取消面板。未在 Preferences 窗口中嵌入面板控制器，避免 `PSListController` 不支持的 `tableView` 接口。

新增全局外观值：高度、列数、图标大小、文字大小、行高、圆角、图标圆角百分比、背景 dim、开合时长、名称显隐和 system/light/dark appearance。首版用户值缺失时使用模型默认值，不覆盖用户原 binding。

注意：本节只记录源码数据契约和实现方案；构建、成品验包和设备面板交互均需分别验证，不能由原 OneStepX 伪源码或前一版安装成功推断。
