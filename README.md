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
| Alt + T | AI 翻译原文框文本，译文显示在上方译文框（原文保留） |
| Ctrl + Tab | 在原文框 / 译文框之间切换注入源（选中框边条高亮） |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl + Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Shift + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| 鼠标滚轮 / PgUp / PgDn | 悬浮窗激活时转发滚动消息至游戏聊天记录 |
| F12 | 重载脚本（仅游戏内生效） |
| F9 | 诊断热键：强制显示悬浮窗（用于测试） |

> 快捷键支持交互式设置：在配置面板中**点击快捷键按钮** ➔ 键盘直接按下任意组合键 ➔ 按 **Enter** 确认完成修改。

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
EnablePythonScraper=1                    ; 1=允许远端更新失败时自动调用本地 Python (Conda) 刷新/采集
GlossaryUrl=https://raw.githubusercontent.com/Al0nely/HD2ChatOverlay/main/assets/glossary.core.json
GlossaryLocalPath=assets\glossary.core.json

[Hotkeys]
TranslateKey=!t                          ; 翻译快捷键 (默认 Alt+T)
SwitchSourceKey=^Tab                     ; 切换注入源快捷键 (默认 Ctrl+Tab)
```

## AI 翻译与术语库

1. 托盘菜单打开配置面板，勾选「开启翻译双悬浮框」，填入 API Base / Key，选择模型（默认 `google/gemini-2.5-flash`）。
2. 游戏内按 Enter 唤醒后，在下方原文框输入中文，按 `Alt+T` 翻译，上方淡蓝译文框显示英文（原文保留）。
3. 按 `Ctrl+Tab` 切换注入源（选中框边条高亮：原文框绝地黄 / 译文框淡蓝），按 Enter 注入选中框内容；译文框为空时自动回退注入原文。
4. **HD2 游戏黑话词库 (137 词条 + 6 细分类)**：
   - 包含绝地潜兵 2 全套飞鹰/轨道/重武器背包/炮台/机甲/虫族/机器人/武器投掷物与战场黑话。
   - 支持高频中英文缩写混合捕获：`BT`, `AC`, `RR`, `QC`, `FS`, `re`, `mb`, `rdy`, `500`, `下头500`, `大红线`, `泡泡盾`, `牛`, `隐形虫`, `粉桶`, `鸡腿石` 等。
   - 细分为 `enemy` (敌人)、`stratagem` (战术配备)、`weapon` (武器)、`resource` (资源)、`action` (战术动作)、`slang` (口癖黑话) 6 大类别。
5. **CDN 热更新与失败诊断**：配置面板「🔄 更新术语库」从 GitHub 官方 Raw 仓库拉取最新词库；若远端网络不可达，界面弹窗将**明确指示具体失败的目标 URL 及错误原因**，并可勾选允许调用本地 Conda 环境自动刷新。
6. **Conda 隔离环境配置（防止污染主 Python 环境）**：
   - 使用项目根目录的 `environment.yml` 或手动创建 `hd2chat` 环境：
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
