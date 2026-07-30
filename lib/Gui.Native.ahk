; lib/Gui.Native.ahk - 原生 AHK 悬浮窗实现

global nativeChatGui := ""
global nativeEditBox := ""
global nativeIsChatActive := false

global hDarkBrush := 0

global nativePrefixText := ""
global hDarkBrush := 0

InitNativeChatGui() {
    global nativeChatGui, nativeEditBox, nativePrefixText, hDarkBrush

    nativeChatGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    nativeChatGui.BackColor := "0D0E12"

    ; 修改 Win32 窗口类背景刷子为暗色 (0x0D0E12 RGB -> 0x120E0D BGR)
    hDarkBrush := DllCall("CreateSolidBrush", "UInt", 0x00120E0D, "Ptr")
    DllCall("SetClassLongPtr", "Ptr", nativeChatGui.Hwnd, "Int", -10, "Ptr", hDarkBrush)

    ; 拦截 Edit 和 Static 控件颜色绘制 (WM_CTLCOLOREDIT 0x0133 / WM_CTLCOLORSTATIC 0x0138)
    OnMessage(0x0133, Native_WM_CTLCOLOR)
    OnMessage(0x0138, Native_WM_CTLCOLOR)

    ; 左侧绝地黄 (Helldivers Gold #FFC800) 4px 纵向高亮边条
    nativeChatGui.AddProgress("x0 y0 w4 h58 BackgroundFFC800")

    ; 左侧图标与前缀 (w105 宽度充裕, 绝不遮挡右括号 ])
    nativeChatGui.SetFont("s15 Bold cFFC800", "Microsoft YaHei")
    nativePrefixText := nativeChatGui.AddText("x14 y11 w105 h36 +0x200", "💬 [中]")

    ; 动态输入框 (从 x125 开始, 留出 6px 安全间隔, 彻底解决文字重叠)
    nativeChatGui.SetFont("s16 Bold cFFFFFF", "Microsoft YaHei")
    nativeEditBox := nativeChatGui.AddEdit("x125 y7 w500 h44 -Border -E0x0200 cFFFFFF")

    ; 禁用 DWM 窗口过渡动画
    dwmDisableAnim := Buffer(4, 0)
    NumPut("Int", 1, dwmDisableAnim)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", nativeChatGui.Hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

    ; 离屏驻留 (w640 h58 大容器, 完整覆包裹原版聊天框)
    nativeChatGui.Show("x-9999 y-9999 w640 h58 NA")

    OnMessage(0x0201, Native_WM_LBUTTONDOWN)
}

Native_SetPrefixText(text) {
    global nativePrefixText
    if (nativePrefixText) {
        try nativePrefixText.Value := text
    }
}

Native_WM_CTLCOLOR(wParam, lParam, msg, hwnd) {
    global nativeEditBox, nativePrefixText, hDarkBrush
    if (nativeEditBox && lParam == nativeEditBox.Hwnd) {
        DllCall("SetTextColor", "Ptr", wParam, "UInt", 0x00FFFFFF) ; 纯白文字
        DllCall("SetBkColor", "Ptr", wParam, "UInt", 0x00120E0D)   ; 暗黑背景 (0x0D0E12 RGB -> 0x120E0D BGR)
        return hDarkBrush
    }
    if (nativePrefixText && lParam == nativePrefixText.Hwnd) {
        DllCall("SetTextColor", "Ptr", wParam, "UInt", 0x0000C8FF) ; 绝地黄 (0xFFC800 RGB -> 0x00C8FF BGR)
        DllCall("SetBkColor", "Ptr", wParam, "UInt", 0x00120E0D)
        return hDarkBrush
    }
}

Native_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global nativeChatGui, nativeEditBox
    if (hwnd == nativeChatGui.Hwnd) {
        nativeEditBox.Focus()
        Native_SetEditCaret()
    }
}

Native_SetEditCaret() {
    global nativeEditBox
    try {
        DllCall("CreateCaret", "Ptr", nativeEditBox.Hwnd, "Ptr", 0, "Int", 2, "Int", 22)
        DllCall("ShowCaret", "Ptr", nativeEditBox.Hwnd)
    }
}

Native_UpdateOverlayDimensions(w, h, fontSz := 16) {
    global nativeChatGui, nativeEditBox, nativePrefixText
    if (!nativeChatGui || !nativeEditBox)
        return

    editW := w - 140
    if (editW < 100)
        editW := 100
    editH := h - 14
    if (editH < 20)
        editH := 20

    nativeEditBox.SetFont("s" fontSz " Bold cFFFFFF", "Microsoft YaHei")
    nativeEditBox.Move(125, 7, editW, editH)
    nativeChatGui.Move(, , w, h)
}

Native_CalculateOverlayPos(offX, offY, w, h, &posX, &posY) {
    global nativeChatGui
    gameHwnd := GetGameHwnd()
    targetHwnd := 0

    if (gameHwnd && WinExist("ahk_id " gameHwnd)) {
        targetHwnd := gameHwnd
    } else {
        targetHwnd := WinActive("A")
        if (nativeChatGui && targetHwnd == nativeChatGui.Hwnd)
            targetHwnd := 0
    }

    if (targetHwnd && WinExist("ahk_id " targetHwnd)) {
        try {
            WinGetPos(&X, &Y, &W_win, &H_win, "ahk_id " targetHwnd)
            if (X > -10000 && Y > -10000 && W_win > 100 && H_win > 100) {
                posX := X + W_win - offX
                posY := Y + H_win - offY
                LimitGuiPos(targetHwnd, &posX, &posY, w, h)
                return
            }
        } catch {
        }
    }

    posX := A_ScreenWidth - offX
    posY := A_ScreenHeight - offY
    LimitGuiPos(0, &posX, &posY, w, h)
}

Native_ShowChatGui() {
    global nativeIsChatActive, nativeChatGui, nativeEditBox

    if nativeIsChatActive
        return

    nativeIsChatActive := true

    w := AppConfig.OverlayWidth > 0 ? AppConfig.OverlayWidth : 640
    h := AppConfig.OverlayHeight > 0 ? AppConfig.OverlayHeight : 58

    posX := 0, posY := 0
    Native_CalculateOverlayPos(AppConfig.OffsetX, AppConfig.OffsetY, w, h, &posX, &posY)

    WriteLog("[Gui.Native] 显示原生悬浮窗: x=" posX " y=" posY " w=" w " h=" h)

    Native_UpdateOverlayDimensions(w, h, AppConfig.FontSize)
    nativeChatGui.Show(Format("x{1} y{2} w{3} h{4}", posX, posY, w, h))
    WinSetTransparent(248, "ahk_id " nativeChatGui.Hwnd)
    WinActivate("ahk_id " nativeChatGui.Hwnd)
    nativeEditBox.Value := ""
    nativeEditBox.Focus()
    Native_SetEditCaret()
    Native_SetGuiLayoutToChinese()
}

Native_SetGuiLayoutToChinese() {
    global nativeChatGui
    try {
        IME_SET(1, "ahk_id " nativeChatGui.Hwnd)
    } catch Error as err {
        WriteLog("[Native_SetGuiLayoutToChinese] 异常: " err.Message)
    }
}

Native_HideGuiToOffscreen() {
    global nativeChatGui, nativeIsChatActive
    nativeIsChatActive := false
    if (nativeChatGui) {
        nativeChatGui.Move(-9999, -9999)
        nativeChatGui.Hide()
    }
    gameHwnd := GetGameHwnd()
    if (gameHwnd && WinExist("ahk_id " gameHwnd)) {
        try WinActivate("ahk_id " gameHwnd)
    }
}

Native_GetText() {
    global nativeEditBox
    return nativeEditBox.Value
}

Native_ClearText() {
    global nativeEditBox
    nativeEditBox.Value := ""
}

Native_IsActive() {
    global nativeIsChatActive
    return nativeIsChatActive
}

Native_SetActive(state) {
    global nativeIsChatActive
    nativeIsChatActive := state
}

Native_GetHwnd() {
    global nativeChatGui
    return nativeChatGui ? nativeChatGui.Hwnd : 0
}

Native_GetEditHwnd() {
    global nativeEditBox
    return nativeEditBox ? nativeEditBox.Hwnd : 0
}

Native_Destroy() {
    global nativeChatGui, nativeIsChatActive
    if (nativeChatGui) {
        nativeChatGui.Destroy()
        nativeChatGui := ""
    }
    nativeIsChatActive := false
}

Native_RebuildChatGui() {
    Native_DestroyChatGui()
    InitNativeChatGui()
    WriteLog("[Gui.Native] 原生悬浮窗已重建")
}

Native_DestroyChatGui() {
    Native_Destroy()
}

Native_FocusEdit() {
    global nativeEditBox
    if (nativeEditBox)
        nativeEditBox.Focus()
}
