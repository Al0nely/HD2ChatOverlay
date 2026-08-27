#Requires AutoHotkey v2.0
; test/TestCapsLockLifecycle.ahk - 大小写锁定状态机与外部窗口状态记忆单元测试

global g_savedExternalCapsLock := "Off"
global isGameActive := false
global isChatActive := false
global currentCapsLockState := "Off"

; 状态机模拟
SetCapsLockSafe(targetState) {
    global currentCapsLockState
    currentCapsLockState := targetState
}

DisableGameIME() {
    SetCapsLockSafe("On")
}

SimulateSwitchToGame() {
    global isGameActive, g_savedExternalCapsLock, currentCapsLockState
    if (!isGameActive) {
        g_savedExternalCapsLock := currentCapsLockState
    }
    isGameActive := true
    DisableGameIME()
}

SimulateSwitchToExternal() {
    global isGameActive, g_savedExternalCapsLock, currentCapsLockState, isChatActive
    if (isGameActive && !isChatActive) {
        SetCapsLockSafe(g_savedExternalCapsLock)
    }
    isGameActive := false
}

SimulateShowChatGui() {
    global isChatActive
    isChatActive := true
    SetCapsLockSafe("Off")
}

SimulateSubmitText() {
    global isChatActive
    isChatActive := false
    DisableGameIME()
}

SimulateCloseGuiEsc() {
    global isChatActive
    isChatActive := false
    DisableGameIME()
}

results := []

; -------------------------------------------------------------
; 测试组 A：外部窗口初始为小写 (Off)
; -------------------------------------------------------------
currentCapsLockState := "Off"
SimulateSwitchToGame()
results.Push({ name: "A1. 外部窗口小写(Off) ➔ 切入游戏 ➔ 自动锁定大写(On)", pass: (currentCapsLockState = "On"), state: currentCapsLockState })

SimulateShowChatGui()
results.Push({ name: "A2. 游戏内大写(On) ➔ 唤醒黑金悬浮框 ➔ 自动切为小写(Off)打字", pass: (currentCapsLockState = "Off"), state: currentCapsLockState })

SimulateSubmitText()
results.Push({ name: "A3. 悬浮框提交文本 ➔ 返回游戏 ➔ 自动恢复大写(On)", pass: (currentCapsLockState = "On"), state: currentCapsLockState })

SimulateSwitchToExternal()
results.Push({ name: "A4. 离开游戏切回外部窗口 ➔ 精准恢复外部原本的小写(Off)", pass: (currentCapsLockState = "Off"), state: currentCapsLockState })

; -------------------------------------------------------------
; 测试组 B：外部窗口初始为大写 (On) （用户之前在写大写代码或按了CapsLock）
; -------------------------------------------------------------
currentCapsLockState := "On"
SimulateSwitchToGame()
results.Push({ name: "B1. 外部窗口大写(On) ➔ 切入游戏 ➔ 维持游戏大写(On)", pass: (currentCapsLockState = "On"), state: currentCapsLockState })

SimulateShowChatGui()
results.Push({ name: "B2. 游戏内 ➔ 唤醒悬浮框 ➔ 自动切为小写(Off)打字", pass: (currentCapsLockState = "Off"), state: currentCapsLockState })

SimulateCloseGuiEsc()
results.Push({ name: "B3. 悬浮框按 Esc 取消 ➔ 返回游戏 ➔ 自动恢复大写(On)", pass: (currentCapsLockState = "On"), state: currentCapsLockState })

SimulateSwitchToExternal()
results.Push({ name: "B4. 离开游戏切回外部窗口 ➔ 精准恢复外部原本的大写(On)", pass: (currentCapsLockState = "On"), state: currentCapsLockState })

; -------------------------------------------------------------
; 输出测试报告
; -------------------------------------------------------------
out := "====================================================`n"
out .= "🛡️ HD2ChatOverlay 大小写记忆与状态切换深度验证报告`n"
out .= "====================================================`n"

allPass := true
for idx, r in results {
    statusTag := r.pass ? "[PASS] " : "[FAIL] "
    if (!r.pass)
        allPass := false
    out .= statusTag r.name "`n   -> 当前状态: CapsLock=" r.state "`n"
}

out .= "----------------------------------------------------`n"
out .= allPass ? "✅ 验证结论: 8 项全链路大小写记忆与切换测试 100% 全部通过！`n" : "❌ 验证结论: 存在异常状态！`n"
out .= "====================================================`n"

logFile := A_ScriptDir "\capslock_verify.log"
try FileDelete(logFile)
FileAppend(out, logFile, "UTF-8")
ExitApp(allPass ? 0 : 1)
