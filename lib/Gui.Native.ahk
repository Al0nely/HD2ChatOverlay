; lib/Gui.Native.ahk - 原生 AHK 悬浮窗实现 (原文框 + 译文框 双悬浮窗)

global nativeChatGui := ""
global nativeEditBox := ""
global nativeIsChatActive := false
global nativePrefixText := ""
global nativeProgressBar := ""
global hDarkBrush := 0

; 译文悬浮窗 (Translation Overlay)
global nativeTransGui := ""
global nativeTransEdit := ""
global nativeTransPrefix := ""
global nativeTransProgressBar := ""
global nativeTransVisible := false

; 译文框与原文框的垂直间距 (px)
global TRANS_OVERLAY_GAP := 6

GetLangTag(langName) {
    switch StrLower(Trim(langName)) {
        case "chinese", "中文", "zh": return "中"
        case "english", "英文", "en": return "英"
        case "japanese", "日文", "jp": return "日"
        case "german", "德文", "de": return "德"
        case "french", "法文", "fr": return "法"
        case "spanish", "西文", "es": return "西"
        case "russian", "俄文", "ru": return "俄"
        case "auto", "自动": return "自"
        default: return (StrLen(langName) > 0 ? SubStr(langName, 1, 2) : "自")
    }
}

InitNativeChatGui() {
    global nativeChatGui, nativeEditBox, nativePrefixText, nativeProgressBar, hDarkBrush

    nativeChatGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    nativeChatGui.BackColor := "0D0E12"

    ; 修改 Win32 窗口类背景刷子为暗色 (0x0D0E12 RGB -> 0x120E0D BGR)
    hDarkBrush := DllCall("CreateSolidBrush", "UInt", 0x00120E0D, "Ptr")
    DllCall("SetClassLongPtr", "Ptr", nativeChatGui.Hwnd, "Int", -10, "Ptr", hDarkBrush)

    ; 拦截 Edit 和 Static 控件颜色绘制 (WM_CTLCOLOREDIT 0x0133 / WM_CTLCOLORSTATIC 0x0138)
    OnMessage(0x0133, Native_WM_CTLCOLOR)
    OnMessage(0x0138, Native_WM_CTLCOLOR)

    ; 左侧绝地黄 (Helldivers Gold #FFC800) 4px 纵向高亮边条
    nativeProgressBar := nativeChatGui.AddProgress("x0 y0 w4 h58 BackgroundFFC800")

    ; 左侧图标与前缀 (动态响应源语言配置)
    srcTag := GetLangTag(AppConfig.SourceLanguage)
    nativeChatGui.SetFont("s15 Bold cFFC800", "Microsoft YaHei")
    nativePrefixText := nativeChatGui.AddText("x14 y11 w135 h36 +0x200", "💬 [" srcTag "]")

    ; 动态输入框 (从 x150 开始, EM_SETMARGINS 设置 6px 内边距彻底防止光标/选框边缘渗漏)
    nativeChatGui.SetFont("s16 Bold cFFFFFF", "Microsoft YaHei")
    nativeEditBox := nativeChatGui.AddEdit("x150 y7 w475 h44 -Border -E0x0200 cFFFFFF")
    DllCall("SendMessage", "Ptr", nativeEditBox.Hwnd, "UInt", 0x00D3, "Ptr", 3, "Ptr", (6 & 0xFFFF) | ((6 & 0xFFFF) << 16))

    ; 禁用 DWM 窗口过渡动画
    dwmDisableAnim := Buffer(4, 0)
    NumPut("Int", 1, dwmDisableAnim)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", nativeChatGui.Hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

    ; 离屏驻留 (w640 h58 大容器, 完整覆包裹原版聊天框)
    nativeChatGui.Show("x-9999 y-9999 w640 h58 NA")

    OnMessage(0x0201, Native_WM_LBUTTONDOWN)

    ; 创建译文悬浮窗 (初始离屏隐藏)
    InitNativeTransGui()
}

; -------------------------------------------------------------
; 译文悬浮窗初始化 (只读, 淡蓝 #4A9EFF 边条)
; -------------------------------------------------------------
InitNativeTransGui() {
    global nativeTransGui, nativeTransEdit, nativeTransPrefix, nativeTransProgressBar

    nativeTransGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Owner" nativeChatGui.Hwnd)
    nativeTransGui.BackColor := "0D0E12"

    ; 左侧淡蓝 (Translation Blue #4A9EFF) 4px 纵向高亮边条
    nativeTransProgressBar := nativeTransGui.AddProgress("x0 y0 w4 h58 Background4A9EFF")

    ; 前缀标签 (动态响应目标语言配置)
    targetTag := GetLangTag(AppConfig.TargetLanguage)
    nativeTransGui.SetFont("s15 Bold c4A9EFF", "Microsoft YaHei")
    nativeTransPrefix := nativeTransGui.AddText("x14 y11 w135 h36 +0x200", "🌐 [" targetTag "]")

    ; 只读译文框 (与原文框同布局, +ReadOnly 防误编辑)
    nativeTransGui.SetFont("s16 Bold cFFFFFF", "Microsoft YaHei")
    nativeTransEdit := nativeTransGui.AddEdit("x150 y7 w475 h44 -Border -E0x0200 +ReadOnly cFFFFFF")
    DllCall("SendMessage", "Ptr", nativeTransEdit.Hwnd, "UInt", 0x00D3, "Ptr", 3, "Ptr", (6 & 0xFFFF) | ((6 & 0xFFFF) << 16))

    ; 禁用 DWM 窗口过渡动画
    dwmDisableAnim := Buffer(4, 0)
    NumPut("Int", 1, dwmDisableAnim)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", nativeTransGui.Hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

    ; 离屏驻留
    nativeTransGui.Show("x-9999 y-9999 w640 h58 NA")
}

Native_SetPrefixText(text := "") {
    global nativePrefixText
    if (nativePrefixText) {
        try {
            if (text = "") {
                srcTag := GetLangTag(AppConfig.SourceLanguage)
                nativePrefixText.Value := "💬 [" srcTag "]"
            } else {
                nativePrefixText.Value := text
            }
        }
    }
}

Native_WM_CTLCOLOR(wParam, lParam, msg, hwnd) {
    global nativeEditBox, nativePrefixText, nativeTransEdit, nativeTransPrefix, hDarkBrush
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
    if (nativeTransEdit && lParam == nativeTransEdit.Hwnd) {
        DllCall("SetTextColor", "Ptr", wParam, "UInt", 0x00FFFFFF) ; 纯白文字
        DllCall("SetBkColor", "Ptr", wParam, "UInt", 0x00120E0D)
        return hDarkBrush
    }
    if (nativeTransPrefix && lParam == nativeTransPrefix.Hwnd) {
        DllCall("SetTextColor", "Ptr", wParam, "UInt", 0x00FF9E4A) ; 淡蓝 (0x4A9EFF RGB -> 0xFF9E4A BGR)
        DllCall("SetBkColor", "Ptr", wParam, "UInt", 0x00120E0D)
        return hDarkBrush
    }
}

Native_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global nativeChatGui, nativeEditBox
    if (hwnd == nativeChatGui.Hwnd && nativeEditBox) {
        nativeEditBox.Focus()
    }
}

Native_UpdateOverlayDimensions(w, h, fontSz := 16) {
    global nativeChatGui, nativeEditBox, nativePrefixText, nativeProgressBar
    if (!nativeChatGui || !nativeEditBox)
        return

    ; 高亮条高度随 h 联动
    if (nativeProgressBar)
        nativeProgressBar.Move(0, 0, 4, h)

    ; 前缀 Label 垂直居中与尺寸重排
    prefixH := 36
    prefixY := (h > prefixH) ? (h - prefixH) // 2 : 0
    if (nativePrefixText)
        nativePrefixText.Move(14, prefixY, 135, prefixH)

    ; Edit 输入框垂直居中与尺寸重排
    editX := 150
    editW := w - editX - 15
    if (editW < 100)
        editW := 100
    editH := h - 14
    if (editH < 20)
        editH := 20
    editY := (h > editH) ? (h - editH) // 2 : 0

    nativeEditBox.SetFont("s" fontSz " Bold cFFFFFF", "Microsoft YaHei")
    nativeEditBox.Move(editX, editY, editW, editH)
    DllCall("SendMessage", "Ptr", nativeEditBox.Hwnd, "UInt", 0x00D3, "Ptr", 3, "Ptr", (6 & 0xFFFF) | ((6 & 0xFFFF) << 16))
    nativeChatGui.Move(, , w, h)

    ; 译文框尺寸联动
    Native_UpdateTransDimensions(w, h, fontSz)
}

; -------------------------------------------------------------
; 译文框尺寸重排 (与原文框同规则)
; -------------------------------------------------------------
Native_UpdateTransDimensions(w, h, fontSz := 16) {
    global nativeTransGui, nativeTransEdit, nativeTransPrefix, nativeTransProgressBar
    if (!nativeTransGui || !nativeTransEdit)
        return

    if (nativeTransProgressBar)
        nativeTransProgressBar.Move(0, 0, 4, h)

    prefixH := 36
    prefixY := (h > prefixH) ? (h - prefixH) // 2 : 0
    if (nativeTransPrefix)
        nativeTransPrefix.Move(14, prefixY, 135, prefixH)

    editX := 150
    editW := w - editX - 15
    if (editW < 100)
        editW := 100
    editH := h - 14
    if (editH < 20)
        editH := 20
    editY := (h > editH) ? (h - editH) // 2 : 0

    nativeTransEdit.SetFont("s" fontSz " Bold cFFFFFF", "Microsoft YaHei")
    nativeTransEdit.Move(editX, editY, editW, editH)
    DllCall("SendMessage", "Ptr", nativeTransEdit.Hwnd, "UInt", 0x00D3, "Ptr", 3, "Ptr", (6 & 0xFFFF) | ((6 & 0xFFFF) << 16))
    nativeTransGui.Move(, , w, h)
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
    global nativeIsChatActive, nativeChatGui, nativeEditBox, nativePrefixText

    if nativeIsChatActive
        return

    nativeIsChatActive := true

    w := AppConfig.OverlayWidth > 0 ? AppConfig.OverlayWidth : 640
    h := AppConfig.OverlayHeight > 0 ? AppConfig.OverlayHeight : 58

    posX := 0, posY := 0
    Native_CalculateOverlayPos(AppConfig.OffsetX, AppConfig.OffsetY, w, h, &posX, &posY)

    WriteLog("[Gui.Native] 显示原生悬浮窗: x=" posX " y=" posY " w=" w " h=" h)

    Native_UpdateOverlayDimensions(w, h, AppConfig.FontSize)

    ; 动态刷新源语言前缀标签
    if (nativePrefixText)
        nativePrefixText.Value := "💬 [" GetLangTag(AppConfig.SourceLanguage) "]"

    nativeChatGui.Show(Format("x{1} y{2} w{3} h{4}", posX, posY, w, h))
    WinSetTransparent(248, "ahk_id " nativeChatGui.Hwnd)
    WinActivate("ahk_id " nativeChatGui.Hwnd)
    nativeEditBox.Value := ""
    nativeEditBox.Focus()
    Native_SetGuiLayoutToChinese()

    ; 开启翻译功能时同步显示译文框 (位于原文框正上方)
    if (AppConfig.EnableAutoTranslate) {
        Native_ShowTransGui(posX, posY, w, h)
    } else {
        Native_HideTransGui()
    }
}

; -------------------------------------------------------------
; 显示译文框 (位于原文框正上方 TRANS_OVERLAY_GAP 间距)
; -------------------------------------------------------------
Native_ShowTransGui(origX, origY, w, h) {
    global nativeTransGui, nativeTransEdit, nativeTransPrefix, nativeTransVisible, TRANS_OVERLAY_GAP
    if (!nativeTransGui)
        return

    transY := origY - h - TRANS_OVERLAY_GAP
    if (transY < 0)
        transY := 0

    ; 动态刷新目标语言前缀标签
    if (nativeTransPrefix)
        nativeTransPrefix.Value := "🌐 [" GetLangTag(AppConfig.TargetLanguage) "]"

    nativeTransEdit.Value := ""
    nativeTransGui.Show(Format("x{1} y{2} w{3} h{4} NA", origX, transY, w, h))
    WinSetTransparent(248, "ahk_id " nativeTransGui.Hwnd)
    nativeTransVisible := true
    WriteLog("[Gui.Native] 译文悬浮窗已显示: x=" origX " y=" transY)
}

Native_HideTransGui() {
    global nativeTransGui, nativeTransVisible
    nativeTransVisible := false
    if (nativeTransGui) {
        nativeTransGui.Move(-9999, -9999)
        nativeTransGui.Hide()
    }
}

; -------------------------------------------------------------
; 译文框读写
; -------------------------------------------------------------
Native_SetTransText(text) {
    global nativeTransEdit
    if (nativeTransEdit) {
        try nativeTransEdit.Value := text
    }
}

Native_GetTransText() {
    global nativeTransEdit
    return nativeTransEdit ? nativeTransEdit.Value : ""
}

Native_ClearTransText() {
    global nativeTransEdit
    if (nativeTransEdit)
        nativeTransEdit.Value := ""
}

Native_IsTransVisible() {
    global nativeTransVisible
    return nativeTransVisible
}

; -------------------------------------------------------------
; 注入源选中态视觉反馈: 选中框边条亮色, 未选中框边条变暗
; source = "original" | "translated"
; -------------------------------------------------------------
Native_HighlightSource(source) {
    global nativeProgressBar, nativeTransProgressBar, nativeTransVisible

    ; 原文框: 选中 #FFC800 / 未选中暗色 #6B5A1F
    if (nativeProgressBar) {
        try nativeProgressBar.Opt((source = "original") ? "+BackgroundFFC800" : "+Background6B5A1F")
    }
    ; 译文框: 选中 #4A9EFF / 未选中暗色 #24405C
    if (nativeTransProgressBar && nativeTransVisible) {
        try nativeTransProgressBar.Opt((source = "translated") ? "+Background4A9EFF" : "+Background24405C")
    }
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
    Native_HideTransGui()
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
    global nativeChatGui, nativeIsChatActive, nativeTransGui, nativeTransVisible
    if (nativeTransGui) {
        nativeTransGui.Destroy()
        nativeTransGui := ""
    }
    nativeTransVisible := false
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
