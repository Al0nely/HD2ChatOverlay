; lib/Injection.ahk - 文本注入与按键模拟

; -------------------------------------------------------------
; 动态分片注入: 根据文本长度自适应 chunkSize,减少总注入时间
; -------------------------------------------------------------
SendOptimizedText(rawText) {
    if (rawText = "")
        return

    len := StrLen(rawText)
    chunkSize := AppConfig.ChunkSize
    delayMs := AppConfig.ChunkDelay

    ; 动态调整: 短文本不分片,长文本增大分片减少 Sleep 次数
    if (len <= 8) {
        chunkSize := len
        delayMs := 0
    } else if (len <= 32) {
        chunkSize := 16
        delayMs := 3
    } else {
        chunkSize := 32
        delayMs := 2
    }

    WriteLog("[Injection] 文本长度=" len ", 动态分片=" chunkSize ", 延迟=" delayMs "ms")

    pos := 1
    while (pos <= len) {
        chunk := SubStr(rawText, pos, chunkSize)
        SendInput("{Text}" chunk)
        if (delayMs > 0)
            Sleep(delayMs)
        pos += chunkSize
    }
}

; -------------------------------------------------------------
; 修饰键清理
; -------------------------------------------------------------
ReleaseModifiers() {
    SendInput("{Alt Up}{Ctrl Up}{Shift Up}")
}

; -------------------------------------------------------------
; 提交文本到游戏
; -------------------------------------------------------------
SubmitText(*) {
    global isChatActive, editBox
    if !isChatActive
        return

    isChatActive := false
    rawText := editBox.Value
    editBox.Value := ""

    HideGuiToOffscreen()

    gameHwnd := GetGameHwnd()
    if gameHwnd {
        if (rawText != "") {
            ReleaseModifiers()
            sanitizedText := RegExReplace(rawText, "[\r\n]+", " ")
            SendOptimizedText(sanitizedText)
            Sleep(30)
            ReleaseModifiers()
            SendEvent("{Enter}")
            DisableGameIME()
        } else {
            ReleaseModifiers()
            SendEvent("{Enter}")
            DisableGameIME()
        }
    }
}

; -------------------------------------------------------------
; 关闭悬浮窗(可选发送 Esc)
; -------------------------------------------------------------
CloseGui(sendEsc := false) {
    global isChatActive, editBox
    if !isChatActive
        return
    isChatActive := false
    editBox.Value := ""

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
; 滚轮/翻页转发到游戏
; -------------------------------------------------------------
ForwardScrollToGame(direction) {
    gameHwnd := GetGameHwnd()
    if !gameHwnd
        return

    global chatGui
    MouseGetPos &mx, &my, &mHwnd
    if (mHwnd != chatGui.Hwnd) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " chatGui.Hwnd)
            mx := gx + (gw // 2)
            my := gy + (gh // 2)
        } catch {
        }
    }

    lParam := ((my & 0xFFFF) << 16) | (mx & 0xFFFF)
    wParam := (direction = "WheelUp") ? (120 << 16) : ((-120 << 16) & 0xFFFFFFFF)

    PostMessage(0x020A, wParam, lParam, , "ahk_id " gameHwnd)
}

; -------------------------------------------------------------
; 位置调整
; -------------------------------------------------------------
AdjustGuiPos(deltaX, deltaY) {
    global chatGui, isAdjusting, editBox

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
            ; 根据钳制后的实际位置反推 Offset,防止漂移
            AppConfig.OffsetX := X + W - posX
            AppConfig.OffsetY := Y + H - posY

            chatGui.Move(posX, posY)
        } catch TargetError {
        }
    }

    editBox.Focus()
    SetEditCaret()
    SetTimer(OnAdjustTimeout, -200)
}

OnAdjustTimeout() {
    global isAdjusting, chatGui

    isAdjusting := false
    AppConfig.Save()

    activeHwnd := WinActive("A")
    if (activeHwnd != chatGui.Hwnd) {
        CloseGui(false)
    }
}
