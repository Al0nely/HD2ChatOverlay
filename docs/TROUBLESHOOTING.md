# 故障排查指南

## 1. WebView2 相关

### 1.1 WebView2 Runtime 未安装

**症状**: 启动时日志显示 `[WebView2Runtime] 未检测到 WebView2 Runtime`

**解决方案**:
1. 脚本会自动尝试下载并静默安装 WebView2 Runtime
2. 若自动安装失败，手动下载安装:
   - 访问 [WebView2 Runtime 下载页](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)
   - 下载 "Evergreen Bootstrapper" 并运行
3. 安装完成后重启脚本

### 1.2 WebView2 启动失败，自动降级到原生模式

**症状**: 托盘提示显示 "原生控件"，日志显示 `WebView2 连续初始化失败`

**解决方案**:
1. 检查 Edge 浏览器是否可正常启动
2. 检查系统安全软件是否拦截了 PowerShell 或 Edge
3. 尝试手动运行 `hd2_chat_native.ahk` 使用原生模式
4. 查看日志中 `[BridgeServer]` 和 `[WebView2HostInstance]` 的详细错误

### 1.3 Edge App 窗口无法找到

**症状**: 日志显示 `等待窗口超时`

**解决方案**:
1. 检查 `lib/WebView2Bridge.ps1` 是否存在
2. 检查 PowerShell 执行策略: 以管理员运行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. 检查防火墙是否阻止了本地 HTTP 连接 (127.0.0.1)
4. 尝试手动运行桥接服务器: `powershell -File lib/WebView2Bridge.ps1 -Port 9280`

## 2. 悬浮窗问题

### 2.1 悬浮窗位置偏移

**症状**: 悬浮窗不在游戏窗口右下角预期位置

**解决方案**:
1. 使用 `Ctrl+Alt+方向键` 实时调整位置
2. 打开配置窗口，修改 OffsetX/OffsetY
3. 检查多显示器 DPI 缩放设置是否一致
4. 确认游戏窗口未被最小化或处于全屏独占模式

### 2.2 悬浮窗无法唤醒

**症状**: 游戏内按 Enter 无反应

**解决方案**:
1. 确认脚本已在后台运行 (系统托盘有图标)
2. 确认未开启 "全局测试模式" 时，只在游戏窗口内按 Enter
3. 检查游戏是否以管理员身份运行，而脚本未以管理员运行 (权限不匹配)
4. 尝试以管理员身份运行脚本

### 2.3 拼音输入仍然卡顿

**症状**: WebView2 模式下拼音输入仍不流畅

**解决方案**:
1. 确认当前确实处于 WebView2 模式 (托盘提示应显示 "WebView2")
2. 检查 Edge 浏览器版本是否过旧，尝试更新 Edge
3. 关闭其他占用 GPU/CPU 的程序
4. 尝试在配置界面降低字体大小

## 3. 配置界面问题

### 3.1 配置窗口无法打开

**症状**: 点击托盘 "打开配置窗口" 无反应

**解决方案**:
1. 检查是否已有一个配置窗口实例在运行 (任务栏搜索 "HD2 Chat Overlay - 配置")
2. 尝试切换到原生模式后打开配置窗口
3. 查看日志中是否有 `[WebView2HostInstance] 启动失败` 记录

### 3.2 配置保存后不生效

**症状**: 修改配置并保存后，悬浮窗未应用新设置

**解决方案**:
1. 确认点击的是 "保存" 而非 "取消"
2. 检查 `hd2_chat_settings.ini` 文件是否被正确修改
3. 尝试重启脚本
4. 若修改的是渲染引擎，需要重启脚本才能生效

## 4. 文本注入问题

### 4.1 文本未注入到游戏

**症状**: 悬浮窗提交后，游戏聊天框无文本

**解决方案**:
1. 确认游戏窗口处于活跃状态
2. 检查游戏内聊天框是否已打开 (某些游戏需要先按 T 或 Y 打开聊天)
3. 尝试增加配置中的 "分片延迟" (ChunkDelay)
4. 查看日志中 `[Injection]` 的详细记录

### 4.2 注入文本乱码

**症状**: 游戏内显示乱码或问号

**解决方案**:
1. 确认游戏支持中文输入
2. 尝试更换悬浮窗字体为 "SimHei" 或 "Microsoft YaHei UI"
3. 检查系统区域设置是否为中文 (中国)

## 5. 性能问题

### 5.1 内存占用过高

**症状**: 任务管理器显示脚本占用内存超过 300MB

**解决方案**:
1. WebView2 模式下内存占用 150-250MB 属于正常范围 (Chromium 内核)
2. 若超过 300MB，尝试关闭配置窗口
3. 切换到原生控件模式可显著降低内存占用

### 5.2 CPU 占用过高

**症状**: 脚本持续占用 CPU 超过 10%

**解决方案**:
1. 检查是否开启了调试日志 (大量日志写入会占用 CPU)
2. 尝试重启脚本
3. 检查是否有其他程序与脚本冲突

## 6. 回滚与恢复

### 6.1 配置损坏无法启动

**症状**: 脚本启动崩溃或行为异常

**解决方案**:
1. 删除 `hd2_chat_settings.ini`，脚本将使用默认配置重启
2. 或重命名 `hd2_chat_settings.ini.bak` 为 `hd2_chat_settings.ini` 恢复备份
3. 使用 `hd2_chat_native.ahk` 以原生模式启动

### 6.2 需要完全重置

**解决方案**:
1. 退出脚本 (托盘图标 -> 退出)
2. 删除以下文件:
   - `hd2_chat_settings.ini`
   - `hd2_chat_settings.ini.bak*`
   - `hd2_chat_debug.log`
   - `%TEMP%\HD2ChatOverlay_*`
3. 重新启动脚本

## 7. 日志分析

开启调试日志后，可通过以下关键字过滤日志:

| 关键字 | 说明 |
|--------|------|
| `[Main]` | 主入口启动/关闭 |
| `[Config]` | 配置加载/保存/备份/回滚 |
| `[WebView2Runtime]` | WebView2 Runtime 检测/安装 |
| `[BridgeServer]` | HTTP 桥接服务器状态 |
| `[WebView2Host]` | WebView2 初始化状态 |
| `[WebView2HostInstance]` | Edge App 窗口状态 |
| `[Gui]` | 悬浮窗显示/隐藏/重建 |
| `[Injection]` | 文本注入详情 |
| `[GameHwndCache]` | 游戏窗口句柄缓存 |
| `[DPI]` | DPI 感知设置 |
| `[CapsLockManager]` | CapsLock 状态变更 |

---

若以上方案均无法解决问题，请:
1. 开启调试日志
2. 复现问题
3. 将 `hd2_chat_debug.log` 和 `hd2_chat_settings.ini` 打包提交 Issue
