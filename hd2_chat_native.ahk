#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
KeyHistory 0

; -------------------------------------------------------------
; HD2 Chat Overlay - 纯原生控件入口
; 版本: 1.1.0
; 说明: 强制使用原生 AHK 控件,禁用 WebView2,用于兼容旧系统或调试
; -------------------------------------------------------------

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; 强制禁用 WebView2
AppConfig_UseWebView2_Override := false

#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Utils.ahk
#Include %A_ScriptDir%\lib\WebView2Host.ahk
#Include %A_ScriptDir%\lib\Gui.Native.ahk
#Include %A_ScriptDir%\lib\ConfigGui.Native.ahk
#Include %A_ScriptDir%\lib\Gui.ahk
#Include %A_ScriptDir%\lib\Injection.ahk
#Include %A_ScriptDir%\lib\Tray.ahk

EnsureSingleInstance()
SetProcessDpiAwareness()
AppConfig.Load()

; 强制原生模式
AppConfig.UseWebView2 := false
AppConfig.Save()

InitTrayMenu()
InitChatGui()

; -------------------------------------------------------------
; ShellHook 窗口切换监听
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
#HotIf (WinActive("ahk_exe helldivers2.exe") || AppConfig.GlobalTestMode) && !isChatActive && !isAdjusting
$~$Enter::
$~$NumpadEnter:: {
    ShowChatGui()
}
#HotIf

#HotIf isChatActive || WinActive("ahk_id " GetChatGuiHwnd())
Enter:: SubmitText()
NumpadEnter:: SubmitText()
Escape:: CloseGui(true)
WheelUp:: ForwardScrollToGame("WheelUp")
WheelDown:: ForwardScrollToGame("WheelDown")
PgUp:: ForwardScrollToGame("WheelUp")
PgDn:: ForwardScrollToGame("WheelDown")
^!Left:: AdjustGuiPos(-10, 0)
^!Right:: AdjustGuiPos(10, 0)
^!Up:: AdjustGuiPos(0, -10)
^!Down:: AdjustGuiPos(0, 10)
#HotIf

#HotIf WinActive("ahk_exe helldivers2.exe")
F12:: Reload()
#HotIf

; 诊断热键: F9 强制显示悬浮窗 (用于测试)
F9:: {
    WriteLog("[Main] F9 诊断热键触发")
    ShowChatGui()
}

WriteLog("[Main] HD2 Chat Overlay v" SCRIPT_VERSION " (原生模式) 启动完成")
TrayTip("HD2 Chat Overlay", "原生模式已启动,按 Enter 唤醒输入框", 1)
