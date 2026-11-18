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
