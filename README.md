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
| Enter / 小键盘 Enter | 唤醒悬浮窗 / 将**当前选中框**文本发送到游戏 |
| Ctrl + T | AI 翻译原文框文本，译文显示在上方译文框（原文保留） |
| Ctrl + Tab | 在原文框 / 译文框之间切换注入源（选中框边条高亮） |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl + Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Shift + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| 鼠标滚轮 / PgUp / PgDn | 悬浮窗激活时转发滚动消息至游戏聊天记录 |
| F12 | 重载脚本（仅游戏内生效） |
| F9 | 诊断热键：强制显示悬浮窗（用于测试） |

> 翻译与切换注入源快捷键可在配置面板或 INI `[Hotkeys]` 节自定义（AHK 语法：`^`=Ctrl `!`=Alt `+`=Shift）。

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
EnableAutoTranslate=0                    ; 1=开启翻译双悬浮框
ApiBase=https://openrouter.ai/api/v1    ; OpenRouter / OpenAI 兼容接口地址
ApiKey=sk-or-v1-xxxx                    ; 您的 API Key
Model=google/gemini-2.5-flash           ; 默认推荐模型 (低延迟低成本)
TargetLanguage=English                   ; 目标翻译语言
EnableGlossary=1                         ; 1=启用术语库 AC 自动机预扫描
GlossaryUrl=https://raw.githubusercontent.com/helldivers-2/json/main/glossary.json
GlossaryLocalPath=assets\glossary.core.json

[Hotkeys]
TranslateKey=^t                          ; 翻译快捷键
SwitchSourceKey=^Tab                     ; 切换注入源快捷键
```

## AI 翻译（双悬浮框）

1. 托盘菜单打开配置面板，勾选「开启翻译双悬浮框」，填入 API Base / Key，选择模型（默认 `google/gemini-2.5-flash`）。
2. 游戏内按 Enter 唤醒后，在下方原文框输入中文，按 `Ctrl+T` 翻译，上方淡蓝译文框显示英文（原文保留）。
3. 按 `Ctrl+Tab` 切换注入源（选中框边条高亮：原文框绝地黄 / 译文框淡蓝），按 Enter 注入选中框内容；译文框为空时自动回退注入原文。
4. 术语库：内置 44 条 HD2 核心黑话（虫族/机器人/撤离/战术配备等），AC 自动机预扫描当前句子并注入 Prompt 约束模型用词；配置面板「更新术语库」可从 CDN 热更新。
5. 离线词库再生成（使用 Conda 隔离环境，避免污染主环境）：
   ```bash
   conda create -n hd2chat python=3.11 -y
   conda activate hd2chat
   python tools/glossary_scraper.py --out assets/glossary.core.json
   ```

## 运行方式

1. 确保已安装 AutoHotkey v2.0+
2. 双击运行 `hd2_chat.ahk`
3. 启动《绝地潜兵 2》，在游戏内按 Enter 唤醒黑金悬浮框输入中文
4. 按 Enter 发送文本；开启翻译后按 Ctrl+T 翻译、Ctrl+Tab 选择注入原文或译文

## 项目结构

```
hd2_chat.ahk               ; 主入口
lib/
  Config.ahk               ; 配置管理与 INI 持久化
  Translation.ahk          ; OpenRouter / OpenAI AI 翻译与在线模型拉取
  Glossary.ahk             ; HD2 术语库 AC 自动机预扫描与 CDN 热更新
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
