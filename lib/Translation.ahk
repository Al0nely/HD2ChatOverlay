; lib/Translation.ahk - AI 实时翻译与 OpenRouter / OpenAI API 交互封装

class OpenRouterClient {

    ; -------------------------------------------------------------
    ; 拉取中转平台支持的模型列表 (GET /v1/models)
    ; -------------------------------------------------------------
    static FetchModelList(apiBase, apiKey) {
        if (apiBase = "")
            apiBase := "https://openrouter.ai/api/v1"

        ; 移除末尾斜杠
        url := RegExReplace(apiBase, "/+$", "") "/models"

        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", url, true) ; 异步请求
            http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay/1.3.0")
            http.SetRequestHeader("HTTP-Referer", "https://github.com/HD2ChatOverlay")
            http.SetRequestHeader("X-Title", "HD2 Chat Overlay")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)

            http.Send()
            if !http.WaitForResponse(5) { ; 5 秒超时
                return { success: false, error: "请求超时 (5s)", models: [] }
            }

            if (http.Status != 200) {
                return { success: false, error: this._ExtractErrorMessage(http.Status, this._GetUtf8Response(http)),
                    models: [] }
            }

            respText := this._GetUtf8Response(http)
            models := this._ParseModelList(respText)

            return { success: true, error: "", models: models }
        } catch Error as err {
            return { success: false, error: "网络连接失败: " err.Message, models: [] }
        }
    }

    ; -------------------------------------------------------------
    ; 测试 API 连通性 (GET /v1/models 不消耗 LLM Token)
    ; -------------------------------------------------------------
    static TestConnection(apiBase, apiKey) {
        if (apiBase = "")
            apiBase := "https://openrouter.ai/api/v1"

        url := RegExReplace(apiBase, "/+$", "") "/models"

        startMs := A_TickCount
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", url, true) ; 异步请求
            http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay/1.3.0")
            http.SetRequestHeader("HTTP-Referer", "https://github.com/HD2ChatOverlay")
            http.SetRequestHeader("X-Title", "HD2 Chat Overlay")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)

            http.Send()
            if !http.WaitForResponse(5) { ; 5 秒超时
                return { success: false, latencyMs: 0, error: "连接超时 (5s)", status: 0 }
            }

            latencyMs := A_TickCount - startMs
            status := http.Status

            if (status == 200) {
                return { success: true, latencyMs: latencyMs, error: "", status: 200 }
            } else {
                errDetail := this._ExtractErrorMessage(status, this._GetUtf8Response(http))
                return { success: false, latencyMs: latencyMs, error: errDetail, status: status }
            }
        } catch Error as err {
            return { success: false, latencyMs: 0, error: "网络连接失败: " err.Message, status: 0 }
        }
    }

    static _httpClient := ""

    static _GetHttpClient() {
        if (!this._httpClient) {
            this._httpClient := ComObject("WinHttp.WinHttpRequest.5.1")
        }
        return this._httpClient
    }

    static _ResetHttpClient() {
        this._httpClient := ""
    }

    ; -------------------------------------------------------------
    ; 翻译文本 (POST /v1/chat/completions)
    ; -------------------------------------------------------------
    static TranslateText(text, targetLang, sourceLang, apiBase, apiKey, model, glossaryHint := "") {
        if (text = "")
            return { success: false, text: "", error: "输入文本为空" }

        if (apiKey = "")
            return { success: false, text: text, error: "未设置 API Key，请打开配置界面填写" }

        if (apiBase = "")
            apiBase := "https://openrouter.ai/api/v1"
        if (model = "")
            model := "google/gemini-2.5-flash"
        if (targetLang = "")
            targetLang := "English"
        if (sourceLang = "")
            sourceLang := "Auto"

        url := RegExReplace(apiBase, "/+$", "") "/chat/completions"

        srcDesc := (sourceLang != "" && StrLower(sourceLang) != "auto") ? ("from " sourceLang " ") : ""
        systemPrompt :=
            "You are an authentic online multiplayer gamer translating real-time in-game chat for Helldivers 2. Translate the input " srcDesc "into natural, casual, humanized online gamer chat in " targetLang ". "
        systemPrompt .= "Style & Persona Rules: "
        systemPrompt .=
            "1. REAL GAMER TALK: Translate into raw, authentic gamer chat as typed in Discord/in-game squad chat. Adapt fully to " targetLang " gamer culture. For English, naturally use gamer shorthand (e.g., 'bro', 'pls', 're', 'tk', 'mb', 'fk'). For Chinese, use real player slang (e.g., '老哥', '拉我', '我的', '冲', 'nb'). "
        systemPrompt .=
            "2. EMOTICONS & SENTIMENT: Match the emotional energy and kaomoji/emoticons (e.g., 'T_T', 'xD', ':)') of the original sentence. DO NOT spam emoticons if the source text is neutral or plain. "
        systemPrompt .=
            "3. NO FORMAL TONE: Avoid textbook, formal, or rigid military phrasing. Keep it brief, snappy, and quick to read. "
        systemPrompt .=
            "4. GAME TERMS & GLOSSARY: Keep Helldivers 2 core terminology precise (e.g., Bile Titan, Charger, Stratagem, 500kg, Reinforce, Extract). If a explicit glossary mapping is provided in the prompt, ALWAYS prioritize it. "
        systemPrompt .= "Output ONLY the final translated chat text without quotes, prefixes, or explanations."

        ; AC 自动机预扫描命中的当句术语动态注入
        if (glossaryHint != "")
            systemPrompt .= " " glossaryHint

        jsonBody := '{"model":"' this._EscapeJsonStr(model) '",'
        jsonBody .= '"messages":['
        jsonBody .= '{"role":"system","content":"' this._EscapeJsonStr(systemPrompt) '"},'
        jsonBody .= '{"role":"user","content":"' this._EscapeJsonStr(text) '"}'
        jsonBody .= '],'
        jsonBody .= '"temperature":0.6}'

        try {
            http := this._GetHttpClient()
            http.SetTimeouts(5000, 5000, 10000, 15000) ; 域名 5s, 连接 5s, 发送 10s, 接收 15s
            http.Open("POST", url, true)
            http.SetRequestHeader("Connection", "Keep-Alive")
            http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay/1.4.3")
            http.SetRequestHeader("HTTP-Referer", "https://github.com/HD2ChatOverlay")
            http.SetRequestHeader("X-Title", "HD2 Chat Overlay")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)

            http.Send(jsonBody)
            if !http.WaitForResponse(15) { ; 15 秒超时
                this._ResetHttpClient()
                return { success: false, text: text, error: "翻译请求超时 (15s)，请检查网络或更换快速模型" }
            }

            if (http.Status != 200) {
                return { success: false, text: text, error: this._ExtractErrorMessage(http.Status, this._GetUtf8Response(
                    http)) }
            }

            respText := this._GetUtf8Response(http)
            translated := this._ParseChatCompletionResponse(respText)

            if (translated = "")
                return { success: false, text: text, error: "解析译文为空" }

            return { success: true, text: translated, error: "" }
        } catch Error as err {
            this._ResetHttpClient()
            return { success: false, text: text, error: "翻译网络异常: " err.Message }
        }
    }

    ; -------------------------------------------------------------
    ; 从 WinHttp 响应的 ResponseBody 二进制流中安全解码 UTF-8 文本
    ; -------------------------------------------------------------
    static _GetUtf8Response(http) {
        try {
            stream := ComObject("ADODB.Stream")
            stream.Type := 1 ; adTypeBinary
            stream.Open()
            stream.Write(http.ResponseBody)
            stream.Position := 0
            stream.Type := 2 ; adTypeText
            stream.Charset := "utf-8"
            str := stream.ReadText()
            stream.Close()
            if (str != "")
                return str
        } catch {
        }
        try {
            sa := ComObjValue(http.ResponseBody)
            pData := 0
            if (sa && DllCall("oleaut32\SafeArrayAccessData", "Ptr", sa, "Ptr*", &pData) == 0) {
                ub := 0
                DllCall("oleaut32\SafeArrayGetUBound", "Ptr", sa, "UInt", 1, "Int*", &ub)
                str := StrGet(pData, ub + 1, "UTF-8")
                DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", sa)
                return str
            }
        } catch {
        }
        return ""
    }

    ; -------------------------------------------------------------
    ; JSON 字符串转义
    ; -------------------------------------------------------------
    static _EscapeJsonStr(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`t", "\t")
        return str
    }

    ; -------------------------------------------------------------
    ; JSON 解码基础字符串 (高性能批量替换)
    ; -------------------------------------------------------------
    static _UnescapeJsonStr(str) {
        if (!InStr(str, "\"))
            return str

        str := StrReplace(str, '\"', '"')
        str := StrReplace(str, '\\', '\')
        str := StrReplace(str, '\/', '/')
        str := StrReplace(str, '\b', '`b')
        str := StrReplace(str, '\f', '`f')
        str := StrReplace(str, '\n', '`n')
        str := StrReplace(str, '\r', '`r')
        str := StrReplace(str, '\t', '`t')

        if InStr(str, "\u") {
            while RegExMatch(str, "\\u([0-9a-fA-F]{4})", &m) {
                str := StrReplace(str, m[0], Chr(Integer("0x" m[1])))
            }
        }
        return str
    }

    ; -------------------------------------------------------------
    ; 解析模型列表 JSON ("id": "...")
    ; -------------------------------------------------------------
    static _ParseModelList(jsonText) {
        models := []
        seen := Map()

        pos := 1
        while (pos := RegExMatch(jsonText, '"id"\s*:\s*"([^"]+)"', &m, pos)) {
            modelId := m[1]
            if (!seen.Has(modelId)) {
                seen[modelId] := true
                models.Push(modelId)
            }
            pos += StrLen(m[0])
        }

        return models
    }

    ; -------------------------------------------------------------
    ; 解析 Chat Completion 响应 ("content": "...")
    ; -------------------------------------------------------------
    static _ParseChatCompletionResponse(jsonText) {
        ; 正则提取 choices[0].message.content
        if RegExMatch(jsonText, '"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
            return Trim(this._UnescapeJsonStr(m[1]), " `t`r`n`"")
        }
        return ""
    }

    ; -------------------------------------------------------------
    ; 提取 JSON 报错响应中的详细错误原因
    ; -------------------------------------------------------------
    static _ExtractErrorMessage(httpStatus, responseText) {
        errMsg := "HTTP 错误: " httpStatus
        if (responseText != "") {
            if RegExMatch(responseText, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &mErr) {
                detail := this._UnescapeJsonStr(mErr[1])
                if (detail != "")
                    return errMsg " (" detail ")"
            }
            if RegExMatch(responseText, '"error"\s*:\s*"((?:[^"\\]|\\.)*)"', &mErr2) {
                detail2 := this._UnescapeJsonStr(mErr2[1])
                if (detail2 != "")
                    return errMsg " (" detail2 ")"
            }
        }
        if (httpStatus == 403)
            return errMsg " (403 拒绝访问: 请检查 API Key 有效性/节点授权/OpenRouter 余额)"
        if (httpStatus == 401)
            return errMsg " (401 未授权: API Key 错误或已被撤销)"
        if (httpStatus == 404)
            return errMsg " (404 未找到接口: 请检查 API Base 格式)"
        return errMsg
    }
}
