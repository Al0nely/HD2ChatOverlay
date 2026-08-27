#Requires AutoHotkey v2.0
; test/BenchmarkPerformance.ahk - 性能基准测试与吞吐量验证

#Include %A_ScriptDir%\..\lib\Config.ahk
WriteLog(t) => 0
GetGameHwnd() => 0
LimitGuiPos(h, &x, &y, w := 640, hh := 58) => true
IME_SET(s, t := "A") => 0
SetCapsLockSafe(s) => true
DisableGameIME() => true
ReleaseModifiers() => true

#Include %A_ScriptDir%\..\lib\Translation.ahk
#Include %A_ScriptDir%\..\lib\Glossary.ahk

AppConfig.GlossaryLocalPath := A_ScriptDir "\..\assets\glossary.core.json"
Glossary.Init()

out := "====================================================`n"
out .= "⚡ HD2ChatOverlay 核心模块性能基准测试 (10,000 次循环)`n"
out .= "====================================================`n"

; 1. AC 自动机单句扫描速度测试
testSentence := "虫巢爆发了，500kg 炸弹准备，快呼叫阔步虫歼灭和撤离，小心阔步虫和强袭虫！"
start := A_TickCount
loop 10000 {
    Glossary.ScanText(testSentence)
}
scanElapsed := A_TickCount - start
avgScanUs := (scanElapsed / 10000) * 1000
out .= "1. AC 自动机文本扫描 (10,000 次): " scanElapsed " ms (平均单次: " Round(avgScanUs, 2) " μs)`n"

; 2. JSON 字符串高速反转义测试
rawJsonStr := '\"This is a test: \u4e2d\u6587 with \\ escaped \\n and \\\"quotes\\\"\"'
start := A_TickCount
loop 10000 {
    OpenRouterClient._UnescapeJsonStr(rawJsonStr)
}
unescapeElapsed := A_TickCount - start
avgUnescapeUs := (unescapeElapsed / 10000) * 1000
out .= "2. JSON 高性能反转义 (10,000 次): " unescapeElapsed " ms (平均单次: " Round(avgUnescapeUs, 2) " μs)`n"

; 3. 无转义普通文本快速通道测试
plainStr := "This is a clean plain text without any backslashes"
start := A_TickCount
loop 100000 {
    OpenRouterClient._UnescapeJsonStr(plainStr)
}
plainElapsed := A_TickCount - start
out .= "3. 普通文本零转义直通 (100,000 次): " plainElapsed " ms (平均单次: " Round((plainElapsed / 100000) * 1000, 3) " μs)`n"

out .= "====================================================`n"

benchLog := A_ScriptDir "\benchmark_results.log"
try FileDelete(benchLog)
FileAppend(out, benchLog, "UTF-8")
ExitApp(0)
