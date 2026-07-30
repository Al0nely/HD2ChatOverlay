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
            http.SetRequestHeader("User-Agent", "HD2ChatOverlay/1.2.0")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)
            
            http.Send()
            if !http.WaitForResponse(5) { ; 5 秒超时
                return { success: false, error: "请求超时 (5s)", models: [] }
            }

            if (http.Status != 200) {
                return { success: false, error: "HTTP 错误: " http.Status, models: [] }
            }

            respText := http.ResponseText
            models := this._ParseModelList(respText)
            
            if (models.Length = 0)
                return { success: false, error: "解析模型列表为空", models: [] }

            return { success: true, error: "", models: models }
        } catch Error as err {
            return { success: false, error: "网络连接失败: " err.Message, models: [] }
        }
    }

    ; -------------------------------------------------------------
    ; 翻译文本 (POST /v1/chat/completions)
    ; -------------------------------------------------------------
    static TranslateText(text, targetLang, apiBase, apiKey, model) {
        if (text = "")
            return { success: false, text: "", error: "输入文本为空" }

        if (apiBase = "")
            apiBase := "https://openrouter.ai/api/v1"
        if (model = "")
            model := "google/gemini-2.5-flash"
        if (targetLang = "")
            targetLang := "English"

        url := RegExReplace(apiBase, "/+$", "") "/chat/completions"

        systemPrompt := "You are a fast game chat translator for Helldivers 2 (《绝地潜兵 2》). Translate the user text directly into " targetLang ". Keep it brief, natural, matching game tone and slang. Output ONLY the translated text without quotes or explanations."

        jsonBody := '{"model":"' this._EscapeJsonStr(model) '",'
        jsonBody .= '"messages":['
        jsonBody .= '{"role":"system","content":"' this._EscapeJsonStr(systemPrompt) '"},'
        jsonBody .= '{"role":"user","content":"' this._EscapeJsonStr(text) '"}'
        jsonBody .= '],'
        jsonBody .= '"temperature":0.3}'

        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("POST", url, true)
            http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            http.SetRequestHeader("User-Agent", "HD2ChatOverlay/1.2.0")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " apiKey)
            
            http.Send(jsonBody)
            if !http.WaitForResponse(8) { ; 8 秒超时
                return { success: false, text: text, error: "翻译请求超时 (8s)" }
            }

            if (http.Status != 200) {
                return { success: false, text: text, error: "HTTP 错误: " http.Status }
            }

            respText := http.ResponseText
            translated := this._ParseChatCompletionResponse(respText)

            if (translated = "")
                return { success: false, text: text, error: "解析译文为空" }

            return { success: true, text: translated, error: "" }
        } catch Error as err {
            return { success: false, text: text, error: "翻译网络异常: " err.Message }
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
        str := StrReplace(str, '\"', '"')
        str := StrReplace(str, '\\', '\')
        str := StrReplace(str, '\/', '/')
        str := StrReplace(str, '\n', '`n')
        str := StrReplace(str, '\r', '`r')
        str := StrReplace(str, '\t', '`t')
        ; 处理 unicode 转义如 \u4e2d
        while RegExMatch(str, "\\u([0-9a-fA-F]{4})", &m) {
            char := Chr(Integer("0x" m[1]))
            str := StrReplace(str, m[0], char)
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
}
