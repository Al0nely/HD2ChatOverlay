#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
KeyHistory 0



; -------------------------------------------------------------
; 🛡️ 管理员权限自动提升 (解决游戏独占窗口 UIPI 拦截 Enter 无响应问题)
; -------------------------------------------------------------
if (!A_IsAdmin) {
    try {
        if (A_IsCompiled)
            Run('*RunAs "' A_ScriptFullpath '"')
        else
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullpath '"')
    } catch {
        MsgBox("以管理员身份运行失败，在游戏独占全屏下按键响应可能受限。`n建议右键可执行文件选择『以管理员身份运行』。", "HD2 Chat Overlay", "Icon!")
    }
    ExitApp()
}

; -------------------------------------------------------------
; HD2 Chat Overlay - 主入口
; 版本: 1.4.0
; 功能: 《绝地潜兵 2》中文输入悬浮窗插件 (原生模式)
; -------------------------------------------------------------

; 🎯 统一屏幕坐标系
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; -------------------------------------------------------------
; 引用模块
; -------------------------------------------------------------
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Utils.ahk
#Include %A_ScriptDir%\lib\Translation.ahk
#Include %A_ScriptDir%\lib\Glossary.ahk
#Include %A_ScriptDir%\lib\Gui.Native.ahk
#Include %A_ScriptDir%\lib\ConfigGui.Native.ahk
#Include %A_ScriptDir%\lib\Gui.ahk
#Include %A_ScriptDir%\lib\Injection.ahk
#Include %A_ScriptDir%\lib\Tray.ahk

; -------------------------------------------------------------
; 初始化
; -------------------------------------------------------------
EnsureSingleInstance()

; 设置 DPI 感知 (必须在创建窗口前)
SetProcessDpiAwareness()

AppConfig.Load()

; 初始化术语库 (AC 自动机), 失败不阻塞主流程
Glossary.Init()

InitTrayMenu()
InitChatGui()

; 动态绑定翻译/切换注入源热键 (INI [Hotkeys] 可自定义)
RegisterTranslationHotkeys()

RegisterTranslationHotkeys() {
    ; 仅在悬浮窗激活时生效 (与下方 #HotIf 条件一致)
    HotIf((*) => isChatActive || WinActive("ahk_id " GetChatGuiHwnd()))
    if (AppConfig.TranslateKey != "") {
        try Hotkey(AppConfig.TranslateKey, TranslateCurrentText)
        catch Error as err
            WriteLog("[Main] 翻译热键注册失败 (" AppConfig.TranslateKey "): " err.Message)
    }
    if (AppConfig.SwitchSourceKey != "") {
        try Hotkey(AppConfig.SwitchSourceKey, ToggleInjectSource)
        catch Error as err
            WriteLog("[Main] 切换注入源热键注册失败 (" AppConfig.SwitchSourceKey "): " err.Message)
    }
    HotIf()  ; 重置上下文
}

; -------------------------------------------------------------
; ShellHook 窗口切换监听(带防抖)
; -------------------------------------------------------------
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
global shellMessageNum := DllCall("RegisterWindowMessage", "Str", "ShellHook")
OnMessage(shellMessageNum, ShellMessageCallback)

global lastActiveHwnd := 0
global lastShellEventTime := 0
global SHELL_DEBOUNCE_MS := 50

ShellMessageCallback(wParam, lParam, *) {
    if (wParam = 1 || wParam = 4 || wParam = 32769 || wParam = 32772) {
        SetTimer(_ProcessShellEvent.Bind(lParam), -1)
    }
}

global overlayInvokedWindow := 0

_ProcessShellEvent(activeHwnd) {
    global lastActiveHwnd, isChatActive, isBoundToGame, lastShellEventTime, overlayInvokedWindow

    ; 防抖: 50ms 内重复事件跳过
    now := A_TickCount
    if (now - lastShellEventTime < SHELL_DEBOUNCE_MS)
        return
    lastShellEventTime := now

    gameHwnd := GetGameHwnd()
    guiHwnd := GetChatGuiHwnd()

    if !activeHwnd || activeHwnd == guiHwnd || activeHwnd == overlayInvokedWindow
        return

    procName := ""
    try {
        procName := WinGetProcessName("ahk_id " activeHwnd)
    } catch {
        procName := "Unknown"
    }

    guiThreadId := guiHwnd ? DllCall("GetWindowThreadProcessId", "Ptr", guiHwnd, "Ptr", 0, "UInt") : 0
    activeThreadId := DllCall("GetWindowThreadProcessId", "Ptr", activeHwnd, "Ptr", 0, "UInt")
    activeOwner := guiHwnd ? DllCall("GetWindow", "Ptr", activeHwnd, "UInt", 4, "Ptr") : 0

    ; 过滤 IME 子窗口与自身线程
    if (procName ~= "i)(TextInputHost|ctfmon|SogouInput|QQInput|BaiduInput)\.exe"
        || activeThreadId == guiThreadId
        || activeOwner == guiHwnd) {
        return
    }

    if (gameHwnd && activeHwnd = gameHwnd) {
        if DllCall("IsHungAppWindow", "Ptr", gameHwnd)
            return
        if isChatActive
            return
        DisableGameIME()
    } else if (activeHwnd != 0) {
        if (isChatActive && !isAdjusting && !AppConfig.GlobalTestMode) {
            CloseGui(false)
        }
        if (!isChatActive) {
            SetCapsLockSafe("Off")
        }
        isBoundToGame := false
    }
    lastActiveHwnd := activeHwnd
}

; -------------------------------------------------------------
; 热键定义
; -------------------------------------------------------------

; 游戏内且未激活聊天时: Enter 唤醒悬浮窗
#HotIf (WinActive("ahk_exe helldivers2.exe") || AppConfig.GlobalTestMode) && !isChatActive && !isAdjusting

$~$Enter::
$~$NumpadEnter:: {
    ShowChatGui()
}

#HotIf

; 悬浮窗激活时: Enter 提交(按选中框), Esc 取消, 滚轮转发, 位置调整
; 翻译(Ctrl+T)与切换注入源(Ctrl+Tab)热键由 RegisterTranslationHotkeys() 动态注册
#HotIf isChatActive || WinActive("ahk_id " GetChatGuiHwnd())

Enter:: SubmitText()
NumpadEnter:: SubmitText()
Escape:: CloseGui(true)

WheelUp:: ForwardScrollToGame("WheelUp")
WheelDown:: ForwardScrollToGame("WheelDown")
PgUp:: ForwardScrollToGame("WheelUp")
PgDn:: ForwardScrollToGame("WheelDown")

^!Left:: AdjustGuiPos(-5, 0)
^!Right:: AdjustGuiPos(5, 0)
^!Up:: AdjustGuiPos(0, -5)
^!Down:: AdjustGuiPos(0, 5)

+Left:: AdjustGuiPos(-5, 0)
+Right:: AdjustGuiPos(5, 0)
+Up:: AdjustGuiPos(0, -5)
+Down:: AdjustGuiPos(0, 5)

!Left:: AdjustGuiPos(-5, 0)
!Right:: AdjustGuiPos(5, 0)
!Up:: AdjustGuiPos(0, -5)
!Down:: AdjustGuiPos(0, 5)
#HotIf

; 游戏内 F12 重载
#HotIf WinActive("ahk_exe helldivers2.exe")
F12:: Reload()
#HotIf

; 诊断热键: F9 强制显示悬浮窗 (用于测试)
F9:: {
    WriteLog("[Main] F9 诊断热键触发")
    ShowChatGui()
}

; -------------------------------------------------------------
; 启动完成
; -------------------------------------------------------------
WriteLog("[Main] HD2 Chat Overlay v" SCRIPT_VERSION " 启动完成")
TrayTip("HD2 Chat Overlay", "插件已在后台运行,按 Enter 唤醒输入框", 1)
