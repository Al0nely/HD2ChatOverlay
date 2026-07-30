; lib/Injection.ahk - 文本注入与按键模拟

; -------------------------------------------------------------
; 动态分片注入: 根据文本长度自适应 chunkSize,减少总注入时间
; -------------------------------------------------------------
SendOptimizedText(rawText) {
    if (rawText = "")
        return

    len := StrLen(rawText)
    delayMs := AppConfig.ChunkDelay > 0 ? AppConfig.ChunkDelay : 15
    WriteLog("[Injection] 逐字帧同步 Unicode 注入: 长度=" len ", 字间延迟=" delayMs "ms")

    ; 放弃剪贴板粘贴, 采用 100% 兼容的逐字帧间隔发送
    Loop parse, rawText {
        SendInput("{Text}" A_LoopField)
        if (delayMs > 0)
            Sleep(delayMs)
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
SubmitText(forceTranslate := false) {
    global isChatActive
    if !isChatActive
        return

    rawText := Native_GetText()

    ; 判断是否触发 AI 翻译 (强制触发 或 开启了自动翻译)
    shouldTranslate := (forceTranslate || AppConfig.EnableAutoTranslate) && (rawText != "")

    if (shouldTranslate) {
        Native_SetPrefixText("💬 [翻译中...]")
        res := OpenRouterClient.TranslateText(rawText, AppConfig.TargetLanguage, AppConfig.ApiBase, AppConfig.ApiKey, AppConfig.Model)
        Native_SetPrefixText("💬 [中]")
        if (res.success && res.text != "") {
            rawText := res.text
            WriteLog("[Translation] 译文结果: " rawText)
        } else {
            WriteLog("[Translation] 翻译失败/保留原文: " res.error)
            TrayTip("AI 翻译失败", res.error " (将发送原文)", 2)
        }
    }

    isChatActive := false
    Native_ClearText()

    HideGuiToOffscreen()

    gameHwnd := GetGameHwnd()
    targetHwnd := 0
    if (gameHwnd && WinActive("ahk_id " gameHwnd)) {
        targetHwnd := gameHwnd
    } else {
        global overlayInvokedWindow
        if (overlayInvokedWindow && WinExist("ahk_id " overlayInvokedWindow)) {
            targetHwnd := overlayInvokedWindow
        } else if (gameHwnd && WinExist("ahk_id " gameHwnd)) {
            targetHwnd := gameHwnd
        }
    }

    if (targetHwnd && WinExist("ahk_id " targetHwnd)) {
        try WinActivate("ahk_id " targetHwnd)
        if (rawText != "") {
            ReleaseModifiers()

            ; 关键: 注入前关闭目标的中文 IME 候选框, 防止游戏内输入法误把 Unicode 当作拼音检索候选词
            try IME_SET(0, "ahk_id " targetHwnd)
            SetCapsLockSafe("Off")

            sanitizedText := RegExReplace(rawText, "[\r\n]+", " ")
            SendOptimizedText(sanitizedText)
            Sleep(50)
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
; 滚轮/翻页转发到游戏
; -------------------------------------------------------------
ForwardScrollToGame(direction) {
    gameHwnd := GetGameHwnd()
    if !gameHwnd
        return

    guiHwnd := GetChatGuiHwnd()
    MouseGetPos &mx, &my, &mHwnd
    if (mHwnd != guiHwnd) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " guiHwnd)
            mx := gx + (gw // 2)
            my := gy + (gh // 2)
        } catch {
        }
    }

    lParam := ((my & 0xFFFF) << 16) | (mx & 0xFFFF)
    wParam := (direction = "WheelUp") ? (120 << 16) : ((-120 << 16) & 0xFFFFFFFF)

    PostMessage(0x020A, wParam, lParam, , "ahk_id " gameHwnd)
}
