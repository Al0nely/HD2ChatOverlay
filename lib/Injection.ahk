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
; 翻译当前原文框文本 (Alt+T 触发): 原文保留, 译文显示在译文框
; -------------------------------------------------------------
TranslateCurrentText(*) {
    global isChatActive, g_injectSource
    if !isChatActive
        return

    rawText := Native_GetText()
    if (rawText = "") {
        TrayTip("AI 翻译", "原文框为空, 请先输入文本", 1)
        return
    }

    ; AC 自动机预扫描当句术语
    glossaryHint := ""
    if (AppConfig.EnableGlossary && Glossary.isLoaded) {
        hits := Glossary.ScanText(rawText)
        if (hits.Length > 0) {
            glossaryHint := Glossary.FormatForPrompt(hits)
            WriteLog("[Translation] 术语命中 " hits.Length " 个, 扫描耗时 " Glossary.lastScanMs "ms")
        }
    }

    Native_SetPrefixText("💬 [翻译中]")
    res := OpenRouterClient.TranslateText(rawText, AppConfig.TargetLanguage, AppConfig.SourceLanguage, AppConfig.ApiBase, AppConfig.ApiKey, AppConfig.Model, glossaryHint)
    Native_SetPrefixText("")

    if (res.success && res.text != "") {
        Native_SetTransText(res.text)
        WriteLog("[Translation] 译文结果: " res.text)
        ; 翻译成功后默认选中译文框
        SetInjectSource("translated")
    } else {
        WriteLog("[Translation] 翻译失败: " res.error)
        TrayTip("AI 翻译失败", res.error, 2)
        ; 失败保持选中原文框
        SetInjectSource("original")
    }

    ; 焦点回到原文输入框, 保持输入流畅
    FocusInput()
}

; -------------------------------------------------------------
; 提交文本到游戏 (按当前选中框注入)
; -------------------------------------------------------------
SubmitText(*) {
    global isChatActive, g_injectSource
    if !isChatActive
        return

    ; 按注入源取文本: 译文框为空时强制回退原文框
    rawText := ""
    if (g_injectSource = "translated" && Native_IsTransVisible()) {
        rawText := Native_GetTransText()
        if (rawText = "") {
            g_injectSource := "original"
            rawText := Native_GetText()
        }
    } else {
        rawText := Native_GetText()
    }

    isChatActive := false
    Native_ClearText()
    Native_ClearTransText()

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
