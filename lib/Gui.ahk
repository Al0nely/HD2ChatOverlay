; lib/Gui.ahk - 悬浮窗与配置窗口门面 (Facade)
; 根据 AppConfig.UseWebView2 路由到 WebView2 或原生控件实现

; -------------------------------------------------------------
; 全局状态
; -------------------------------------------------------------
global chatGui := ""          ; 原生模式 GUI 对象 (兼容旧代码)
global editBox := ""          ; 原生模式 Edit 对象 (兼容旧代码)
global isChatActive := false
global isAdjusting := false
global lastShowTime := 0
global isBoundToGame := false

; 当前使用的引擎实例
global g_overlayHost := ""    ; WebView2HostInstance 或 ""

; -------------------------------------------------------------
; 初始化悬浮窗
; -------------------------------------------------------------
InitChatGui() {
    global chatGui, editBox, g_overlayHost

    WriteLog("[Gui] InitChatGui 开始, UseWebView2=" AppConfig.UseWebView2)

    if (AppConfig.UseWebView2) {
        WriteLog("[Gui] 尝试初始化 WebView2...")
        if (WebView2Host.Init()) {
            WriteLog("[Gui] WebView2Host.Init 成功")
            g_overlayHost := WebView2Host.CreateOverlay()
            if (g_overlayHost) {
                g_overlayHost.OnMessage("submit", _OnOverlaySubmit)
                g_overlayHost.OnMessage("cancel", _OnOverlayCancel)
                g_overlayHost.OnMessage("ready", _OnOverlayReady)
                g_overlayHost.OnMessage("resize", _OnOverlayResize)
                WriteLog("[Gui] WebView2 悬浮窗已创建")
                return
            } else {
                WriteLog("[Gui] WebView2 悬浮窗创建失败,降级到原生模式")
                AppConfig.UseWebView2 := false
            }
        } else {
            WriteLog("[Gui] WebView2Host.Init 失败,降级到原生模式")
            AppConfig.UseWebView2 := false
        }
    }

    ; 原生模式
    WriteLog("[Gui] 使用原生模式")
    InitNativeChatGui()
    chatGui := nativeChatGui
    editBox := nativeEditBox
    WriteLog("[Gui] 原生悬浮窗已创建")
}

; -------------------------------------------------------------
; 显示悬浮窗
; -------------------------------------------------------------
ShowChatGui() {
    global isChatActive, lastShowTime, isBoundToGame, g_overlayHost, overlayInvokedWindow

    WriteLog("[Gui] ShowChatGui 被调用, isChatActive=" isChatActive ", g_overlayHost=" (g_overlayHost ? "存在" : "空"))

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

    if (g_overlayHost) {
        WriteLog("[Gui] 使用 WebView2 模式")
        ; WebView2 模式
        gameHwnd := GetGameHwnd()
        if gameHwnd {
            try {
                WinGetPos(&X, &Y, &W, &H, "ahk_id " gameHwnd)
                posX := X + W - AppConfig.OffsetX
                posY := Y + H - AppConfig.OffsetY
                LimitGuiPos(gameHwnd, &posX, &posY)

                if (!g_overlayHost.Hwnd) {
                    WriteLog("[Gui] WebView2 未启动,调用 Start()...")
                    if (!g_overlayHost.Start()) {
                        WriteLog("[Gui] WebView2 启动失败,降级到原生模式")
                        g_overlayHost := ""
                        AppConfig.UseWebView2 := false
                        isChatActive := false
                        InitNativeChatGui()
                        Native_ShowChatGui()
                        return
                    }
                    WriteLog("[Gui] WebView2 启动成功")
                }

                g_overlayHost.Move(posX, posY)
                g_overlayHost.Show()
                g_overlayHost.PostMessage('{"type":"focus"}')
                g_overlayHost.PostMessage('{"type":"setText","payload":""}')
                WriteLog("[Gui] WebView2 悬浮窗已显示")
            } catch TargetError {
                WriteLog("[Gui] 获取游戏窗口位置失败,使用默认位置")
                g_overlayHost.Show(100, 100)
            }
        } else {
            WriteLog("[Gui] 未找到游戏窗口,使用默认位置")
            if (!g_overlayHost.Hwnd) {
                if (!g_overlayHost.Start()) {
                    WriteLog("[Gui] WebView2 启动失败")
                    isChatActive := false
                    return
                }
            }
            g_overlayHost.Show(100, 100)
        }
    } else {
        WriteLog("[Gui] 使用原生模式")
        ; 原生模式
        Native_ShowChatGui()
    }
}

; -------------------------------------------------------------
; 隐藏悬浮窗到离屏
; -------------------------------------------------------------
HideGuiToOffscreen() {
    global g_overlayHost

    if (g_overlayHost) {
        g_overlayHost.Hide()
    } else {
        Native_HideGuiToOffscreen()
    }

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
    global g_overlayHost

    if (g_overlayHost) {
        ; WebView2 模式下,文本通过 submit 消息传递
        ; 此函数主要用于原生模式兼容
        return ""
    } else {
        return Native_GetText()
    }
}

; -------------------------------------------------------------
; 清空输入框
; -------------------------------------------------------------
ClearInput() {
    global g_overlayHost

    if (g_overlayHost) {
        g_overlayHost.PostMessage('{"type":"setText","payload":""}')
    } else {
        Native_ClearText()
    }
}

; -------------------------------------------------------------
; 设置焦点到输入框
; -------------------------------------------------------------
FocusInput() {
    global g_overlayHost

    if (g_overlayHost) {
        g_overlayHost.PostMessage('{"type":"focus"}')
    } else {
        Native_FocusEdit()
        Native_SetEditCaret()
    }
}

; -------------------------------------------------------------
; 检查悬浮窗是否激活
; -------------------------------------------------------------
GetIsChatActive() {
    global isChatActive, g_overlayHost

    if (g_overlayHost) {
        return isChatActive && g_overlayHost.IsReady
    } else {
        return Native_IsActive()
    }
}

; -------------------------------------------------------------
; 设置悬浮窗激活状态
; -------------------------------------------------------------
SetIsChatActive(state) {
    global isChatActive, g_overlayHost

    isChatActive := state

    if (!g_overlayHost) {
        Native_SetActive(state)
    }
}

; -------------------------------------------------------------
; 获取悬浮窗句柄
; -------------------------------------------------------------
GetChatGuiHwnd() {
    global g_overlayHost, chatGui

    if (g_overlayHost) {
        return g_overlayHost.Hwnd
    } else if (chatGui) {
        return chatGui.Hwnd
    }
    return 0
}

; -------------------------------------------------------------
; 获取输入框句柄 (仅原生模式)
; -------------------------------------------------------------
GetEditHwnd() {
    global g_overlayHost, editBox

    if (g_overlayHost) {
        return 0  ; WebView2 模式下无原生 Edit 句柄
    } else if (editBox) {
        return editBox.Hwnd
    }
    return 0
}

; -------------------------------------------------------------
; 重建悬浮窗 (应用新配置)
; -------------------------------------------------------------
RebuildChatGui() {
    global g_overlayHost, chatGui, editBox

    if (g_overlayHost) {
        g_overlayHost.Destroy()
        g_overlayHost := ""
        g_overlayHost := WebView2Host.CreateOverlay()
        if (g_overlayHost) {
            g_overlayHost.OnMessage("submit", _OnOverlaySubmit)
            g_overlayHost.OnMessage("cancel", _OnOverlayCancel)
            g_overlayHost.OnMessage("ready", _OnOverlayReady)
            g_overlayHost.OnMessage("resize", _OnOverlayResize)
        }
    } else {
        Native_RebuildChatGui()
        chatGui := nativeChatGui
        editBox := nativeEditBox
    }

    WriteLog("[Gui] 悬浮窗已重建,字体: " AppConfig.FontName)
}

; -------------------------------------------------------------
; 销毁悬浮窗
; -------------------------------------------------------------
DestroyChatGui() {
    global g_overlayHost, chatGui

    if (g_overlayHost) {
        g_overlayHost.Destroy()
        g_overlayHost := ""
    } else {
        Native_DestroyChatGui()
        chatGui := ""
    }
}

; -------------------------------------------------------------
; 显示配置窗口
; -------------------------------------------------------------
ShowConfigGui() {
    if (AppConfig.UseWebView2 && WebView2Host.IsAvailable) {
        configHost := WebView2Host.CreateConfigWindow()
        if (configHost) {
            configHost.OnMessage("saveConfig", _OnConfigSave)
            configHost.OnMessage("cancel", _OnConfigCancel)
            configHost.OnMessage("preview", _OnConfigPreview)
            configHost.OnMessage("getConfig", _OnConfigGet)
            configHost.OnMessage("resetConfig", _OnConfigReset)
            configHost.Start()
            configHost.Show()
            return
        }
    }

    ; 原生模式
    Native_ShowConfigGui()
}

; -------------------------------------------------------------
; WebView2 消息回调
; -------------------------------------------------------------
_OnOverlaySubmit(payload) {
    global isChatActive
    isChatActive := false

    ; payload 是 JSON 字符串,提取 text
    text := ""
    if (RegExMatch(payload, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &match)) {
        text := StrReplace(match[1], '\"', '"')
        text := StrReplace(text, '\\', '\')
        text := StrReplace(text, '\n', '`n')
        text := StrReplace(text, '\r', '`r')
    }

    HideGuiToOffscreen()

    gameHwnd := GetGameHwnd()
    if gameHwnd && (text != "") {
        ReleaseModifiers()
        sanitizedText := RegExReplace(text, "[\r\n]+", " ")
        SendOptimizedText(sanitizedText)
        Sleep(30)
        ReleaseModifiers()
        SendEvent("{Enter}")
        DisableGameIME()
    } else if gameHwnd {
        ReleaseModifiers()
        SendEvent("{Enter}")
        DisableGameIME()
    }
}

_OnOverlayCancel(payload) {
    CloseGui(true)
}

_OnOverlayReady(payload) {
    global g_overlayHost
    WriteLog("[Gui] WebView2 悬浮窗就绪")

    ; 同步当前字体配置
    if (g_overlayHost) {
        g_overlayHost.PostMessage('{"type":"setFont","payload":{"family":"' AppConfig.FontName '","size":' AppConfig.FontSize '}}')
    }
}

_OnOverlayResize(payload) {
    global g_overlayHost
    if (!g_overlayHost)
        return

    height := 0
    if (RegExMatch(payload, '"height"\s*:\s*(\d+)', &m))
        height := Integer(m[1])

    if (height > 0) {
        ; 仅按高度调整窗口尺寸 (保持固定宽度 510px, 防止宽度循环累加展开)
        newH := Max(48, height + 16)
        g_overlayHost.Resize(510, newH)
    }
}

_OnConfigGet(payload) {
    ; 发送当前配置到配置窗口
    configJson := '{'
    configJson .= '"OffsetX":' AppConfig.OffsetX ','
    configJson .= '"OffsetY":' AppConfig.OffsetY ','
    configJson .= '"ChunkSize":' AppConfig.ChunkSize ','
    configJson .= '"ChunkDelay":' AppConfig.ChunkDelay ','
    configJson .= '"FontName":"' AppConfig.FontName '",'
    configJson .= '"FontSize":' AppConfig.FontSize ','
    configJson .= '"EnableDebugLog":' (AppConfig.EnableDebugLog ? 1 : 0) ','
    configJson .= '"GlobalTestMode":' (AppConfig.GlobalTestMode ? 1 : 0) ','
    configJson .= '"UseWebView2":"' (AppConfig.UseWebView2 ? "webview2" : "native") '"'
    configJson .= '}'

    configHost := WebView2Host.GetConfigWindow()
    if (configHost)
        configHost.PostMessage('{"type":"config","payload":' configJson '}')
}

_OnConfigReset(payload) {
    AppConfig.ResetDefaults()
    _OnConfigGet("")  ; 重新发送默认配置
    TrayTip("配置已重置", "所有设置已恢复默认值", 1)
}

_OnConfigSave(payload) {
    WriteLog("[Gui] 配置保存: " payload)

    ; 解析 JSON 配置
    if (RegExMatch(payload, '"OffsetX"\s*:\s*(\d+)', &m))
        AppConfig.OffsetX := Integer(m[1])
    if (RegExMatch(payload, '"OffsetY"\s*:\s*(\d+)', &m))
        AppConfig.OffsetY := Integer(m[1])
    if (RegExMatch(payload, '"ChunkSize"\s*:\s*(\d+)', &m))
        AppConfig.ChunkSize := Integer(m[1])
    if (RegExMatch(payload, '"ChunkDelay"\s*:\s*(\d+)', &m))
        AppConfig.ChunkDelay := Integer(m[1])
    if (RegExMatch(payload, '"FontName"\s*:\s*"([^"]+)"', &m))
        AppConfig.FontName := m[1]
    if (RegExMatch(payload, '"FontSize"\s*:\s*(\d+)', &m))
        AppConfig.FontSize := Integer(m[1])
    if (RegExMatch(payload, '"EnableDebugLog"\s*:\s*(\d+)', &m))
        AppConfig.EnableDebugLog := m[1] = "1"
    if (RegExMatch(payload, '"GlobalTestMode"\s*:\s*(\d+)', &m))
        AppConfig.GlobalTestMode := m[1] = "1"
    if (RegExMatch(payload, '"UseWebView2"\s*:\s*(\d+)', &m)) {
        newEngine := m[1] = "1"
        if (newEngine != AppConfig.UseWebView2) {
            AppConfig.UseWebView2 := newEngine
            AppConfig.Save()
            TrayTip("引擎已切换", "已切换到 " (newEngine ? "WebView2" : "原生控件") ",脚本将重启", 1)
            Sleep(1500)
            Reload()
            return
        }
    }

    AppConfig.Save()
    RebuildChatGui()

    ; 通知前端保存成功
    configHost := WebView2Host.GetConfigWindow()
    if (configHost)
        configHost.PostMessage('{"type":"configSaved"}')
}

_OnConfigCancel(payload) {
    configHost := WebView2Host.GetConfigWindow()
    if (configHost)
        configHost.Hide()
}

_OnConfigPreview(payload) {
    WriteLog("[Gui] 配置预览: " payload)

    ; 提取预览字段并应用到悬浮窗
    fontName := ""
    fontSize := 0
    offsetX := 0
    offsetY := 0

    if (RegExMatch(payload, '"FontName"\s*:\s*"([^"]+)"', &m))
        fontName := m[1]
    if (RegExMatch(payload, '"FontSize"\s*:\s*(\d+)', &m))
        fontSize := Integer(m[1])
    if (RegExMatch(payload, '"OffsetX"\s*:\s*(\d+)', &m))
        offsetX := Integer(m[1])
    if (RegExMatch(payload, '"OffsetY"\s*:\s*(\d+)', &m))
        offsetY := Integer(m[1])

    ; 应用字体预览
    if (fontName != "" && fontSize > 0) {
        if (g_overlayHost) {
            g_overlayHost.PostMessage('{"type":"setFont","payload":{"family":"' fontName '","size":' fontSize '}}')
        }
    }

    ; 应用位置预览
    if (offsetX > 0 && offsetY > 0) {
        gameHwnd := GetGameHwnd()
        if gameHwnd {
            try {
                WinGetPos(&X, &Y, &W, &H, "ahk_id " gameHwnd)
                posX := X + W - offsetX
                posY := Y + H - offsetY
                LimitGuiPos(gameHwnd, &posX, &posY)

                if (g_overlayHost) {
                    g_overlayHost.Move(posX, posY)
                } else if (nativeChatGui) {
                    nativeChatGui.Move(posX, posY)
                }
            }
        }
    }
}



; -------------------------------------------------------------
; 位置调整
; -------------------------------------------------------------
AdjustGuiPos(deltaX, deltaY) {
    global isAdjusting, g_overlayHost

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

            if (g_overlayHost) {
                g_overlayHost.Move(posX, posY)
            } else {
                nativeChatGui.Move(posX, posY)
            }
        } catch TargetError {
        }
    }

    FocusInput()
    SetTimer(OnAdjustTimeout, -200)
}

OnAdjustTimeout() {
    global isAdjusting, g_overlayHost, chatGui

    isAdjusting := false
    AppConfig.Save()

    activeHwnd := WinActive("A")
    guiHwnd := g_overlayHost ? g_overlayHost.Hwnd : (chatGui ? chatGui.Hwnd : 0)
    if (activeHwnd != guiHwnd) {
        CloseGui(false)
    }
}
