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
                return { success: false, error: this._ExtractErrorMessage(http.Status, this._GetUtf8Response(http)), models: [] }
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

    ; -------------------------------------------------------------
    ; 翻译文本 (POST /v1/chat/completions)
    ; -------------------------------------------------------------
    static TranslateText(text, targetLang, sourceLang, apiBase, apiKey, model, glossaryHint := "") {
        if (text = "")
            return { success: false, text: "", error: "输入文本为空" }

        if (apiBase = "")
            apiBase := "https://openrouter.ai/api/v1"
        if (model = "")
            model := "google/gemini-2.5-flash"
        if (targetLang = "")
            targetLang := "English"
        if (sourceLang = "")
            sourceLang := "Auto"

        url := RegExReplace(apiBase, "/+$", "") "/chat/completions"

        ; 基础 System Prompt: HD2 游戏语气 + 术语约束
        srcDesc := (sourceLang != "" && StrLower(sourceLang) != "auto") ? ("from " sourceLang " ") : ""
        systemPrompt := "You are a fast game chat translator for Helldivers 2 (《绝地潜兵 2》). Translate the user text " srcDesc "directly into " targetLang ". Keep it brief, natural, matching game tone and slang. Use official Helldivers 2 terminology (e.g. 虫族=Terminid, 机器人=Automaton, 撤离=extract, 战术配备=stratagem). Output ONLY the translated text without quotes or explanations."

        ; AC 自动机预扫描命中的当句术语动态注入
        if (glossaryHint != "")
            systemPrompt .= " " glossaryHint

        jsonBody := '{"model":"' this._EscapeJsonStr(model) '",'
        jsonBody .= '"messages":['
        jsonBody .= '{"role":"system","content":"' this._EscapeJsonStr(systemPrompt) '"},'
        jsonBody .= '{"role":"user","content":"' this._EscapeJsonStr(text) '"}'
        jsonBody .= '],'
        jsonBody .= '"temperature":0.2}'

        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("POST", url, true)
            http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay/1.3.0")
            http.SetRequestHeader("HTTP-Referer", "https://github.com/HD2ChatOverlay")
            http.SetRequestHeader("X-Title", "HD2 Chat Overlay")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)
            
            http.Send(jsonBody)
            if !http.WaitForResponse(8) { ; 8 秒超时
                return { success: false, text: text, error: "翻译请求超时 (8s)" }
            }

            if (http.Status != 200) {
                return { success: false, text: text, error: this._ExtractErrorMessage(http.Status, this._GetUtf8Response(http)) }
            }

            respText := this._GetUtf8Response(http)
            translated := this._ParseChatCompletionResponse(respText)

            if (translated = "")
                return { success: false, text: text, error: "解析译文为空" }

            return { success: true, text: translated, error: "" }
        } catch Error as err {
            return { success: false, text: text, error: "翻译网络异常: " err.Message }
        }
    }

    ; -------------------------------------------------------------
    ; 从 WinHttp 响应的 ResponseBody 二进制流中安全解码 UTF-8 文本
    ; -------------------------------------------------------------
    static _GetUtf8Response(http) {
        try {
            sa := ComObjValue(http.ResponseBody)
            pData := 0
            if (DllCall("oleaut32\SafeArrayAccessData", "Ptr", sa, "Ptr*", &pData) == 0) {
                size := http.ResponseBody.MaxIndex() + 1
                str := StrGet(pData, size, "UTF-8")
                DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", sa)
                return str
            }
        } catch {
        }
        try {
            return http.ResponseText
        } catch {
            return ""
        }
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
    ; JSON 解码基础字符串
    ; -------------------------------------------------------------
    static _UnescapeJsonStr(str) {
        out := ""
        pos := 1
        len := StrLen(str)
        while (pos <= len) {
            ch := SubStr(str, pos, 1)
            if (ch == "\" && pos < len) {
                nextCh := SubStr(str, pos + 1, 1)
                switch nextCh {
                    case '"':  out .= '"',  pos += 2
                    case "\": out .= "\", pos += 2
                    case "/":  out .= "/",  pos += 2
                    case "b":  out .= "`b", pos += 2
                    case "f":  out .= "`f", pos += 2
                    case "n":  out .= "`n", pos += 2
                    case "r":  out .= "`r", pos += 2
                    case "t":  out .= "`t", pos += 2
                    case "u":
                        if (pos + 5 <= len && RegExMatch(str, "^\\u([0-9a-fA-F]{4})", &m, pos)) {
                            out .= Chr(Integer("0x" m[1]))
                            pos += 6
                        } else {
                            out .= "\u"
                            pos += 2
                        }
                    default:
                        out .= nextCh
                        pos += 2
                }
            } else {
                out .= ch
                pos += 1
            }
        }
        return out
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
