; lib/Glossary.ahk - HD2 游戏黑话术语库：AC 自动机预扫描 + 热更新
; 词库格式 (glossary.json):
; {
;   "version": "2026.07.30",
;   "terms": [
;     { "zh": "虫巢", "en": "bug nest", "aliases": ["虫穴"], "category": "enemy" }
;   ]
; }

class Glossary {
    ; AC 自动机节点: Map(char -> node), node = { children: Map, fail: node, output: [termIndex...] }
    static root := ""
    static terms := []          ; [{zh, en, aliases, category}...]
    static version := ""
    static isLoaded := false
    static lastLoadMs := 0
    static lastScanMs := 0

    ; -------------------------------------------------------------
    ; 初始化：加载本地词库并构建 AC 自动机
    ; -------------------------------------------------------------
    static Init() {
        if (!AppConfig.EnableGlossary) {
            WriteLog("[Glossary] 术语库已禁用 (EnableGlossary=0)")
            return false
        }

        localPath := AppConfig.GlossaryLocalPath
        if (!FileExist(localPath)) {
            try {
                dir := SubStr(localPath, 1, InStr(localPath, "\", , -1) - 1)
                if (dir != "" && !DirExist(dir))
                    DirCreate(dir)
                FileInstall("assets/glossary.core.json", localPath, 0)
            } catch Error as err {
                WriteLog("[Glossary] FileInstall 提取内置词库失败: " err.Message)
            }
        }

        return this.LoadFromFile(localPath)
    }

    ; -------------------------------------------------------------
    ; 从 JSON 文件加载词库并构建自动机
    ; -------------------------------------------------------------
    static LoadFromFile(jsonPath) {
        startMs := A_TickCount

        jsonText := ""
        try {
            jsonText := FileRead(jsonPath, "UTF-8")
        } catch Error as err {
            WriteLog("[Glossary] 读取词库失败: " err.Message)
            return false
        }

        parsed := this._ParseGlossaryJson(jsonText)
        if (parsed.terms.Length = 0) {
            WriteLog("[Glossary] 词库解析为空或格式错误: " jsonPath)
            return false
        }

        this.terms := parsed.terms
        this.version := parsed.version
        this._BuildAutomaton()

        this.isLoaded := true
        this.lastLoadMs := A_TickCount - startMs
        WriteLog("[Glossary] 词库已加载: " this.terms.Length " 词, 版本 " this.version ", 构建耗时 " this.lastLoadMs "ms")
        return true
    }

    ; -------------------------------------------------------------
    ; -------------------------------------------------------------
    ; 热更新：从 CDN/URL 下载 glossary.json, 比对版本后覆盖本地并重建；
    ; 若远端下载失败（404/网络故障），自动降级触发本地 Python 刷新或重新载入本地核心词库。
    ; 返回 { success, updated, version, error }
    ; -------------------------------------------------------------
    static CheckUpdate() {
        urls := []
        if (AppConfig.GlossaryUrl != "")
            urls.Push(AppConfig.GlossaryUrl)

        ; 远端候选 URL 列表 (防止默认单点 404 导致功能不可用)
        candidateUrls := [
            "https://raw.githubusercontent.com/Al0nely/HD2ChatOverlay/main/assets/glossary.core.json",
            "https://cdn.jsdelivr.net/gh/Al0nely/HD2ChatOverlay@main/assets/glossary.core.json"
        ]
        for _, cUrl in candidateUrls {
            if (cUrl != AppConfig.GlossaryUrl)
                urls.Push(cUrl)
        }

        lastErr := ""
        failedUrl := AppConfig.GlossaryUrl != "" ? AppConfig.GlossaryUrl : (urls.Length > 0 ? urls[1] : "")
        localPath := AppConfig.GlossaryLocalPath

        for _, url in urls {
            res := this._TryDownloadUrl(url, localPath)
            if (res.success)
                return res
            failedUrl := url
            lastErr := res.error
        }

        WriteLog("[Glossary] 远端下载失败 (" failedUrl " -> " lastErr ")，尝试本地数据源刷新/恢复...")

        ; 降级策略 1: 尝试运行本地 Python 采集脚本刷新/生成词库 (仅在 AppConfig.EnablePythonScraper 为 true 时运行)
        scraperScript := A_ScriptDir "\tools\glossary_scraper.py"
        if (AppConfig.EnablePythonScraper && FileExist(scraperScript)) {
            SplitPath(localPath, , &dir)
            if (dir && !DirExist(dir))
                DirCreate(dir)

            pythonCmd := "python"
            condaEnvExe := "E:\Tools\Miniconda\envs\hd2chat\python.exe"
            if FileExist(condaEnvExe)
                pythonCmd := '"' condaEnvExe '"'
            else
                pythonCmd := 'conda run -n hd2chat python'

            cmd := pythonCmd ' "' scraperScript '" --out "' localPath '"'
            exitCode := RunWait(cmd, A_ScriptDir, "Hide")
            if (exitCode = 0 && FileExist(localPath)) {
                if this.LoadFromFile(localPath) {
                    WriteLog("[Glossary] 本地采集器生成/刷新词库成功: " this.terms.Length " 词, 版本 " this.version)
                    return { success: true, updated: true, remote: false, failedUrl: failedUrl, version: this.version " (本地刷新)", error: lastErr }
                }
            }
        }

        ; 降级策略 2: 若本地已有词库文件，重新载入
        if FileExist(localPath) {
            if this.LoadFromFile(localPath) {
                WriteLog("[Glossary] 已载入本地现有词库: " this.terms.Length " 词, 版本 " this.version)
                return { success: true, updated: false, remote: false, failedUrl: failedUrl, version: this.version " (本地现有)", error: lastErr }
            }
        }

        return { success: false, updated: false, remote: false, failedUrl: failedUrl, version: this.version, error: lastErr }
    }

    static _TryDownloadUrl(url, localPath) {
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", url, true)
            http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay/1.3.0")
            http.Send()
            if !http.WaitForResponse(8) {
                return { success: false, updated: false, remote: false, version: this.version, error: "下载超时 (8s)" }
            }
            if (http.Status != 200) {
                return { success: false, updated: false, remote: false, version: this.version, error: "HTTP " http.Status }
            }

            remoteText := http.ResponseText
            parsed := this._ParseGlossaryJson(remoteText)
            if (parsed.terms.Length = 0) {
                return { success: false, updated: false, remote: false, version: this.version, error: "远端词库格式错误" }
            }

            ; 版本相同则跳过
            if (parsed.version = this.version && this.isLoaded) {
                WriteLog("[Glossary] 词库已是最新版本: " this.version)
                return { success: true, updated: false, remote: true, version: this.version, error: "" }
            }

            ; 确保目录存在并覆盖本地文件
            SplitPath(localPath, , &dir)
            if (dir && !DirExist(dir))
                DirCreate(dir)

            try {
                if FileExist(localPath)
                    FileDelete(localPath)
                FileAppend(remoteText, localPath, "UTF-8")
            } catch Error as err {
                return { success: false, updated: false, remote: false, version: this.version, error: "写入本地失败: " err.Message }
            }

            ; 重建自动机
            this.terms := parsed.terms
            this.version := parsed.version
            this._BuildAutomaton()
            this.isLoaded := true

            WriteLog("[Glossary] 词库热更新成功: " this.terms.Length " 词, 新版本 " this.version)
            return { success: true, updated: true, remote: true, version: this.version, error: "" }
        } catch Error as err {
            return { success: false, updated: false, remote: false, version: this.version, error: "网络异常: " err.Message }
        }
    }

    ; -------------------------------------------------------------
    ; AC 自动机扫描：返回句子中命中的术语列表 [{zh, en}...] (去重)
    ; -------------------------------------------------------------
    static ScanText(text) {
        results := []
        if (!this.isLoaded || text = "")
            return results

        startMs := A_TickCount
        seen := Map()
        node := this.root

        Loop Parse, text {
            ch := A_LoopField
            ; 沿 fail 指针回退直到找到匹配子节点或回到根
            while (node != this.root && !node.children.Has(ch))
                node := node.fail

            if (node.children.Has(ch))
                node := node.children[ch]
            else
                node := this.root

            ; 收集当前节点所有输出（含 fail 链上的后缀匹配）
            tmp := node
            while (tmp != this.root) {
                if (tmp.HasOwnProp("output")) {
                    for _, termIdx in tmp.output {
                        if (!seen.Has(termIdx)) {
                            seen[termIdx] := true
                            t := this.terms[termIdx]
                            results.Push({ zh: t.zh, en: t.en, category: t.HasOwnProp("category") ? t.category : "" })
                        }
                    }
                }
                tmp := tmp.fail
            }
        }

        this.lastScanMs := A_TickCount - startMs
        return results
    }

    ; -------------------------------------------------------------
    ; 将命中术语格式化为 Prompt 注入字符串: "虫巢=bug nest; 撤离=extract"
    ; -------------------------------------------------------------
    static FormatForPrompt(hits, maxTerms := 12) {
        if (hits.Length = 0)
            return ""
        parts := []
        count := 0
        for _, h in hits {
            if (count >= maxTerms)
                break
            parts.Push(h.zh "=" h.en)
            count++
        }
        return "Terminology mapping (use exactly): " this._Join(parts, "; ")
    }

    ; -------------------------------------------------------------
    ; 构建 AC 自动机 (Trie + BFS fail 指针)
    ; -------------------------------------------------------------
    static _BuildAutomaton() {
        this.root := { children: Map(), fail: 0 }
        this.root.fail := this.root

        ; 第1步: 插入所有词条 (zh + aliases 均作为模式串, 输出指向同一 termIndex)
        for idx, term in this.terms {
            patterns := [term.zh]
            if (term.HasOwnProp("aliases") && term.aliases.Length > 0) {
                for _, alias in term.aliases {
                    if (alias != "" && alias != term.zh)
                        patterns.Push(alias)
                }
            }
            for _, pat in patterns {
                this._InsertPattern(pat, idx)
            }
        }

        ; 第2步: BFS 构建 fail 指针
        queue := []
        for ch, child in this.root.children {
            child.fail := this.root
            queue.Push(child)
        }

        while (queue.Length > 0) {
            curr := queue.RemoveAt(1)
            for ch, child in curr.children {
                ; 找 curr 的 fail 链上第一个含 ch 子节点的节点
                f := curr.fail
                while (f != this.root && !f.children.Has(ch))
                    f := f.fail
                child.fail := (f.children.Has(ch) && f.children[ch] != child) ? f.children[ch] : this.root

                ; 合并 fail 节点的输出 (后缀匹配)
                if (child.fail.HasOwnProp("output")) {
                    if (!child.HasOwnProp("output"))
                        child.output := []
                    for _, o in child.fail.output
                        child.output.Push(o)
                }
                queue.Push(child)
            }
        }
    }

    static _InsertPattern(pattern, termIdx) {
        if (pattern = "")
            return
        node := this.root
        Loop Parse, pattern {
            ch := A_LoopField
            if (!node.children.Has(ch)) {
                node.children[ch] := { children: Map(), fail: this.root }
            }
            node := node.children[ch]
        }
        if (!node.HasOwnProp("output"))
            node.output := []
        node.output.Push(termIdx)
    }

    ; -------------------------------------------------------------
    ; 解析 glossary JSON (无第三方库, 正则提取, 与 Translation.ahk 风格一致)
    ; 返回 { version, terms: [{zh, en, aliases, category}...] }
    ; -------------------------------------------------------------
    static _ParseGlossaryJson(jsonText) {
        terms := []
        version := ""

        if RegExMatch(jsonText, '"version"\s*:\s*"([^"]+)"', &mVer)
            version := mVer[1]

        ; 逐条提取 term 对象块
        pos := 1
        while (pos := RegExMatch(jsonText, '\{[^{}]*"zh"[^{}]*\}', &mTerm, pos)) {
            block := mTerm[0]
            zh := "", en := "", category := "", aliases := []

            if RegExMatch(block, '"zh"\s*:\s*"((?:[^"\\]|\\.)*)"', &mZh)
                zh := this._Unescape(mZh[1])
            if RegExMatch(block, '"en"\s*:\s*"((?:[^"\\]|\\.)*)"', &mEn)
                en := this._Unescape(mEn[1])
            if RegExMatch(block, '"category"\s*:\s*"((?:[^"\\]|\\.)*)"', &mCat)
                category := this._Unescape(mCat[1])

            ; aliases 数组提取
            if RegExMatch(block, '"aliases"\s*:\s*\[([^\]]*)\]', &mAl) {
                alPos := 1
                while (alPos := RegExMatch(mAl[1], '"((?:[^"\\]|\\.)*)"', &mAlItem, alPos)) {
                    aliases.Push(this._Unescape(mAlItem[1]))
                    alPos += StrLen(mAlItem[0])
                }
            }

            if (zh != "" && en != "")
                terms.Push({ zh: zh, en: en, aliases: aliases, category: category })

            pos += StrLen(mTerm[0])
        }

        return { version: version, terms: terms }
    }

    static _Unescape(str) {
        str := StrReplace(str, '\"', '"')
        str := StrReplace(str, '\\', '\')
        str := StrReplace(str, '\/', '/')
        str := StrReplace(str, '\n', '`n')
        str := StrReplace(str, '\r', '`r')
        str := StrReplace(str, '\t', '`t')
        while RegExMatch(str, "\\u([0-9a-fA-F]{4})", &m) {
            str := StrReplace(str, m[0], Chr(Integer("0x" m[1])))
        }
        return str
    }

    static _Join(arr, sep) {
        out := ""
        for i, v in arr
            out .= (i > 1 ? sep : "") v
        return out
    }
}
