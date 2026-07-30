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
global g_injectSource := "original"   ; 注入源: "original" 原文框 | "translated" 译文框

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

    ; 注入源初始状态: 开启翻译默认译文框, 否则原文框
    g_injectSource := AppConfig.EnableAutoTranslate ? "translated" : "original"

    Native_ShowChatGui()
    Native_HighlightSource(g_injectSource)
}

; -------------------------------------------------------------
; 注入源状态机: 设置/切换 (Ctrl+Tab)
; -------------------------------------------------------------
SetInjectSource(source) {
    global g_injectSource
    ; 译文框不可见或为空时强制回退原文框
    if (source = "translated" && (!Native_IsTransVisible() || Native_GetTransText() = ""))
        source := "original"
    g_injectSource := source
    Native_HighlightSource(source)
    WriteLog("[Gui] 注入源切换: " source)
}

ToggleInjectSource(*) {
    global g_injectSource
    if !isChatActive
        return
    if (!AppConfig.EnableAutoTranslate || !Native_IsTransVisible())
        return
    SetInjectSource(g_injectSource = "translated" ? "original" : "translated")
    FocusInput()
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
    global isChatActive, nativeIsChatActive, g_injectSource

    if !isChatActive {
        nativeIsChatActive := false
        return
    }

    isChatActive := false
    nativeIsChatActive := false
    g_injectSource := "original"
    ClearInput()
    Native_ClearTransText()
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

            ; 译文框随主框联动 (位于正上方)
            if (nativeTransVisible && nativeTransGui) {
                w := AppConfig.OverlayWidth > 0 ? AppConfig.OverlayWidth : 640
                h := AppConfig.OverlayHeight > 0 ? AppConfig.OverlayHeight : 58
                transY := posY - h - TRANS_OVERLAY_GAP
                if (transY < 0)
                    transY := 0
                nativeTransGui.Move(posX, transY, w, h)
            }
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
