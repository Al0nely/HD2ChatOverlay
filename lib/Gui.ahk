; lib/Gui.ahk - 悬浮窗与配置窗口管理

; -------------------------------------------------------------
; 悬浮窗 (聊天输入框) - 离屏驻留架构
; -------------------------------------------------------------
global chatGui := ""
global editBox := ""
global isChatActive := false
global isAdjusting := false
global lastShowTime := 0
global isBoundToGame := false

InitChatGui() {
    global chatGui, editBox

    chatGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    chatGui.BackColor := "111317"
    chatGui.MarginX := 15
    chatGui.MarginY := 10
    chatGui.SetFont("s" AppConfig.FontSize " Bold cFFFFFF", AppConfig.FontName)

    ; -E0x0200 抹除 Win32 Edit 默认 3D 白边
    editBox := chatGui.AddEdit("w480 -Border -E0x0200 Background111317 cFFFFFF")

    ; 修改 Win32 窗口类背景刷子为暗色
    hDarkBrush := DllCall("CreateSolidBrush", "UInt", 0x00171311, "Ptr")
    DllCall("SetClassLongPtr", "Ptr", chatGui.Hwnd, "Int", -10, "Ptr", hDarkBrush)

    ; 禁用 DWM 窗口过渡动画
    dwmDisableAnim := Buffer(4, 0)
    NumPut("Int", 1, dwmDisableAnim)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", chatGui.Hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

    ; 离屏驻留
    chatGui.Show("x-9999 y-9999 w510 h48 NA")

    ; 注册 WM_CHAR 拦截 (Zero-CapsLock Toggle)
    OnMessage(0x0102, WM_CHAR_Callback)
    OnMessage(0x0201, WM_LBUTTONDOWN)
}

WM_CHAR_Callback(wParam, lParam, msg, hwnd) {
    global editBox, isChatActive
    if (isChatActive && hwnd == editBox.Hwnd) {
        if (wParam >= 65 && wParam <= 90) {
            if GetKeyState("Shift", "P")
                return
            lowerWParam := wParam + 32
            DllCall("PostMessage", "Ptr", editBox.Hwnd, "UInt", 0x0102, "Ptr", lowerWParam, "Ptr", lParam)
            return 0
        }
    }
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global chatGui, editBox
    if (hwnd == chatGui.Hwnd) {
        editBox.Focus()
        SetEditCaret()
    }
}

SetEditCaret() {
    global editBox
    try {
        DllCall("CreateCaret", "Ptr", editBox.Hwnd, "Ptr", 0, "Int", 2, "Int", 22)
        DllCall("ShowCaret", "Ptr", editBox.Hwnd)
    }
}

ShowChatGui() {
    global isChatActive, chatGui, editBox, lastShowTime, isBoundToGame

    if (isChatActive || (A_TickCount - lastShowTime < 200))
        return

    isChatActive := true
    lastShowTime := A_TickCount

    gameHwnd := GetGameHwnd()
    if gameHwnd {
        try {
            if (!isBoundToGame || DllCall("GetWindow", "Ptr", chatGui.Hwnd, "UInt", 4, "Ptr") != gameHwnd) {
                DllCall("SetWindowLongPtr", "Ptr", chatGui.Hwnd, "Int", -8, "Ptr", gameHwnd)
                isBoundToGame := true
            }

            WinGetPos(&X, &Y, &W, &H, "ahk_id " gameHwnd)
            posX := X + W - AppConfig.OffsetX
            posY := Y + H - AppConfig.OffsetY
            LimitGuiPos(gameHwnd, &posX, &posY)

            chatGui.Move(posX, posY)
        } catch TargetError {
            chatGui.Move(100, 100)
        }
    } else {
        chatGui.Move(100, 100)
    }

    chatGui.Show()
    editBox.Value := ""
    editBox.Focus()
    SetEditCaret()
    SetGuiLayoutToChinese()
}

SetGuiLayoutToChinese() {
    global chatGui
    try {
        IME_SET(1, "ahk_id " chatGui.Hwnd)
    } catch Error as err {
        WriteLog("[SetGuiLayoutToChinese] 异常: " err.Message)
    }
}

HideGuiToOffscreen() {
    global chatGui
    chatGui.Move(-9999, -9999)
    chatGui.Hide()
    gameHwnd := GetGameHwnd()
    if gameHwnd {
        try WinActivate("ahk_id " gameHwnd)
    }
}

; -------------------------------------------------------------
; 配置窗口
; -------------------------------------------------------------
global configGui := ""

ShowConfigGui() {
    global configGui

    if (configGui) {
        configGui.Show()
        return
    }

    configGui := Gui("+AlwaysOnTop +ToolWindow", "HD2 Chat Overlay - 配置")
    configGui.BackColor := "1E1E1E"
    configGui.SetFont("s10 cFFFFFF", "Segoe UI")
    configGui.MarginX := 20
    configGui.MarginY := 15

    ; 坐标配置
    configGui.AddText("w200", "窗口位置偏移 (基于游戏右下角):")
    configGui.AddText("w80 xm+20", "OffsetX:")
    editOffsetX := configGui.AddEdit("x+10 w100 Number", AppConfig.OffsetX)
    configGui.AddText("xm+20 w80", "OffsetY:")
    editOffsetY := configGui.AddEdit("x+10 w100 Number", AppConfig.OffsetY)

    ; 注入配置
    configGui.AddText("xm w200", "文本注入参数:")
    configGui.AddText("xm+20 w80", "分片大小:")
    editChunkSize := configGui.AddEdit("x+10 w100 Number", AppConfig.ChunkSize)
    configGui.AddText("xm+20 w80", "分片延迟(ms):")
    editChunkDelay := configGui.AddEdit("x+10 w100 Number", AppConfig.ChunkDelay)

    ; 字体配置
    configGui.AddText("xm w200", "悬浮窗字体:")
    configGui.AddText("xm+20 w80", "字体名称:")
    ddlFont := configGui.AddDropDownList("x+10 w150 Choose" _GetFontIndex(AppConfig.FontName), ["SimHei", "Microsoft YaHei UI", "Segoe UI", "NSimSun", "Consolas"])
    configGui.AddText("xm+20 w80", "字体大小:")
    editFontSize := configGui.AddEdit("x+10 w100 Number", AppConfig.FontSize)

    ; 调试配置
    chkDebugLog := configGui.AddCheckbox("xm w200 Checked" (AppConfig.EnableDebugLog ? 1 : 0), "启用调试日志")

    ; 按钮
    btnSave := configGui.AddButton("xm+20 w100 h30", "保存")
    btnCancel := configGui.AddButton("x+20 w100 h30", "取消")
    btnReset := configGui.AddButton("x+20 w120 h30", "恢复默认")

    ; 事件绑定
    btnSave.OnEvent("Click", _SaveConfig.Bind(editOffsetX, editOffsetY, editChunkSize, editChunkDelay, ddlFont, editFontSize, chkDebugLog))
    btnCancel.OnEvent("Click", _CloseConfig)
    btnReset.OnEvent("Click", _ResetConfig.Bind(editOffsetX, editOffsetY, editChunkSize, editChunkDelay, ddlFont, editFontSize, chkDebugLog))
    configGui.OnEvent("Close", _CloseConfig)

    configGui.Show("w420 h420")
}

_GetFontIndex(fontName) {
    fonts := ["SimHei", "Microsoft YaHei UI", "Segoe UI", "NSimSun", "Consolas"]
    for i, f in fonts {
        if (f = fontName)
            return i
    }
    return 1
}

_SaveConfig(editOffsetX, editOffsetY, editChunkSize, editChunkDelay, ddlFont, editFontSize, chkDebugLog, *) {
    global configGui

    AppConfig.OffsetX := Integer(editOffsetX.Value)
    AppConfig.OffsetY := Integer(editOffsetY.Value)
    AppConfig.ChunkSize := Integer(editChunkSize.Value)
    AppConfig.ChunkDelay := Integer(editChunkDelay.Value)
    AppConfig.FontName := ddlFont.Text
    AppConfig.FontSize := Integer(editFontSize.Value)
    AppConfig.EnableDebugLog := chkDebugLog.Value

    AppConfig.Save()
    WriteLog("[Config] 配置已保存")

    ; 重建悬浮窗以应用新字体
    RebuildChatGui()

    configGui.Hide()
}

_CloseConfig(*) {
    global configGui
    configGui.Hide()
}

_ResetConfig(editOffsetX, editOffsetY, editChunkSize, editChunkDelay, ddlFont, editFontSize, chkDebugLog, *) {
    AppConfig.ResetDefaults()
    editOffsetX.Value := AppConfig.OffsetX
    editOffsetY.Value := AppConfig.OffsetY
    editChunkSize.Value := AppConfig.ChunkSize
    editChunkDelay.Value := AppConfig.ChunkDelay
    ddlFont.Value := _GetFontIndex(AppConfig.FontName)
    editFontSize.Value := AppConfig.FontSize
    chkDebugLog.Value := AppConfig.EnableDebugLog
}

RebuildChatGui() {
    global chatGui, editBox
    if (chatGui) {
        chatGui.Destroy()
    }
    InitChatGui()
    WriteLog("[Gui] 悬浮窗已重建,应用新字体: " AppConfig.FontName)
}
