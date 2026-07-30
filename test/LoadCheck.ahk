#Requires AutoHotkey v2.0
; test/LoadCheck.ahk - 主程序全模块加载验证 (不进入消息循环, 加载后立即报告并退出)
; 验证 hd2_chat.ahk 及其所有 #Include 是否无语法/引用错误

; 拦截主程序的常驻行为: 通过全局标志让主程序跳过热键注册后的驻留
; 做法: 直接 #Include 主程序, 但主程序末尾无 ExitApp, 会进入消息循环。
; 因此改为: 仅验证各 lib 模块可共同加载 + 主程序文本可被解析。

; 方案: 用 AHK 的 #Include 包含主程序会执行其顶层代码(含热键/托盘), 不适合 CI。
; 改用: 读取主程序文本, 检查关键符号存在性 + 各 lib 独立加载(已由 SyntaxCheck 覆盖)。

mainText := FileRead(A_ScriptDir "\..\hd2_chat.ahk", "UTF-8")

checks := Map(
    "IncludeGlossary", "#Include %A_ScriptDir%\lib\Glossary.ahk",
    "GlossaryInit", "Glossary.Init()",
    "RegisterHotkeys", "RegisterTranslationHotkeys()",
    "TranslateCall", "TranslateCurrentText",
    "ToggleSource", "ToggleInjectSource",
    "SubmitNoArg", "Enter:: SubmitText()"
)

fail := []
for name, needle in checks {
    if (!InStr(mainText, needle))
        fail.Push(name " 缺失: " needle)
}

; 验证 Gui.Native / Gui / Injection / ConfigGui 可共同加载 (含双悬浮窗符号)
#Include %A_ScriptDir%\..\lib\Config.ahk
WriteLog(t) => OutputDebug(t)
GetGameHwnd() => 0
LimitGuiPos(h, &x, &y, w := 640, hh := 58) => true
IME_SET(s, t := "A") => 0
SetCapsLockSafe(s) => true
DisableGameIME() => true
ReleaseModifiers() => true
#Include %A_ScriptDir%\..\lib\Translation.ahk
#Include %A_ScriptDir%\..\lib\Glossary.ahk
#Include %A_ScriptDir%\..\lib\Gui.Native.ahk

for sym in ["InitNativeTransGui", "Native_ShowTransGui", "Native_HighlightSource", "Native_SetTransText", "Native_GetTransText", "Native_ClearTransText", "Native_IsTransVisible"] {
    if (!InStr(FileRead(A_ScriptDir "\..\lib\Gui.Native.ahk", "UTF-8"), sym))
        fail.Push("Gui.Native.ahk 缺失函数: " sym)
}

injText := FileRead(A_ScriptDir "\..\lib\Injection.ahk", "UTF-8")
for sym in ["TranslateCurrentText", "g_injectSource", "Native_GetTransText"] {
    if (!InStr(injText, sym))
        fail.Push("Injection.ahk 缺失符号: " sym)
}

guiText := FileRead(A_ScriptDir "\..\lib\Gui.ahk", "UTF-8")
for sym in ["SetInjectSource", "ToggleInjectSource", "g_injectSource"] {
    if (!InStr(guiText, sym))
        fail.Push("Gui.ahk 缺失符号: " sym)
}

if (fail.Length = 0) {
    FileAppend("LOAD_CHECK_PASS`n", "*", "UTF-8")
    ExitApp(0)
} else {
    msg := "LOAD_CHECK_FAIL:`n"
    for _, e in fail
        msg .= "- " e "`n"
    FileAppend(msg "`n", "*", "UTF-8")
    ExitApp(1)
}
