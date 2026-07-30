# HD2 Chat Overlay

《绝地潜兵 2》(HELLDIVERS 2) 中文输入悬浮窗插件 - 极速原生 AHK 控件 / 黑金美学重构版

## 功能特性

- **《绝地潜兵 2》黑金沉浸美学**: 深空暗黑背景 (`#0D0E12`) + 绝地黄发光边条 (`#FFC800`) + 纯白高亮文字 (`#FFFFFF`)，完美贴合游戏原生 UI。
- **Win32 Edit 控件独家无缝渲染**: 彻底拦截 `WM_CTLCOLOR` 消息，100% 消除刺眼 Win32 白框。
- **100% 准确零吞字注入**: 放弃不稳定剪贴板，采用 15ms 帧同步逐字 Unicode 分发，完美匹配游戏 60-144 FPS 输入消息队列，告别乱码与吞字。
- **完全遮盖原版聊天底栏**: `640px x 58px` 大容器与 `h44` 高度输入框，文字上下左右 100% 完整舒展展示，无任何笔画遮挡。
- **AI 游戏实时翻译 (OpenRouter / OpenAI 格式)**:
  - 接入 OpenRouter API 格式，支持自定义 API Base 与 Key。
  - **一键在线在线拉取模型列表**: 在配置界面点击 "🔄 拉取模型列表" 自动在线读取中转平台可用模型。
  - **智能游戏口语翻译**: 针对《绝地潜兵 2》游戏俚语优化 System Prompt，支持中英等多语言极速翻译。
  - **按键精准触发**: `Ctrl+Enter` 随时强制触发翻译发送，或勾选“开启 Enter 自动翻译”。
- **配置面板实时在屏预览 (Live Preview)**:
  - 打开配置菜单时，悬浮窗在屏幕上同步亮起呈现在原位置。
  - 随意微调 `OffsetX` / `OffsetY` / `Width` / `Height` / `FontSize` 或点击方向按钮，悬浮窗 0 延迟实时在屏滑动与放缩。
- **快捷键实时位置微调**: 在悬浮窗唤起激活时，直接按 `Ctrl+Alt+方向键` / `Shift+方向键` / `Alt+方向键`，即可以 5 像素为单位微调位置并自动保存。
- **系统托盘与自动置顶**: 托盘菜单一键唤起配置，智能多显示器 DPI 感知。

## 系统要求

- Windows 10 1803+ / Windows 11
- [AutoHotkey v2.0+](https://www.autohotkey.com/)
- 无额外依赖

## 快捷键

| 按键 | 功能 |
|------|------|
| Enter / 小键盘 Enter | 唤醒悬浮窗 / 发送文本到游戏 (若开启自动翻译则自动翻译) |
| Ctrl + Enter | 强制触发 AI 翻译并发送译文到游戏 |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl + Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Shift + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| 鼠标滚轮 / PgUp / PgDn | 悬浮窗激活时转发滚动消息至游戏聊天记录 |
| F12 | 重载脚本（仅游戏内生效） |
| F9 | 诊断热键：强制显示悬浮窗（用于测试） |

## 配置说明

配置文件: `hd2_chat_settings.ini` (运行时自动生成)

```ini
[Coordinates]
OffsetX=840    ; 悬浮窗水平偏移(基于游戏窗口右下角)
OffsetY=638    ; 悬浮窗垂直偏移

[Injection]
ChunkSize=1    ; 逐字发送
ChunkDelay=15  ; 逐字帧同步延迟(毫秒)

[Debug]
EnableDebugLog=1  ; 1=启用调试日志, 0=禁用

[UI]
FontName=SimHei
FontSize=16
OverlayWidth=640   ; 悬浮窗宽度
OverlayHeight=58   ; 悬浮窗高度

[Mode]
GlobalTestMode=1  ; 1=全局测试模式(任意窗口可唤醒), 0=仅游戏内

[Translation]
EnableAutoTranslate=0                    ; 1=Enter 自动翻译, 0=手动 Ctrl+Enter
ApiBase=https://openrouter.ai/api/v1    ; OpenRouter / OpenAI 兼容接口地址
ApiKey=sk-or-v1-xxxx                    ; 您的 API Key
Model=google/gemini-2.5-flash           ; 默认推荐模型 (或 deepseek/deepseek-chat)
TargetLanguage=English                   ; 目标翻译语言
```

## 运行方式

1. 确保已安装 AutoHotkey v2.0+
2. 双击运行 `hd2_chat.ahk`
3. 启动《绝地潜兵 2》，在游戏内按 Enter 唤醒黑金悬浮框输入中文
4. 按 Enter 发送文本，或按 Ctrl+Enter 自动 AI 翻译后发送

## 项目结构

```
hd2_chat.ahk               ; 主入口
lib/
  Config.ahk               ; 配置管理与 INI 持久化
  Translation.ahk          ; OpenRouter / OpenAI AI 翻译与在线模型拉取
  Gui.ahk                  ; 原生悬浮窗门面
  Gui.Native.ahk           ; 原生黑金悬浮窗实现
  ConfigGui.Native.ahk     ; 原生配置窗口与 Live Preview / AI 设置
  Injection.ahk            ; 帧同步文本注入与按键模拟
  Tray.ahk                 ; 系统托盘菜单
  Utils.ahk                ; 日志、IME、Win32、DPI 辅助
CHANGELOG.md               ; 更新日志
```

## 许可证

MIT License
