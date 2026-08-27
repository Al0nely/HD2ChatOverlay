#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
; 🛡️ PE 元数据与清单正规化伪装配置 (Ahk2Exe 预编译指令)
; =============================================================
;@Ahk2Exe-SetDescription HELLDIVERS™ 2 Text Input & Accessibility Assistant
;@Ahk2Exe-SetProductName HD2 Chat Overlay
;@Ahk2Exe-SetFileVersion 1.4.3.0
;@Ahk2Exe-SetProductVersion 1.4.3.0
;@Ahk2Exe-SetCompanyName Arrowhead Community Tools
;@Ahk2Exe-SetCopyright Copyright (C) 2024-2026 Al0nely. All rights reserved.
;@Ahk2Exe-SetOrigFilename HD2ChatOverlay.exe
;@Ahk2Exe-UpdateManifest 0

ListLines 0
KeyHistory 0

; 提高当前进程调度优先级至 AboveNormal，确保在游戏高 CPU 占用 (80-100%) 时按键拦截与悬浮窗响应丝滑无卡顿
try ProcessSetPriority("AboveNormal")

; -------------------------------------------------------------
; HD2 Chat Overlay - 主入口
; 版本: 1.4.3
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

; 隐藏 AHK 默认窗口标题指纹，伪装为正常文本服务宿主
try WinSetTitle("HD2_TextServices_Host", "ahk_id " A_ScriptHwnd)

AppConfig.Load()

; 设置 DPI 感知 (必须在创建窗口前)
SetProcessDpiAwareness()

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
; ShellHook 窗口切换监听与焦点防抖
; -------------------------------------------------------------
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
global shellMessageNum := DllCall("RegisterWindowMessage", "Str", "ShellHook")
; 🛡️ 放行 ShellHook 跨完整性级别消息传递 (MSGFLT_ALLOW = 1)
DllCall("ChangeWindowMessageFilter", "UInt", shellMessageNum, "UInt", 1)
OnMessage(shellMessageNum, ShellMessageCallback)

global lastActiveHwnd := 0
global lastShellEventTime := 0
global SHELL_DEBOUNCE_MS := 60
global isGameActive := false

ShellMessageCallback(wParam, lParam, *) {
    global lastShellEventTime
    ; 1=WINDOWCREATED, 2=WINDOWDESTROYED, 4=WINDOWACTIVATED, 32769=RUDEAPPACTIVATED, 32772=TASKMAN
    if (wParam = 1 || wParam = 2 || wParam = 4 || wParam = 32769 || wParam = 32772) {
        now := A_TickCount
        if (now - lastShellEventTime < 40 && (wParam = 4 || wParam = 32769))
            return
        lastShellEventTime := now
        SetTimer(_ProcessShellEvent.Bind(lParam, wParam), -10)
    }
}

global overlayInvokedWindow := 0

_ProcessShellEvent(activeHwnd, eventType := 0) {
    global lastActiveHwnd, isChatActive, isBoundToGame, lastShellEventTime, overlayInvokedWindow, isGameActive

    gameHwnd := GetGameHwnd()

    ; 窗口销毁事件 (wParam = 2): 若游戏进程/窗口销毁，及时重置缓存
    if (eventType = 2) {
        if (gameHwnd && activeHwnd == gameHwnd) {
            isGameActive := false
            InvalidateGameHwndCache()
            if (isChatActive)
                CloseGui(false)
        }
        return
    }

    guiHwnd := GetChatGuiHwnd()

    if !activeHwnd || activeHwnd == guiHwnd || activeHwnd == overlayInvokedWindow
        return

    ; 防抖: 目标为游戏窗口的切回事件始终优先处理；非游戏窗口事件 60ms 内重复跳过
    now := A_TickCount
    isTargetingGame := (gameHwnd && activeHwnd == gameHwnd)
    if (!isTargetingGame && (now - lastShellEventTime < SHELL_DEBOUNCE_MS))
        return
    lastShellEventTime := now

    procName := ""
    activePid := 0
    try {
        activePid := WinGetPID("ahk_id " activeHwnd)
        procName := WinGetProcessName("ahk_id " activeHwnd)
    } catch {
        procName := "Unknown"
    }

    myPid := DllCall("GetCurrentProcessId", "UInt")
    myThreadId := DllCall("GetCurrentThreadId", "UInt")
    activeThreadId := DllCall("GetWindowThreadProcessId", "Ptr", activeHwnd, "Ptr", 0, "UInt")
    activeOwner := guiHwnd ? DllCall("GetWindow", "Ptr", activeHwnd, "UInt", 4, "Ptr") : 0

    ; 过滤 IME 子窗口与自身进程/线程创建的所有窗口 (包含译文悬浮窗 nativeTransGui、配置窗口等)
    if (activePid == myPid
        || activeThreadId == myThreadId
        || (procName ~= "i)(TextInputHost|ctfmon|SogouInput|QQInput|BaiduInput)\.exe")
        || activeOwner == guiHwnd) {
        return
    }

    if (gameHwnd && activeHwnd = gameHwnd) {
        isGameActive := true
        if DllCall("IsHungAppWindow", "Ptr", gameHwnd)
            return
        if isChatActive
            return
        DisableGameIME()
    } else if (activeHwnd != 0) {
        isGameActive := false
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
; 焦点、CapsLock 与卡死自愈后台监视器 (1秒轮询)
; -------------------------------------------------------------
SetTimer(CheckGameFocusWatchdog, 1000)

CheckGameFocusWatchdog() {
    global isChatActive, isAdjusting, isGameActive
    gameHwnd := GetGameHwnd()
    
    ; 1. 状态自愈：游戏关闭或不存在时，若 isChatActive 残留，强制清空并收起
    if (!gameHwnd || !WinExist("ahk_id " gameHwnd)) {
        isGameActive := false
        if (isChatActive && !WinActive("ahk_id " GetChatGuiHwnd())) {
            CloseGui(false)
        }
        return
    }

    ; 2. 当返回游戏且未开启 Overlay 输入框时，兜底确保 CapsLock 设为 On
    if WinActive("ahk_id " gameHwnd) {
        isGameActive := true
        if (!isChatActive && !isAdjusting) {
            if (!GetKeyState("CapsLock", "T")) {
                DisableGameIME()
            }
        }
    } else {
        isGameActive := false
        ; 离开游戏窗口且悬浮窗处于激活态时，自动关闭悬浮窗以防卡死
        if (isChatActive && !isAdjusting && !AppConfig.GlobalTestMode && !WinActive("ahk_id " GetChatGuiHwnd())) {
            CloseGui(false)
        }
    }
}

global g_ignoreEnterUntil := 0

; -------------------------------------------------------------
; 热键定义
; -------------------------------------------------------------

; 游戏内且未激活聊天时: Enter 唤醒悬浮窗 (极速短路求值，减少全局 Enter 击键延迟)
#HotIf (isGameActive || AppConfig.GlobalTestMode || (WinActive("ahk_id " GetGameHwnd()))) && !isChatActive && !isAdjusting && (A_TickCount > g_ignoreEnterUntil)

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

^!Left:: AdjustGuiPos(-5, 0)
^!Right:: AdjustGuiPos(5, 0)
^!Up:: AdjustGuiPos(0, -5)
^!Down:: AdjustGuiPos(0, 5)
#HotIf

; 游戏内 F12 安全重载
#HotIf WinActive("ahk_exe helldivers2.exe")
F12:: SafeReload()
#HotIf

; -------------------------------------------------------------
; 启动完成
; -------------------------------------------------------------
WriteLog("[Main] HD2 Chat Overlay v" SCRIPT_VERSION " 启动完成")
TrayTip("HD2 Chat Overlay", "插件已在后台运行,按 Enter 唤醒输入框", 1)
