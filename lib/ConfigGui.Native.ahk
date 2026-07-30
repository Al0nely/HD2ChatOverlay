; lib/ConfigGui.Native.ahk - 原生 AHK 配置窗口与实时预览机制

global nativeConfigGui := ""
global g_cfgEditOffsetX := ""
global g_cfgEditOffsetY := ""
global g_cfgEditWidth := ""
global g_cfgEditHeight := ""
global g_cfgEditFontSize := ""
global g_cfgEditChunkDelay := ""
global g_cfgChkDebugLog := ""

global g_cfgChkAutoTranslate := ""
global g_cfgEditApiBase := ""
global g_cfgEditApiKey := ""
global g_cfgCbbModel := ""
global g_cfgDdlTargetLang := ""

Native_ShowConfigGui() {
    global nativeConfigGui, isChatActive, nativeIsChatActive, nativeEditBox
    global g_cfgEditOffsetX, g_cfgEditOffsetY, g_cfgEditWidth, g_cfgEditHeight, g_cfgEditFontSize, g_cfgEditChunkDelay, g_cfgChkDebugLog
    global g_cfgChkAutoTranslate, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel, g_cfgDdlTargetLang

    ; 先将激活状态归零，确保 Native_ShowChatGui() 能正常弹窗展示
    isChatActive := false
    nativeIsChatActive := false
    Native_ShowChatGui()
    if (nativeEditBox) {
        nativeEditBox.Value := "【预览】实时调整位置与尺寸"
    }

    if (nativeConfigGui) {
        if (g_cfgEditOffsetX) {
            g_cfgEditOffsetX.Value := AppConfig.OffsetX
            g_cfgEditOffsetY.Value := AppConfig.OffsetY
            g_cfgEditWidth.Value := AppConfig.OverlayWidth
            g_cfgEditHeight.Value := AppConfig.OverlayHeight
            g_cfgEditFontSize.Value := AppConfig.FontSize
            g_cfgEditChunkDelay.Value := AppConfig.ChunkDelay
            g_cfgChkDebugLog.Value := AppConfig.EnableDebugLog
            g_cfgChkAutoTranslate.Value := AppConfig.EnableAutoTranslate
            g_cfgEditApiBase.Value := AppConfig.ApiBase
            g_cfgEditApiKey.Value := AppConfig.ApiKey
            g_cfgCbbModel.Text := AppConfig.Model
            g_cfgDdlTargetLang.Text := AppConfig.TargetLanguage
            _Native_UpdatePreview()
        }
        nativeConfigGui.Show()
        return
    }

    nativeConfigGui := Gui("+AlwaysOnTop +ToolWindow", "HD2 Chat Overlay - 悬浮窗配置与对齐")
    nativeConfigGui.BackColor := "1E1E1E"
    nativeConfigGui.SetFont("s10 cFFFFFF", "Microsoft YaHei UI")
    nativeConfigGui.MarginX := 20
    nativeConfigGui.MarginY := 15

    ; 1. 窗口位置配置 (基于右下角 OffsetX / OffsetY)
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("w440", "1. 悬浮窗位置偏移 (基于游戏右下角对齐)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    nativeConfigGui.AddText("xm+15 w90", "OffsetX (X轴):")
    g_cfgEditOffsetX := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.OffsetX)
    udOffsetX := nativeConfigGui.AddUpDown("Range-2000-4000", AppConfig.OffsetX)

    nativeConfigGui.AddText("x+15 w90", "OffsetY (Y轴):")
    g_cfgEditOffsetY := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.OffsetY)
    udOffsetY := nativeConfigGui.AddUpDown("Range-2000-4000", AppConfig.OffsetY)

    ; 快捷方向按钮组
    btnUp := nativeConfigGui.AddButton("xm+100 w55 h26", "▲ 上")
    btnDown := nativeConfigGui.AddButton("x+10 w55 h26", "▼ 下")
    btnLeft := nativeConfigGui.AddButton("x+10 w55 h26", "◄ 左")
    btnRight := nativeConfigGui.AddButton("x+10 w55 h26", "► 右")

    ; 2. 框体大小与尺寸配置
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w440", "2. 悬浮窗框体尺寸与字体")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    nativeConfigGui.AddText("xm+15 w90", "宽度 (Width):")
    g_cfgEditWidth := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.OverlayWidth)
    udWidth := nativeConfigGui.AddUpDown("Range300-1200", AppConfig.OverlayWidth)

    nativeConfigGui.AddText("x+15 w90", "高度 (Height):")
    g_cfgEditHeight := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.OverlayHeight)
    udHeight := nativeConfigGui.AddUpDown("Range30-150", AppConfig.OverlayHeight)

    nativeConfigGui.AddText("xm+15 w90", "字体大小:")
    g_cfgEditFontSize := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.FontSize)
    udFontSize := nativeConfigGui.AddUpDown("Range10-36", AppConfig.FontSize)

    nativeConfigGui.AddText("x+15 w90", "字间延迟(ms):")
    g_cfgEditChunkDelay := nativeConfigGui.AddEdit("x+5 w70 Number", AppConfig.ChunkDelay)
    udChunkDelay := nativeConfigGui.AddUpDown("Range1-100", AppConfig.ChunkDelay)

    ; 3. AI 翻译设置 (OpenRouter / OpenAI 格式)
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w440", "3. 🤖 AI 翻译设置 (OpenRouter / OpenAI 格式)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    g_cfgChkAutoTranslate := nativeConfigGui.AddCheckbox("xm+15 w410 Checked" (AppConfig.EnableAutoTranslate ? 1 : 0), "开启 Enter 自动翻译 (按 Ctrl+Enter 随时强制翻译)")

    nativeConfigGui.AddText("xm+15 w90", "API Base:")
    g_cfgEditApiBase := nativeConfigGui.AddEdit("x+5 w310", AppConfig.ApiBase)

    nativeConfigGui.AddText("xm+15 w90", "API Key:")
    g_cfgEditApiKey := nativeConfigGui.AddEdit("x+5 w310 Password*", AppConfig.ApiKey)

    btnFetchModels := nativeConfigGui.AddButton("xm+15 w130 h26", "🔄 拉取模型列表")
    nativeConfigGui.AddText("x+15 w70", "目标语言:")
    
    langList := ["English", "Chinese", "Japanese", "German", "French", "Spanish", "Russian"]
    g_cfgDdlTargetLang := nativeConfigGui.AddDropDownList("x+5 w100", langList)
    g_cfgDdlTargetLang.Text := AppConfig.TargetLanguage

    nativeConfigGui.AddText("xm+15 w90", "模型选择:")
    presetModels := ["google/gemini-2.5-flash", "deepseek/deepseek-chat", "openai/gpt-4o-mini", "qwen/qwen-2.5-72b-instruct"]
    g_cfgCbbModel := nativeConfigGui.AddComboBox("x+5 w310", presetModels)
    g_cfgCbbModel.Text := AppConfig.Model

    ; 4. 调试配置
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w440", "4. 系统服务")
    nativeConfigGui.SetFont("s10 cFFFFFF")
    g_cfgChkDebugLog := nativeConfigGui.AddCheckbox("xm+15 w300 Checked" (AppConfig.EnableDebugLog ? 1 : 0), "启用调试日志")

    ; 底部控制按钮
    btnSave := nativeConfigGui.AddButton("xm+30 w100 h32", "保存配置")
    btnCancel := nativeConfigGui.AddButton("x+20 w100 h32", "取消")
    btnReset := nativeConfigGui.AddButton("x+20 w110 h32", "恢复默认")

    ; 绑定控件 Live Change 事件
    g_cfgEditOffsetX.OnEvent("Change", (*) => _Native_UpdatePreview())
    g_cfgEditOffsetY.OnEvent("Change", (*) => _Native_UpdatePreview())
    g_cfgEditWidth.OnEvent("Change", (*) => _Native_UpdatePreview())
    g_cfgEditHeight.OnEvent("Change", (*) => _Native_UpdatePreview())
    g_cfgEditFontSize.OnEvent("Change", (*) => _Native_UpdatePreview())

    ; 绑定快捷方向按钮
    btnUp.OnEvent("Click", (*) => (g_cfgEditOffsetY.Value := Integer(g_cfgEditOffsetY.Value) + 5, _Native_UpdatePreview()))
    btnDown.OnEvent("Click", (*) => (g_cfgEditOffsetY.Value := Integer(g_cfgEditOffsetY.Value) - 5, _Native_UpdatePreview()))
    btnLeft.OnEvent("Click", (*) => (g_cfgEditOffsetX.Value := Integer(g_cfgEditOffsetX.Value) + 5, _Native_UpdatePreview()))
    btnRight.OnEvent("Click", (*) => (g_cfgEditOffsetX.Value := Integer(g_cfgEditOffsetX.Value) - 5, _Native_UpdatePreview()))

    ; 拉取模型按钮
    btnFetchModels.OnEvent("Click", _Native_FetchModelList)

    ; 保存按钮
    btnSave.OnEvent("Click", _Native_SaveConfig)
    btnCancel.OnEvent("Click", _Native_CloseConfig)
    btnReset.OnEvent("Click", _Native_ResetConfig)
    nativeConfigGui.OnEvent("Close", _Native_CloseConfig)

    ; 初始化位置刷新
    _Native_UpdatePreview()
    nativeConfigGui.Show("w470 h580")
}

_Native_FetchModelList(*) {
    global g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel

    apiBase := g_cfgEditApiBase.Value
    apiKey := g_cfgEditApiKey.Value

    TrayTip("正在请求", "正在从中转平台拉取模型列表...", 1)
    res := OpenRouterClient.FetchModelList(apiBase, apiKey)

    if (res.success) {
        currentModel := g_cfgCbbModel.Text
        g_cfgCbbModel.Delete()
        g_cfgCbbModel.Add(res.models)
        g_cfgCbbModel.Text := (currentModel != "") ? currentModel : res.models[1]
        TrayTip("拉取成功", "已成功拉取 " res.models.Length " 个可用模型！", 1)
    } else {
        MsgBox("拉取模型列表失败:`n" res.error, "HD2 Chat Overlay", "Icon!")
    }
}

_Native_UpdatePreview() {
    global nativeChatGui, g_cfgEditOffsetX, g_cfgEditOffsetY, g_cfgEditWidth, g_cfgEditHeight, g_cfgEditFontSize
    if (!g_cfgEditOffsetX || !nativeChatGui)
        return

    try {
        offX := Integer(g_cfgEditOffsetX.Value)
        offY := Integer(g_cfgEditOffsetY.Value)
        w := Integer(g_cfgEditWidth.Value)
        h := Integer(g_cfgEditHeight.Value)
        fSz := Integer(g_cfgEditFontSize.Value)

        posX := 0, posY := 0
        Native_CalculateOverlayPos(offX, offY, w, h, &posX, &posY)

        Native_UpdateOverlayDimensions(w, h, fSz)
        nativeChatGui.Show(Format("x{1} y{2} w{3} h{4} NA", posX, posY, w, h))
    } catch {
    }
}

_Native_SaveConfig(*) {
    global nativeConfigGui, g_cfgEditOffsetX, g_cfgEditOffsetY, g_cfgEditWidth, g_cfgEditHeight, g_cfgEditFontSize, g_cfgEditChunkDelay, g_cfgChkDebugLog
    global g_cfgChkAutoTranslate, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel, g_cfgDdlTargetLang

    AppConfig.OffsetX := Integer(g_cfgEditOffsetX.Value)
    AppConfig.OffsetY := Integer(g_cfgEditOffsetY.Value)
    AppConfig.OverlayWidth := Integer(g_cfgEditWidth.Value)
    AppConfig.OverlayHeight := Integer(g_cfgEditHeight.Value)
    AppConfig.FontSize := Integer(g_cfgEditFontSize.Value)
    AppConfig.ChunkDelay := Integer(g_cfgEditChunkDelay.Value)
    AppConfig.EnableDebugLog := g_cfgChkDebugLog.Value

    AppConfig.EnableAutoTranslate := g_cfgChkAutoTranslate.Value
    AppConfig.ApiBase := g_cfgEditApiBase.Value
    AppConfig.ApiKey := g_cfgEditApiKey.Value
    AppConfig.Model := g_cfgCbbModel.Text
    AppConfig.TargetLanguage := g_cfgDdlTargetLang.Text

    AppConfig.Save()
    WriteLog("[Config] 配置已保存 (含 AI 翻译配置)")

    Native_HideGuiToOffscreen()
    nativeConfigGui.Hide()
}

_Native_CloseConfig(*) {
    global nativeConfigGui
    Native_HideGuiToOffscreen()
    nativeConfigGui.Hide()
}

_Native_ResetConfig(*) {
    global g_cfgEditOffsetX, g_cfgEditOffsetY, g_cfgEditWidth, g_cfgEditHeight, g_cfgEditFontSize, g_cfgEditChunkDelay, g_cfgChkDebugLog
    global g_cfgChkAutoTranslate, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel, g_cfgDdlTargetLang

    AppConfig.ResetDefaults()
    g_cfgEditOffsetX.Value := AppConfig.OffsetX
    g_cfgEditOffsetY.Value := AppConfig.OffsetY
    g_cfgEditWidth.Value := AppConfig.OverlayWidth
    g_cfgEditHeight.Value := AppConfig.OverlayHeight
    g_cfgEditFontSize.Value := AppConfig.FontSize
    g_cfgEditChunkDelay.Value := AppConfig.ChunkDelay
    g_cfgChkDebugLog.Value := AppConfig.EnableDebugLog

    g_cfgChkAutoTranslate.Value := AppConfig.EnableAutoTranslate
    g_cfgEditApiBase.Value := AppConfig.ApiBase
    g_cfgEditApiKey.Value := AppConfig.ApiKey
    g_cfgCbbModel.Text := AppConfig.Model
    g_cfgDdlTargetLang.Text := AppConfig.TargetLanguage

    _Native_UpdatePreview()
}
