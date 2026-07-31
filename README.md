# HD2 Chat Overlay

《绝地潜兵 2》(HELLDIVERS 2) 中文输入悬浮窗插件 - 原生 AHK 控件 / 黑金美学重构版

## 功能特性

- **《绝地潜兵 2》黑金沉浸美学**: 深空暗黑背景 (`#0D0E12`) + 绝地黄发光边条 (`#FFC800`) + 纯白高亮文字 (`#FFFFFF`)，贴合游戏原生 UI 风格。
- **Win32 Edit 控件暗色渲染**: 拦截 `WM_CTLCOLOR` 消息，消除传统 Win32 白框。
- **逐字 Unicode 防吞字注入**: 摒弃剪贴板，采用帧间隔（默认 15ms）逐字 Unicode 分发，匹配游戏输入消息队列，有效降低乱码与吞字概率。
- **适配游戏聊天框尺寸**: 默认 `640px x 58px` 容器与居中对齐排版算法，确保中英文字符及 `_` 下划线完整展示。
- **AI 游戏实时翻译 (OpenRouter / OpenAI 格式)**:
  - 接入 OpenRouter / OpenAI API 格式，支持自定义 API Base 与 Key。
  - **在线拉取模型列表**: 在配置界面点击 "🔄 拉取模型列表" 自动读取中转平台可用模型。
  - **智能游戏口语翻译**: 针对《绝地潜兵 2》游戏俚语优化 System Prompt，支持中英等多语言翻译。
  - **双悬浮框交互**: `Alt+T` 触发翻译（译文显示在上方淡蓝框，原文保留），`Ctrl+Tab` 自由切换注入源，`Enter` 发送选中框文本。
- **配置面板实时在屏预览 (Live Preview)**:
  - 打开配置菜单时，悬浮窗在屏幕上同步亮起呈现原位置预览。
  - 微调 `OffsetX` / `OffsetY` / `Width` / `Height` / `FontSize` 或点击方向按钮，悬浮窗实时在屏滑动与缩放。
- **快捷键实时位置微调**: 在悬浮窗唤起激活时，按 `Ctrl+Alt+方向键`，即可以 5 像素为单位微调位置并自动保存。
- **系统托盘与自动置顶**: 托盘菜单一键唤起配置，智能多显示器 DPI 感知。

## 系统要求

- Windows 10 1803+ / Windows 11
- **运行 `.exe` 发布版**：无额外依赖，免安装 AutoHotkey / Python，解压双击即用
- **运行 `.ahk` 源码版**：需要安装 [AutoHotkey v2.0+](https://www.autohotkey.com/)


## 快捷键

| 按键 | 功能 |
|------|------|
| Enter / 小键盘 Enter | 唤醒悬浮窗 / 将**当前选中框**文本发送到游戏 |
| Alt + T | AI 翻译原文框文本，译文显示在上方译文框（原文保留，热键可自定义） |
| Ctrl + Tab | 在原文框 / 译文框之间切换注入源（选中框边条高亮，热键可自定义） |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl + Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| 鼠标滚轮 / PgUp / PgDn | 悬浮窗激活时转发滚动消息至游戏聊天记录 |
| F12 | 重载脚本（仅游戏内生效） |

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
GlobalTestMode=0  ; 1=全局测试模式(任意窗口可唤醒), 0=仅游戏内

[Translation]
EnableAutoTranslate=0                    ; 1=开启翻译双悬浮框
ApiBase=https://openrouter.ai/api/v1    ; OpenRouter / OpenAI 兼容接口地址
ApiKey=                                 ; 默认为空，需填入您的 API Key
Model=                                  ; 默认为空，可在线拉取或填写模型名称
SourceLanguage=Auto                     ; 源语言
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

1. 托盘菜单打开配置面板，勾选「开启翻译双悬浮框」，填入您的 API Key 与模型名称（默认为空，也可点击 "🔄 拉取模型列表" 自动选择），按需调整 API Base。
2. 游戏内按 Enter 唤醒后，在下方原文框输入中文，按 `Alt+T` 翻译，上方淡蓝译文框显示英文（原文保留）。
3. 按 `Ctrl+Tab` 切换注入源（选中框边条高亮：原文框绝地黄 / 译文框淡蓝），按 Enter 注入选中框内容；译文框为空时自动回退注入原文。
4. **HD2 游戏黑话词库 (137 词条 + 6 细分类)**：
   - 包含绝地潜兵 2 全套飞鹰/轨道/重武器背包/炮台/机甲/虫族/机器人/武器投掷物与战场黑话。
   - 支持高频中英文缩写混合捕获：`BT`, `AC`, `RR`, `QC`, `FS`, `re`, `mb`, `rdy`, `500`, `下头500`, `大红线`, `泡泡盾`, `牛`, `隐形虫`, `粉桶`, `鸡腿石` 等。
   - 细分为 `enemy` (敌人)、`stratagem` (战术配备)、`weapon` (武器)、`resource` (资源)、`action` (战术动作)、`slang` (口癖黑话) 6 大类别。
5. **CDN 热更新与失败诊断**：配置面板「🔄 更新术语库」从 GitHub 官方 Raw 仓库拉取最新词库；若远端网络不可达，界面弹窗将提示具体失败的目标 URL 及错误原因，并可勾选允许调用本地 Conda 环境自动刷新。
6. **Conda 隔离环境配置（防止污染主 Python 环境）**：
   - 使用项目根目录的 `environment.yml` 或手动创建 `hd2chat` 环境：
   ```bash
   conda create -n hd2chat python=3.11 -y
   conda activate hd2chat
   python tools/glossary_scraper.py --out assets/glossary.core.json
   ```

## 运行方式

1. **单文件直接运行**：从 GitHub Release 下载 `HD2ChatOverlay.exe` 双击即可使用（若在独占全屏游戏内按 Enter 无响应，右键 `.exe` ➔ 属性 ➔ 兼容性 ➔ 勾选「以管理员身份运行」）。
2. **源码运行**：确保安装 AutoHotkey v2.0+，双击运行 `hd2_chat.ahk`。
3. 启动《绝地潜兵 2》，在游戏内按 Enter 唤醒黑金悬浮框输入中文。
4. 按 Enter 发送文本；开启翻译后按 Alt+T 翻译、Ctrl+Tab 选择注入原文或译文。

## 常见问题与环境兼容性 FAQ

1. **游戏画面显示模式（无边框全屏）**：
   - **强烈推荐**：在《绝地潜兵 2》游戏图像设置中将显示模式设置为**【无边框全屏】**或**【窗口化】**。
   - **注意**：若强制设置为“独占全屏”（Exclusive Fullscreen），DirectX/Vulkan 独占渲染管道会绕过 Windows 桌面合成器，可能导致悬浮窗无法置顶显示或唤醒时引发窗口切出（Alt-Tab）。

2. **多分辨率与位置微调 (1080P / 2K / 4K)**：
   - 完美兼容 1080P、2K、4K 及超宽屏。悬浮窗基于屏幕/游戏窗口右下角计算相对坐标，并带有屏幕边界自动限制防溢出保护。
   - 首次启动若位置与游戏原生聊天框有微小偏差，可在唤醒悬浮窗时按 `Ctrl + Alt + 方向键`（每次 5 像素）实时微调，微调结果会自动持久化保存。

3. **游戏帧率 (FPS) 与打字稳定性**：
   - 悬浮窗为原生 Win32 DWM 窗口，打字与响应始终维持系统级流畅，不受游戏帧率波动影响。
   - 逐字 Unicode 注入默认设置了 15ms 帧间延迟（`ChunkDelay=15`）。若遇到极限低帧率（<20 FPS）游戏卡顿导致掉字，可在 `hd2_chat_settings.ini` 中将 `ChunkDelay` 调整为 `20`~`30` 毫秒。

4. **黑话术语库与 Python 依赖**：
   - 普通玩家**完全不需要安装 Python 或 Conda**。黑话词库基于纯 AHK 原生 AC 自动机算法构建，并通过 HTTP 协议在线热更新 JSON 资源。
   - Python（`tools/glossary_scraper.py`）仅为开发者或高级用户的本地爬虫工具。


## 项目结构

```
hd2_chat.ahk               ; 主入口
assets/
  glossary.core.json       ; 内置 HD2 游戏黑话核心词库 (137 词条)
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
tools/
  glossary_scraper.py      ; HD2 词库数据采集与生成脚本
  build_release.py         ; 单文件可执行程序打包构建工具
  publish_github_release.py; GitHub Release 自动发布脚本
environment.yml            ; Conda 隔离环境 (hd2chat) 配置文件
CHANGELOG.md               ; 更新日志
README.md                  ; 项目说明文档
```

## 许可证

MIT License

