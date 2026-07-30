; lib/Gui.ahk - 悬浮窗与配置窗口门面 (Facade)
; 路由到原生控件实现

; -------------------------------------------------------------
; 全局状态
; -------------------------------------------------------------
global chatGui := ""          ; 原生模式 GUI 对象 (兼容旧代码)
global editBox := ""          ; 原生模式 Edit 对象 (兼容旧代码)
global isChatActive := false
global isAdjusting := false
global lastShowTime := 0
global isBoundToGame := false

; -------------------------------------------------------------
; 初始化悬浮窗
; -------------------------------------------------------------
InitChatGui() {
    global chatGui, editBox

    WriteLog("[Gui] InitChatGui 开始")
    InitNativeChatGui()
    chatGui := nativeChatGui
    editBox := nativeEditBox
    WriteLog("[Gui] 原生悬浮窗已创建")
}

; -------------------------------------------------------------
; 显示悬浮窗
; -------------------------------------------------------------
ShowChatGui() {
    global isChatActive, lastShowTime, isBoundToGame, overlayInvokedWindow

    WriteLog("[Gui] ShowChatGui 被调用, isChatActive=" isChatActive)

    if (isChatActive || (A_TickCount - lastShowTime < 200)) {
        WriteLog("[Gui] 显示被跳过: isChatActive=" isChatActive ", 时间间隔=" (A_TickCount - lastShowTime))
        return
    }

    try {
        overlayInvokedWindow := WinActive("A")
    } catch {
        overlayInvokedWindow := 0
    }

    isChatActive := true
    lastShowTime := A_TickCount
    SetCapsLockSafe("Off")
    try {
        IME_SET(1, "A")
    } catch {
    }

    Native_ShowChatGui()
}

; -------------------------------------------------------------
; 隐藏悬浮窗到离屏
; -------------------------------------------------------------
HideGuiToOffscreen() {
    Native_HideGuiToOffscreen()

    gameHwnd := GetGameHwnd()
    if gameHwnd {
        try WinActivate("ahk_id " gameHwnd)
    }
}

CloseGui(sendEsc := false) {
    global isChatActive, nativeIsChatActive

    if !isChatActive {
        nativeIsChatActive := false
        return
    }

    isChatActive := false
    nativeIsChatActive := false
    ClearInput()
    HideGuiToOffscreen()

    gameHwnd := GetGameHwnd()
    if gameHwnd {
        if (sendEsc) {
            ReleaseModifiers()
            SendEvent("{Escape}")
        }
        DisableGameIME()
    }
}

; -------------------------------------------------------------
; 获取输入文本
; -------------------------------------------------------------
GetInputText() {
    return Native_GetText()
}

; -------------------------------------------------------------
; 清空输入框
; -------------------------------------------------------------
ClearInput() {
    Native_ClearText()
}

; -------------------------------------------------------------
; 设置焦点到输入框
; -------------------------------------------------------------
FocusInput() {
    Native_FocusEdit()
    Native_SetEditCaret()
}

; -------------------------------------------------------------
; 检查悬浮窗是否激活
; -------------------------------------------------------------
GetIsChatActive() {
    return Native_IsActive()
}

; -------------------------------------------------------------
; 设置悬浮窗激活状态
; -------------------------------------------------------------
SetIsChatActive(state) {
    global isChatActive
    isChatActive := state
    Native_SetActive(state)
}

; -------------------------------------------------------------
; 获取悬浮窗句柄
; -------------------------------------------------------------
GetChatGuiHwnd() {
    global chatGui
    if (chatGui) {
        return chatGui.Hwnd
    }
    return 0
}

; -------------------------------------------------------------
; 获取输入框句柄
; -------------------------------------------------------------
GetEditHwnd() {
    global editBox
    if (editBox) {
        return editBox.Hwnd
    }
    return 0
}

; -------------------------------------------------------------
; 重建悬浮窗 (应用新配置)
; -------------------------------------------------------------
RebuildChatGui() {
    global chatGui, editBox

    Native_RebuildChatGui()
    chatGui := nativeChatGui
    editBox := nativeEditBox

    WriteLog("[Gui] 悬浮窗已重建,字体: " AppConfig.FontName)
}

; -------------------------------------------------------------
; 销毁悬浮窗
; -------------------------------------------------------------
DestroyChatGui() {
    global chatGui

    Native_DestroyChatGui()
    chatGui := ""
}

; -------------------------------------------------------------
; 显示配置窗口
; -------------------------------------------------------------
ShowConfigGui() {
    Native_ShowConfigGui()
}

; -------------------------------------------------------------
; 位置调整
; -------------------------------------------------------------
AdjustGuiPos(deltaX, deltaY) {
    global isAdjusting

    isAdjusting := true

    AppConfig.OffsetX := AppConfig.OffsetX - deltaX
    AppConfig.OffsetY := AppConfig.OffsetY - deltaY

    gameHwnd := GetGameHwnd()
    if gameHwnd {
        try {
            WinGetPos(&X, &Y, &W, &H, "ahk_id " gameHwnd)
            posX := X + W - AppConfig.OffsetX
            posY := Y + H - AppConfig.OffsetY
            LimitGuiPos(gameHwnd, &posX, &posY)
            AppConfig.OffsetX := X + W - posX
            AppConfig.OffsetY := Y + H - posY

            nativeChatGui.Move(posX, posY)
        } catch TargetError {
        }
    }

    FocusInput()
    SetTimer(OnAdjustTimeout, -200)
}

OnAdjustTimeout() {
    global isAdjusting, chatGui

    isAdjusting := false
    AppConfig.Save()

    activeHwnd := WinActive("A")
    guiHwnd := chatGui ? chatGui.Hwnd : 0
    if (activeHwnd != guiHwnd) {
        CloseGui(false)
    }
}
