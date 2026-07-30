; lib/ConfigGui.Native.ahk - 原生 AHK 配置窗口与实时预览机制

global nativeConfigGui := ""
global g_cfgEditOffsetX := ""
global g_cfgEditOffsetY := ""
global g_cfgEditWidth := ""
global g_cfgEditHeight := ""
global g_cfgEditFontSize := ""
global g_cfgEditChunkDelay := ""
global g_cfgChkAutoTranslate := ""
global g_cfgEditApiBase := ""
global g_cfgEditApiKey := ""
global g_cfgCbbModel := ""
global g_cfgDdlTargetLang := ""
global g_cfgTxtApiStatus := ""
global g_cfgChkGlossary := ""
global g_cfgChkEnablePythonScraper := ""
global g_cfgTxtGlossaryStatus := ""
global g_cfgEditTranslateKey := ""
global g_cfgEditSwitchKey := ""

Native_ShowConfigGui() {
    global nativeConfigGui, isChatActive, nativeIsChatActive, nativeEditBox
    global g_cfgEditOffsetX, g_cfgEditOffsetY, g_cfgEditWidth, g_cfgEditHeight, g_cfgEditFontSize, g_cfgEditChunkDelay, g_cfgChkDebugLog
    global g_cfgChkAutoTranslate, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel, g_cfgDdlTargetLang, g_cfgTxtApiStatus
    global g_cfgChkGlossary, g_cfgChkEnablePythonScraper, g_cfgTxtGlossaryStatus, g_cfgEditTranslateKey, g_cfgEditSwitchKey

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
            g_cfgChkGlossary.Value := AppConfig.EnableGlossary
            g_cfgEditTranslateKey.Value := AppConfig.TranslateKey
            g_cfgEditSwitchKey.Value := AppConfig.SwitchSourceKey
            if (g_cfgTxtApiStatus)
                g_cfgTxtApiStatus.Value := ""
            if (g_cfgTxtGlossaryStatus)
                g_cfgTxtGlossaryStatus.Value := Glossary.isLoaded ? ("词库: " Glossary.terms.Length " 词, 版本 " Glossary.version) : "词库未加载"
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
    nativeConfigGui.AddText("w460", "1. 悬浮窗位置偏移 (基于游戏右下角对齐)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    nativeConfigGui.AddText("xm+15 w115 +0x200", "OffsetX (X轴):")
    g_cfgEditOffsetX := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.OffsetX)
    udOffsetX := nativeConfigGui.AddUpDown("Range-2000-4000", AppConfig.OffsetX)

    nativeConfigGui.AddText("x+20 w115 +0x200", "OffsetY (Y轴):")
    g_cfgEditOffsetY := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.OffsetY)
    udOffsetY := nativeConfigGui.AddUpDown("Range-2000-4000", AppConfig.OffsetY)

    ; 快捷方向按钮组
    btnUp := nativeConfigGui.AddButton("xm+135 w55 h26", "▲ 上")
    btnDown := nativeConfigGui.AddButton("x+10 w55 h26", "▼ 下")
    btnLeft := nativeConfigGui.AddButton("x+10 w55 h26", "◄ 左")
    btnRight := nativeConfigGui.AddButton("x+10 w55 h26", "► 右")

    ; 2. 框体大小与尺寸配置
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w460", "2. 悬浮窗框体尺寸与字体")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    nativeConfigGui.AddText("xm+15 w115 +0x200", "宽度 (Width):")
    g_cfgEditWidth := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.OverlayWidth)
    udWidth := nativeConfigGui.AddUpDown("Range300-1200", AppConfig.OverlayWidth)

    nativeConfigGui.AddText("x+20 w115 +0x200", "高度 (Height):")
    g_cfgEditHeight := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.OverlayHeight)
    udHeight := nativeConfigGui.AddUpDown("Range30-150", AppConfig.OverlayHeight)

    nativeConfigGui.AddText("xm+15 w115 +0x200", "字体大小:")
    g_cfgEditFontSize := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.FontSize)
    udFontSize := nativeConfigGui.AddUpDown("Range10-36", AppConfig.FontSize)

    nativeConfigGui.AddText("x+20 w115 +0x200", "字间延迟(ms):")
    g_cfgEditChunkDelay := nativeConfigGui.AddEdit("x+5 w75 Number c000000", AppConfig.ChunkDelay)
    udChunkDelay := nativeConfigGui.AddUpDown("Range1-100", AppConfig.ChunkDelay)

    ; 3. AI 翻译设置 (OpenRouter / OpenAI 格式)
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w460", "3. 🤖 AI 翻译设置 (OpenRouter / OpenAI 格式)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    g_cfgChkAutoTranslate := nativeConfigGui.AddCheckbox("xm+15 w440 Checked" (AppConfig.EnableAutoTranslate ? 1 : 0), "开启翻译双悬浮框 (Ctrl+T 翻译, Ctrl+Tab 切换注入源)")

    nativeConfigGui.AddText("xm+15 w115 +0x200", "API Base:")
    g_cfgEditApiBase := nativeConfigGui.AddEdit("x+5 w320 c000000", AppConfig.ApiBase)

    nativeConfigGui.AddText("xm+15 w115 +0x200", "API Key:")
    g_cfgEditApiKey := nativeConfigGui.AddEdit("x+5 w320 Password* c000000", AppConfig.ApiKey)

    btnTestApi := nativeConfigGui.AddButton("xm+15 w130 h26", "🔌 测试 API 连接")
    btnFetchModels := nativeConfigGui.AddButton("x+10 w130 h26", "🔄 拉取模型列表")
    nativeConfigGui.AddText("x+10 w65 +0x200", "目标语言:")
    
    langList := ["English", "Chinese", "Japanese", "German", "French", "Spanish", "Russian"]
    g_cfgDdlTargetLang := nativeConfigGui.AddDropDownList("x+5 w115 c000000", langList)
    g_cfgDdlTargetLang.Text := AppConfig.TargetLanguage

    nativeConfigGui.AddText("xm+15 w115 +0x200", "模型选择:")
    presetModels := ["google/gemini-2.5-flash", "deepseek/deepseek-chat", "openai/gpt-4o-mini", "qwen/qwen-2.5-72b-instruct"]
    g_cfgCbbModel := nativeConfigGui.AddComboBox("x+5 w320 c000000", presetModels)
    g_cfgCbbModel.Text := AppConfig.Model

    ; API 验证/拉取状态提示文本
    g_cfgTxtApiStatus := nativeConfigGui.AddText("xm+15 w440 +0x200 cFFC800", "")

    ; 4. 术语库 (游戏黑话 AC 自动机预扫描)
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w460", "4. 📚 术语库 (游戏黑话预扫描)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    g_cfgChkGlossary := nativeConfigGui.AddCheckbox("xm+15 w280 Checked" (AppConfig.EnableGlossary ? 1 : 0), "启用术语注入 (AC 自动机预扫描)")
    btnUpdateGlossary := nativeConfigGui.AddButton("x+10 w150 h26", "🔄 更新术语库")

    g_cfgChkEnablePythonScraper := nativeConfigGui.AddCheckbox("xm+15 w440 Checked" (AppConfig.EnablePythonScraper ? 1 : 0), "允许远端失败时自动调用本地 Python (Conda) 刷新/采集")

    g_cfgTxtGlossaryStatus := nativeConfigGui.AddText("xm+15 w440 +0x200 cAAAAAA", Glossary.isLoaded ? ("词库: " Glossary.terms.Length " 词, 版本 " Glossary.version) : "词库未加载 (将使用内置核心库)")

    ; 5. 快捷键自定义 (AHK 语法: ^=Ctrl !=Alt +=Shift)
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w460", "5. ⌨️ 快捷键自定义 (AHK 语法: ^=Ctrl !=Alt +=Shift)")
    nativeConfigGui.SetFont("s10 cFFFFFF")

    nativeConfigGui.AddText("xm+15 w115 +0x200", "翻译快捷键:")
    g_cfgEditTranslateKey := nativeConfigGui.AddEdit("x+5 w100 c000000", AppConfig.TranslateKey)

    nativeConfigGui.AddText("x+20 w115 +0x200", "切换注入源:")
    g_cfgEditSwitchKey := nativeConfigGui.AddEdit("x+5 w100 c000000", AppConfig.SwitchSourceKey)

    ; 6. 系统服务
    nativeConfigGui.SetFont("s11 Bold cFFC800")
    nativeConfigGui.AddText("xm w460", "6. 系统服务")
    nativeConfigGui.SetFont("s10 cFFFFFF")
    g_cfgChkDebugLog := nativeConfigGui.AddCheckbox("xm+15 w300 Checked" (AppConfig.EnableDebugLog ? 1 : 0), "启用调试日志")

    ; 底部控制按钮
    btnSave := nativeConfigGui.AddButton("xm+40 w110 h32", "保存配置")
    btnCancel := nativeConfigGui.AddButton("x+25 w110 h32", "取消")
    btnReset := nativeConfigGui.AddButton("x+25 w110 h32", "恢复默认")

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

    ; 测试 API 按钮与拉取模型按钮
    btnTestApi.OnEvent("Click", _Native_TestApiConnection)
    btnFetchModels.OnEvent("Click", _Native_FetchModelList)
    btnUpdateGlossary.OnEvent("Click", _Native_UpdateGlossary)

    ; 保存按钮
    btnSave.OnEvent("Click", _Native_SaveConfig)
    btnCancel.OnEvent("Click", _Native_CloseConfig)
    btnReset.OnEvent("Click", _Native_ResetConfig)
    nativeConfigGui.OnEvent("Close", _Native_CloseConfig)

    ; 初始化位置刷新
    _Native_UpdatePreview()
    nativeConfigGui.Show("w500 AutoSize")
}

_Native_TestApiConnection(btnObj, *) {
    global nativeConfigGui, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgTxtApiStatus

    if (!nativeConfigGui)
        return

    apiBase := g_cfgEditApiBase.Value
    apiKey := g_cfgEditApiKey.Value

    btnObj.Enabled := false
    btnObj.Text := "⏳ 正在测试..."
    g_cfgTxtApiStatus.SetFont("cFFC800")
    g_cfgTxtApiStatus.Value := "⏳ 正在测试 API 连通性 (零 Token 消耗)，请稍候..."
    Sleep(10)

    res := OpenRouterClient.TestConnection(apiBase, apiKey)

    btnObj.Enabled := true
    btnObj.Text := "🔌 测试 API 连接"

    ; 强制将弹窗对话框属主设置为配置窗口，使其 100% 置顶在配置界面正上方
    nativeConfigGui.Opt("+OwnDialogs")

    if (res.success) {
        g_cfgTxtApiStatus.SetFont("c00FF00")
        g_cfgTxtApiStatus.Value := "✅ API 连通测试成功！延迟: " res.latencyMs " ms (授权通过)"
        MsgBox("✅ API 连接测试成功！`n`n中转节点: " apiBase "`n网络延迟: " res.latencyMs " ms`n授权状态: API Key 验证通过", "HD2 Chat Overlay", "Iconi")
    } else {
        g_cfgTxtApiStatus.SetFont("cFF5555")
        g_cfgTxtApiStatus.Value := "❌ 测试失败: " res.error
        MsgBox("❌ API 连接测试失败！`n`n详细原因: " res.error "`n中转节点: " apiBase (res.latencyMs > 0 ? "`n网络延迟: " res.latencyMs " ms" : ""), "HD2 Chat Overlay", "Icon!")
    }
}

_Native_FetchModelList(btnObj, *) {
    global nativeConfigGui, g_cfgEditApiBase, g_cfgEditApiKey, g_cfgCbbModel, g_cfgTxtApiStatus

    if (!nativeConfigGui)
        return

    apiBase := g_cfgEditApiBase.Value
    apiKey := g_cfgEditApiKey.Value

    btnObj.Enabled := false
    btnObj.Text := "⏳ 正在拉取..."
    g_cfgTxtApiStatus.SetFont("cFFC800")
    g_cfgTxtApiStatus.Value := "⏳ 正在从中转平台拉取模型列表..."
    Sleep(10)

    res := OpenRouterClient.FetchModelList(apiBase, apiKey)

    btnObj.Enabled := true
    btnObj.Text := "🔄 拉取模型列表"

    nativeConfigGui.Opt("+OwnDialogs")

    if (res.success) {
        currentModel := g_cfgCbbModel.Text
        g_cfgCbbModel.Delete()
        g_cfgCbbModel.Add(res.models)
        g_cfgCbbModel.Text := (currentModel != "") ? currentModel : res.models[1]
        
        g_cfgTxtApiStatus.SetFont("c00FF00")
        g_cfgTxtApiStatus.Value := "✅ 已成功拉取 " res.models.Length " 个可用模型！"
        MsgBox("✅ 成功拉取 " res.models.Length " 个可用模型！", "HD2 Chat Overlay", "Iconi")
    } else {
        g_cfgTxtApiStatus.SetFont("cFF5555")
        g_cfgTxtApiStatus.Value := "❌ 拉取失败: " res.error
        MsgBox("❌ 拉取模型列表失败:`n" res.error, "HD2 Chat Overlay", "Icon!")
    }
}

_Native_UpdateGlossary(btnObj, *) {
    global nativeConfigGui, g_cfgTxtGlossaryStatus

    if (!nativeConfigGui)
        return

    btnObj.Enabled := false
    btnObj.Text := "⏳ 更新中..."
    g_cfgTxtGlossaryStatus.SetFont("cFFC800")
    g_cfgTxtGlossaryStatus.Value := "⏳ 正在拉取/更新术语库..."
    Sleep(10)

    res := Glossary.CheckUpdate()

    btnObj.Enabled := true
    btnObj.Text := "🔄 更新术语库"

    nativeConfigGui.Opt("+OwnDialogs")

    failedUrl := res.HasOwnProp("failedUrl") ? res.failedUrl : AppConfig.GlossaryUrl
    errMsg := (res.error != "") ? res.error : "HTTP 404 / 无法连接"

    if (res.success) {
        if (res.HasOwnProp("remote") && res.remote) {
            ; 远端成功获取
            g_cfgTxtGlossaryStatus.SetFont("c00FF00")
            g_cfgTxtGlossaryStatus.Value := (res.updated ? "✅ 已更新到 " : "✅ 已是最新 ") "版本 " res.version " (" Glossary.terms.Length " 词)"
            if (res.updated)
                MsgBox("✅ 术语库更新成功！`n`n新版本: " res.version "`n词条数: " Glossary.terms.Length, "HD2 Chat Overlay", "Iconi")
        } else {
            ; 远端无法获取，但已自动降级载入本地词库/本地刷新
            g_cfgTxtGlossaryStatus.SetFont("cFFC800")
            g_cfgTxtGlossaryStatus.Value := "⚠️ 远端无法获取 (" errMsg ")，已载入本地词库 (" Glossary.terms.Length " 词)"
            
            detailText := "⚠️ 无法从远端获取术语库`n`n"
            if (failedUrl != "")
                detailText .= "请求的目标远端: " failedUrl "`n"
            detailText .= "失败原因: " errMsg "`n`n"
            detailText .= "已自动降级并载入本地术语库。`n`n"
            detailText .= "当前版本: " res.version "`n"
            detailText .= "词条数量: " Glossary.terms.Length " 词"

            MsgBox(detailText, "HD2 Chat Overlay", "Icon!")
        }
    } else {
        g_cfgTxtGlossaryStatus.SetFont("cFF5555")
        g_cfgTxtGlossaryStatus.Value := "❌ 远端与本地均无法获取: " errMsg
        
        detailText := "❌ 术语库更新失败:`n`n"
        if (failedUrl != "")
            detailText .= "请求的目标远端: " failedUrl "`n"
        detailText .= "失败原因: " errMsg "`n`n将继续使用现有词库。"
        
        MsgBox(detailText, "HD2 Chat Overlay", "Icon!")
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
    global g_cfgChkGlossary, g_cfgChkEnablePythonScraper, g_cfgEditTranslateKey, g_cfgEditSwitchKey

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
    AppConfig.EnableGlossary := g_cfgChkGlossary.Value
    AppConfig.EnablePythonScraper := g_cfgChkEnablePythonScraper.Value
    AppConfig.TranslateKey := Trim(g_cfgEditTranslateKey.Value)
    AppConfig.SwitchSourceKey := Trim(g_cfgEditSwitchKey.Value)

    AppConfig.Save()
    WriteLog("[Config] 配置已保存 (含 AI 翻译/术语库/快捷键配置)")
    TrayTip("HD2 Chat Overlay", "配置已保存。快捷键变更将在重载脚本后生效 (游戏内按 F12)。", 1)

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
    global g_cfgChkGlossary, g_cfgChkEnablePythonScraper, g_cfgEditTranslateKey, g_cfgEditSwitchKey

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
    g_cfgChkGlossary.Value := AppConfig.EnableGlossary
    g_cfgChkEnablePythonScraper.Value := AppConfig.EnablePythonScraper
    g_cfgEditTranslateKey.Value := AppConfig.TranslateKey
    g_cfgEditSwitchKey.Value := AppConfig.SwitchSourceKey

    _Native_UpdatePreview()
}
