# 轻触手势 TouchFlow v1

面向 iOS 16／Roothide 的独立 Theos 手势插件，包名 `com.haoge.touchflow`。使用 OneStepX 逆向恢复的系统接口与汇编作为参考，手势管理、动作分发和中文设置界面以独立源码实现；构建不包含、不链接、不加载 OneStepX 二进制。

## 首版范围

13 个可独立启用、独立选择动作的入口：

- 状态栏左／右各单击、双击、长按、向左滑、向右滑（10 项）。
- 底部左／右上滑（2 项）。
- 桌面空白处长按（1 项）。

动作：控制中心、锁屏、多任务、截图、手电筒、播放暂停、上一曲、下一曲、打开应用、运行快捷指令、打开 URL，另有“不执行动作”。

应用使用 Bundle ID 输入，例如 `com.tencent.xin`；快捷指令输入完整名称；链接输入完整协议。首版不包含应用列表选择器、快捷面板、连续动作流、硬件按键扩展或横屏手势。

## 安装与使用

1. 安装 Roothide 版 deb。包与 `com.wkk.onestepx` 声明互斥，包管理器可能提示移除 OneStepX。
2. 安装完成后由包管理器重新载入 SpringBoard。
3. 打开系统设置 → 轻触手势，开启总开关；进入某项手势，启用并选择动作。
4. 需要参数的动作填写参数；以后改设置自动生效。

默认总开关关闭，锁屏动作关闭，轻振开启。左右区域各占 25%，中间 50% 留给系统；区域可调整到 10%～33%。底部默认距离 110pt，状态栏横滑 60pt，长按 0.55 秒。桌面触摸会排除图标、控件、Dock、小组件、搜索等视图。

## 工程

`Sources/HaogeTouchFlowHooks.m` 安装并检查实际系统类／方法；底部四个回调先一起检查 ABI，不能完整匹配时不会接管半套生命周期。自定义系统窗口识别器只负责状态栏和锁屏底部；解锁底部走系统手势回调，避免重复触发。

`Sources/HaogeTouchFlowGestures.m` 管理状态、手势和配置刷新；`HaogeTouchFlowActions.m` 执行经 selector 检查的系统动作；`HaogeTouchFlowActionCatalog.m` 是主插件和面板共用目录。

偏好面板是唯一配置写入方，使用同一 Roothide `jbroot()` 路径、原子写入和专属 Darwin 通知。主插件只读快照，不写默认设置。不创建覆盖全屏的触摸窗口。

只对 SpringBoard 注入，不向普通应用全局注入。源接口依据见 `REFERENCE.md`。

## 构建与验证

macOS／Xcode + `roothide/theos` + iPhoneOS16.5 SDK：

```sh
sh build.sh roothide
python3 Tools/verify_package.py packages/*.deb
```

编译主插件和设置面板的真实 arm64、arm64e 两个 slice，部署目标 16.0。CI 版本 `5.2.0-<run_number>`。

已覆盖 25 项几何边界／方向／NaN 检查；成品检查涵盖架构、依赖、部署目标、过滤器、资源和两套代码签名页。源码 manifest 记录实际构建提交和逐文件 SHA-256。

这些检查不能代替真机手势验收。未在目标 SpringBoard 上安装测试首版，UI、私有接口实际行为以及与其他手势插件的冲突仍待设备确认。原 OneStepX iOS16 测试包可用的反馈不等于本新插件已实测。
