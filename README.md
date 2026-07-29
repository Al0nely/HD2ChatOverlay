# HD2 Chat Overlay

《绝地潜兵 2》(HELLDIVERS 2) 中文输入悬浮窗插件 - AutoHotkey v2 版本

## 功能特性

- **游戏内中文输入**: 按 Enter 唤醒悬浮窗，输入中文后按 Enter 发送
- **智能 IME 管理**: 自动切换中文输入法，禁用游戏原生 IME 冲突
- **CapsLock 兼容**: Zero-CapsLock Toggle 架构，游戏内 CapsLock On 时拼音输入正常
- **多显示器支持**: 自动检测游戏窗口所在显示器，防止悬浮窗飞出屏幕
- **位置记忆**: Ctrl+Alt+方向键微调位置，自动保存到配置文件
- **滚轮转发**: 悬浮窗上滚动滚轮/PgUp/PgDn 可翻看游戏聊天记录
- **系统托盘**: 右键托盘图标访问配置、测试模式、关于、退出
- **单实例运行**: Mutex 锁防止多开

## 快捷键

| 按键 | 功能 |
|------|------|
| Enter | 唤醒输入框 / 发送文本 |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl+Alt+方向键 | 微调悬浮窗位置(每次10像素) |
| 滚轮 / PgUp / PgDn | 滚动游戏聊天记录 |
| F12 | 重载脚本(游戏内) |

## 配置说明

配置文件: `hd2_chat_settings.ini`(运行时自动生成)

```ini
[Coordinates]
OffsetX=840    ; 悬浮窗水平偏移(基于游戏窗口右下角)
OffsetY=638    ; 悬浮窗垂直偏移

[Injection]
ChunkSize=8    ; 文本分片大小(字符数)
ChunkDelay=5   ; 分片间延迟(毫秒)

[Debug]
EnableDebugLog=0  ; 1=启用调试日志, 0=禁用

[UI]
FontName=SimHei   ; 悬浮窗字体
FontSize=18       ; 字体大小

[Mode]
GlobalTestMode=0  ; 1=全局测试模式(任意窗口可唤醒), 0=仅游戏内
```

## 运行方式

1. 确保已安装 [AutoHotkey v2.0+](https://www.autohotkey.com/)
2. 双击运行 `hd2_chat.ahk`
3. 系统托盘出现图标，启动《绝地潜兵 2》
4. 游戏内按 Enter 唤醒输入框

## 测试模式

无游戏时测试功能：

1. 右键托盘图标 -> 开启 "全局测试模式"
2. 运行 `test/TestWithNotepad.ahk` 启动记事本模拟
3. 在记事本窗口按 Enter 测试悬浮窗

## 日志

调试日志: `hd2_chat_debug.log`

- 默认关闭，配置窗口中勾选 "启用调试日志" 开启
- 日志缓冲批量写入，每 500ms 或满 10 条 flush
- 脚本退出时强制 flush 剩余日志

## 项目结构

```
hd2_chat.ahk          ; 主入口(热键、ShellHook、初始化)
lib/
  Config.ahk          ; 配置管理与 INI 持久化
  Gui.ahk             ; 悬浮窗与配置窗口
  Injection.ahk       ; 文本注入与按键模拟
  Tray.ahk            ; 系统托盘菜单
  Utils.ahk           ; 日志、IME、Win32、单实例锁
test/
  TestWithNotepad.ahk ; 记事本模拟测试脚本
plans/
  ahk-refactor-plan.md ; 重构计划文档
```

## 版本历史

- **v1.0.0** (2026-07-29): 初始版本，从单文件脚本重构为多文件架构，添加托盘菜单、配置 GUI、性能优化

## 许可证

MIT License
