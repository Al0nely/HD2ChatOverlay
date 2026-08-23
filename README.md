# HD2 Chat Overlay

《绝地潜兵 2》(HELLDIVERS 2) 中文输入与 AI 翻译悬浮窗插件

## 功能特性

- **游戏同款视觉风格**: 深空暗黑背景 (`#0D0E12`) + 绝地黄边条 (`#FFC800`) + 纯白文字 (`#FFFFFF`)，贴合游戏界面风格。
- **Win32 Edit 暗色渲染**: 拦截 `WM_CTLCOLOR` 消息，消除传统 Win32 白框。
- **逐字 Unicode 注入**: 摒弃剪贴板，采用帧间隔（默认 15ms）逐字 Unicode 分发，匹配游戏输入消息队列，降低乱码与吞字概率。
- **输入法与大小写锁定 (CapsLock) 自动管理**: 唤醒悬浮窗时自动开启中文输入法；发送文本或处于游戏操作状态时自动将 CapsLock 设为大写锁定 (`On`)，防止游戏内输入法弹出拼音候选框干扰操作。
- **适配游戏聊天框尺寸**: 默认 `640px x 58px` 容器与居中对齐算法，确保中英文字符及 `_` 下划线完整展示。
- **AI 游戏实时翻译 (OpenRouter / OpenAI 格式)**:
  - 接入 OpenRouter / OpenAI API 格式，支持自定义 API Base 与 Key。
  - **在线拉取模型列表**: 在配置界面点击 "🔄 拉取模型列表" 自动读取可用模型。
  - **游戏口语翻译**: 针对游戏语境优化 System Prompt，支持中英等多语言翻译。
  - **双悬浮框交互**: `Alt+T` 触发翻译（译文显示在上方淡蓝框，原文保留），`Ctrl+Tab` 自由切换注入源，`Enter` 发送选中框文本。
- **配置面板实时在屏预览 (Live Preview)**:
  - 打开配置菜单时，悬浮窗在屏幕上同步亮起呈现原位置预览。
  - 微调 `OffsetX` / `OffsetY` / `Width` / `Height` / `FontSize` 或点击方向按钮，悬浮窗实时在屏滑动与缩放。
- **快捷键实时位置微调**: 在悬浮窗唤起激活时，按 `Ctrl+Alt+方向键`，即可以 5 像素为单位微调位置并自动保存。
- **聊天历史滚轮转发**: 悬浮窗激活状态下，向上/向下滚动鼠标滚轮可自动转发滚动消息至游戏聊天窗口，便于翻看历史聊天记录。
- **系统托盘与自动置顶**: 托盘菜单一键唤起配置，智能多显示器 DPI 感知。
- **配置自动备份与一键回滚**: 每次保存配置自动生成 `.bak` 滚动备份，托盘菜单支持一键「回滚到上一版本配置」并自动重启恢复，防止误操作或热键冲突。

## 系统要求

- Windows 10 1803+ / Windows 11
- **运行 `.exe` 发布版**：无额外依赖，免安装 AutoHotkey / Python，解压即用。程序已自带 UAC 提权清单与 Authenticode 代码签名，双击启动即可自动请求提权以穿透游戏反作弊限制。
- **运行 `.ahk` 源码版**：需要安装 [AutoHotkey v2.0+](https://www.autohotkey.com/)（脚本内自带自动请求管理员权限提权逻辑）。



## 快捷键

| 按键 | 功能 |
|------|------|
| Enter / 小键盘 Enter | 唤醒悬浮窗 / 将**当前选中框**文本发送到游戏 |
| Alt + T | AI 翻译原文框文本，译文显示在上方译文框（原文保留，热键可自定义） |
| Ctrl + Tab | 在原文框 / 译文框之间切换注入源（选中框边条高亮，热键可自定义） |
| Esc | 取消输入并关闭悬浮窗 |
| Ctrl + Alt + 方向键 | 微调悬浮窗位置（每次 5 像素，自动保存） |
| 鼠标滚轮 (WheelUp / WheelDown) | 悬浮窗激活时向上/下滚动翻看游戏历史聊天记录 |
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

1. **单文件直接运行**：从 GitHub Release 下载 `HD2ChatOverlay.exe`，**右键选择「以管理员身份运行」**（受 Windows UIPI 权限隔离保护，以管理员身份运行才能向以提升权限运行的游戏发送按键与拦截 Enter 热键）。
2. **源码运行**：确保安装 AutoHotkey v2.0+，双击运行 `hd2_chat.ahk`。
3. 启动《绝地潜兵 2》，在游戏内按 Enter 唤醒黑金悬浮框输入中文。
4. 按 Enter 发送文本；开启翻译后按 Alt+T 翻译、Ctrl+Tab 选择注入原文或译文。

## 常见问题与环境兼容性 FAQ

1. **管理员权限要求（以管理员身份运行）**：
   - **为什么需要管理员权限？**《绝地潜兵 2》及其反作弊系统或 Steam 经常以高权限运行。在 Windows 系统中，根据 UIPI（用户界面特权隔离）机制，低权限程序无法向高权限游戏窗口发送输入模拟或拦截按键。
   - **EXE 与 AHK 的区别**：直接运行 `hd2_chat.ahk` 时，已安装的 AHK v2 解释器默认带有 UIA (UI Access) 权限；而独立的 `HD2ChatOverlay.exe` 需要用户**右键选择「以管理员身份运行」**（或在右键 ➔ 属性 ➔ 兼容性中勾选「以管理员身份运行」），即可保障游戏内键盘响应 100% 正常。

2. **游戏画面显示模式（无边框全屏）**：
   - **强烈推荐**：在《绝地潜兵 2》游戏图像设置中将显示模式设置为**【无边框全屏】**或**【窗口化】**。
   - **注意**：若强制设置为“独占全屏”（Exclusive Fullscreen），DirectX/Vulkan 独占渲染管道会绕过 Windows 桌面合成器，可能导致悬浮窗无法置顶显示或唤醒时引发窗口切出（Alt-Tab）。

3. **多分辨率与位置微调 (1080P / 2K / 4K)**：
   - 完美兼容 1080P、2K、4K 及超宽屏。悬浮窗基于屏幕/游戏窗口右下角计算相对坐标，并带有屏幕边界自动限制防溢出保护。
   - 首次启动若位置与游戏原生聊天框有微小偏差，可在唤醒悬浮窗时按 `Ctrl + Alt + 方向键`（每次 5 像素）实时微调，微调结果会自动持久化保存。

4. **游戏帧率 (FPS) 与打字稳定性**：
   - 悬浮窗为原生 Win32 DWM 窗口，打字与响应始终维持系统级流畅，不受游戏帧率波动影响。
   - 逐字 Unicode 注入默认设置了 15ms 帧间延迟（`ChunkDelay=15`）。若遇到极限低帧率（<20 FPS）游戏卡顿导致掉字，可在 `hd2_chat_settings.ini` 中将 `ChunkDelay` 调整为 `20`~`30` 毫秒。

5. **黑话术语库与 Python 依赖**：
   - 普通玩家**完全不需要安装 Python 或 Conda**。黑话词库基于纯 AHK 原生 AC 自动机算法构建，并通过 HTTP 协议在线热更新 JSON 资源。
   - Python（`tools/glossary_scraper.py`）仅为开发者或高级用户的本地爬虫工具。

6. **配置防呆备份与一键回滚**：
   - 每次在配置面板保存设置或修改参数时，系统会自动在本地将原配置文件备份为 `hd2_chat_settings.ini.bak`（最多保留 3 份历史备份）。
   - 若误填 API 密钥、热键冲突或不小心把悬浮窗挪到屏幕外，右键系统托盘图标选择「🔄 回滚到上一版本配置」即可一键恢复上一版正常配置并自动重启脚本。

7. **输入法与 CapsLock 大写锁定控制机制**：
   - **输入法自动唤醒**：在按 Enter 唤醒悬浮窗时，程序会自动调用 Win32 API 开启当前系统的中文输入法，便于直接打字。
   - **游戏内大写锁定 (CapsLock)**：在完成文本注入或未处于悬浮窗状态时，程序会自动将 CapsLock 设为开启 (`On`)。由于绝大多数中文输入法在 CapsLock 开启状态下会直接输出英文字母，可有效避免在游戏操作中按键误弹出拼音候选框干扰操作。




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

