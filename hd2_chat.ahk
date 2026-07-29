#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
KeyHistory 0

; -------------------------------------------------------------
; HD2 Chat Overlay - 主入口
; 版本: 1.0.0
; 功能: 《绝地潜兵 2》中文输入悬浮窗插件
; -------------------------------------------------------------

; 🎯 统一屏幕坐标系
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; -------------------------------------------------------------
; 引用模块
; -------------------------------------------------------------
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Utils.ahk
#Include %A_ScriptDir%\lib\Gui.ahk
#Include %A_ScriptDir%\lib\Injection.ahk
#Include %A_ScriptDir%\lib\Tray.ahk

; -------------------------------------------------------------
; 初始化
; -------------------------------------------------------------
EnsureSingleInstance()
AppConfig.Load()
InitTrayMenu()
InitChatGui()

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

_ProcessShellEvent(activeHwnd) {
    global lastActiveHwnd, isChatActive, isBoundToGame, lastShellEventTime

    ; 防抖: 50ms 内重复事件跳过
    now := A_TickCount
    if (now - lastShellEventTime < SHELL_DEBOUNCE_MS)
        return
    lastShellEventTime := now

    ; 游戏窗口句柄缓存
    gameHwnd := GetGameHwnd()

    if !activeHwnd || activeHwnd == chatGui.Hwnd
        return

    procName := ""
    try {
        procName := WinGetProcessName("ahk_id " activeHwnd)
    } catch {
        procName := "Unknown"
    }

    guiThreadId := DllCall("GetWindowThreadProcessId", "Ptr", chatGui.Hwnd, "Ptr", 0, "UInt")
    activeThreadId := DllCall("GetWindowThreadProcessId", "Ptr", activeHwnd, "Ptr", 0, "UInt")
    activeOwner := DllCall("GetWindow", "Ptr", activeHwnd, "UInt", 4, "Ptr")

    ; 过滤 IME 子窗口与自身线程
    if (procName ~= "i)(TextInputHost|ctfmon|SogouInput|QQInput|BaiduInput)\.exe"
        || activeThreadId == guiThreadId
        || activeOwner == chatGui.Hwnd) {
        return
    }

    if (gameHwnd && activeHwnd = gameHwnd) {
        if DllCall("IsHungAppWindow", "Ptr", gameHwnd)
            return
        if isChatActive
            return
        DisableGameIME()
    } else if (activeHwnd != 0) {
        if (isChatActive && !isAdjusting) {
            CloseGui(false)
        }
        SetCapsLockSafe("Off")
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

; 悬浮窗激活时: Enter 提交, Esc 取消, 滚轮转发, 位置调整
#HotIf isChatActive || WinActive("ahk_id " chatGui.Hwnd)

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

; 游戏内 F12 重载
#HotIf WinActive("ahk_exe helldivers2.exe")
F12:: Reload()
#HotIf

; -------------------------------------------------------------
; 启动完成
; -------------------------------------------------------------
WriteLog("[Main] HD2 Chat Overlay v" SCRIPT_VERSION " 启动完成")
TrayTip("HD2 Chat Overlay", "插件已在后台运行,按 Enter 唤醒输入框", 1)
