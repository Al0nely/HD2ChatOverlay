#Requires AutoHotkey v2.0
; test/SyntaxCheck.ahk - 模块加载与语法自检 (不启动主程序)
; 用法: AutoHotkey64.exe test\SyntaxCheck.ahk
; 全部通过则输出 "SYNTAX_CHECK_PASS" 并退出; 任一失败弹出错误并退出码 1

#Include %A_ScriptDir%\..\lib\Config.ahk

; WriteLog 桩 (SyntaxCheck 不依赖 Utils.ahk 的日志队列, 避免 OnExit 冲突)
WriteLog(text) {
    OutputDebug(text)
}

; 最小依赖桩 (Glossary/Gui.Native 引用)
GetGameHwnd() => 0
LimitGuiPos(hwnd, &x, &y, w := 640, h := 58) => true
IME_SET(sts, t := "A") => 0
SetCapsLockSafe(s) => true
DisableGameIME() => true
ReleaseModifiers() => true
EnsureSingleInstance() => true
SetProcessDpiAwareness() => true
InitTrayMenu() => true

#Include %A_ScriptDir%\..\lib\Translation.ahk
#Include %A_ScriptDir%\..\lib\Glossary.ahk

errors := []

; --- 1. Config 加载 ---
try {
    AppConfig.Load()
    if (AppConfig.Model != "google/gemini-2.5-flash" && AppConfig.Model = "")
        errors.Push("Config.Model 为空")
    if (AppConfig.TranslateKey = "")
        errors.Push("Config.TranslateKey 为空")
    if (AppConfig.SwitchSourceKey = "")
        errors.Push("Config.SwitchSourceKey 为空")
} catch Error as err {
    errors.Push("Config.Load 异常: " err.Message)
}

; --- 2. Glossary 词库加载 + AC 自动机构建 ---
try {
    AppConfig.EnableGlossary := true
    AppConfig.GlossaryLocalPath := A_ScriptDir "\..\assets\glossary.core.json"
    ok := Glossary.Init()
    if (!ok)
        errors.Push("Glossary.Init 失败")
    else if (Glossary.terms.Length < 30)
        errors.Push("Glossary 词条数异常: " Glossary.terms.Length)
} catch Error as err {
    errors.Push("Glossary.Init 异常: " err.Message)
}

; --- 3. AC 自动机扫描命中测试 ---
try {
    hits := Glossary.ScanText("虫巢爆发了, 快呼叫撤离, 我带无后坐力步枪")
    if (hits.Length < 2)
        errors.Push("AC 扫描命中过少: " hits.Length)
    found := false
    for _, h in hits {
        if (h.en = "bug breach")
            found := true
    }
    if (!found)
        errors.Push("AC 未命中 'bug breach'")
} catch Error as err {
    errors.Push("Glossary.ScanText 异常: " err.Message)
}

; --- 4. FormatForPrompt ---
try {
    hint := Glossary.FormatForPrompt(Glossary.ScanText("撤离点在哪"))
    if (!InStr(hint, "extract"))
        errors.Push("FormatForPrompt 未包含 extract")
} catch Error as err {
    errors.Push("FormatForPrompt 异常: " err.Message)
}

; --- 5. Translation JSON 转义 ---
try {
    esc := OpenRouterClient._EscapeJsonStr('测试"引号"与\反斜杠')
    if (!InStr(esc, '\"'))
        errors.Push("JSON 转义失败")
} catch Error as err {
    errors.Push("Translation 转义异常: " err.Message)
}

; --- 结果输出 ---
if (errors.Length = 0) {
    FileAppend("SYNTAX_CHECK_PASS terms=" Glossary.terms.Length " buildMs=" Glossary.lastLoadMs " scanMs=" Glossary.lastScanMs "`n", "*", "UTF-8")
    ExitApp(0)
} else {
    msg := "SYNTAX_CHECK_FAIL:`n"
    for _, e in errors
        msg .= "- " e "`n"
    FileAppend(msg "`n", "*", "UTF-8")
    ExitApp(1)
}
