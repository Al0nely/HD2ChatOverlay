#Requires AutoHotkey v2.0
; test/VerifyPrivilegeMatrix.ahk - 权限与 UIPI 特权隔离深度验证工具
; 用于测试并验证非管理员 vs 管理员权限下，热键捕获、消息传递、文本注入的差异

#SingleInstance Force

; -------------------------------------------------------------
; 1. 获取当前进程完整性级别 (Integrity Level)
; -------------------------------------------------------------
GetProcessIntegrityLevel(pid := 0) {
    if (pid = 0) {
        hProc := DllCall("GetCurrentProcess", "Ptr")
    } else {
        hProc := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr") ; PROCESS_QUERY_LIMITED_INFORMATION
    }

    if !hProc
        return "Unknown (OpenProcess Failed)"

    hToken := 0
    if !DllCall("Advapi32.dll\OpenProcessToken", "Ptr", hProc, "UInt", 0x0008, "Ptr*", &hToken) { ; TOKEN_QUERY
        if (pid != 0)
            DllCall("CloseHandle", "Ptr", hProc)
        return "Unknown (OpenProcessToken Failed)"
    }

    buf := Buffer(128, 0)
    cbSize := 0
    ilStr := "Unknown"
    if DllCall("Advapi32.dll\GetTokenInformation", "Ptr", hToken, "Int", 25, "Ptr", buf.Ptr, "UInt", buf.Size, "UInt*", &cbSize) {
        pSid := NumGet(buf.Ptr, 0, "Ptr") ; TOKEN_MANDATORY_LABEL.Label.Sid
        if pSid {
            pCount := DllCall("Advapi32.dll\GetSidSubAuthorityCount", "Ptr", pSid, "Ptr")
            count := pCount ? NumGet(pCount, 0, "UChar") : 0
            if (count > 0) {
                pRid := DllCall("Advapi32.dll\GetSidSubAuthority", "Ptr", pSid, "UInt", count - 1, "Ptr")
                rid := pRid ? NumGet(pRid, 0, "UInt") : 0
                if (rid < 0x2000)
                    ilStr := "Low (0x" Format("{:X}", rid) ")"
                else if (rid < 0x3000)
                    ilStr := "Medium [标准普通用户权限] (0x" Format("{:X}", rid) ")"
                else if (rid < 0x4000)
                    ilStr := "High [管理员权限] (0x" Format("{:X}", rid) ")"
                else
                    ilStr := "System (0x" Format("{:X}", rid) ")"
            }
        }
    }

    DllCall("CloseHandle", "Ptr", hToken)
    if (pid != 0)
        DllCall("CloseHandle", "Ptr", hProc)
    return ilStr
}

; -------------------------------------------------------------
; 2. 测试跨进程 UIPI 消息投递能力
; -------------------------------------------------------------
TestUipiMessageDelivery(targetHwnd) {
    if !targetHwnd || !WinExist("ahk_id " targetHwnd)
        return { success: false, errCode: -1, msg: "目标窗口不存在" }

    ; 发送 WM_NULL (0x0000) 探测 UIPI
    DllCall("SetLastError", "UInt", 0)
    res := DllCall("PostMessage", "Ptr", targetHwnd, "UInt", 0x0000, "Ptr", 0, "Ptr", 0, "Int")
    err := DllCall("GetLastError", "UInt")

    if (res = 0 && err = 5) { ; ERROR_ACCESS_DENIED = 5 (UIPI 阻断标志)
        return { success: false, errCode: 5, msg: "UIPI 拦截拒绝访问 (ERROR_ACCESS_DENIED / 5)" }
    } else if (res = 0) {
        return { success: false, errCode: err, msg: "PostMessage 失败 (Error: " err ")" }
    }

    return { success: true, errCode: 0, msg: "允许跨进程消息传递 (UIPI 放行)" }
}

; -------------------------------------------------------------
; 3. 构建测试 GUI 界面
; -------------------------------------------------------------
myIL := GetProcessIntegrityLevel()
isAdmin := A_IsAdmin

guiObj := Gui("+AlwaysOnTop", "HD2ChatOverlay - 权限与 UIPI 隔离分析验证工具")
guiObj.BackColor := "1E1E1E"
guiObj.SetFont("s10 cFFFFFF", "Microsoft YaHei UI")
guiObj.MarginX := 20
guiObj.MarginY := 15

guiObj.SetFont("s12 Bold cFFC800")
guiObj.AddText("w600", "🛡️ HD2ChatOverlay 权限与 UIPI 特权隔离审计报告")
guiObj.SetFont("s10 cFFFFFF")

guiObj.AddText("xm w600", "当前测试工具运行状态:")
guiObj.AddText("xm+15 w580 c" (isAdmin ? "00FF66" : "FF9E4A"), "• A_IsAdmin: " (isAdmin ? "True (管理员已提权)" : "False (普通标准用户)"))
guiObj.AddText("xm+15 w580 c" (isAdmin ? "00FF66" : "FF9E4A"), "• 完整性级别 (IL): " myIL)

guiObj.AddText("xm w600", "`n🎯 交互式目标窗口 UIPI 探测 (将焦点切到目标窗口后按 F8):")
statusText := guiObj.AddText("xm+15 w580 h120 cAAAAAA", "请先启动目标程序（如管理员记事本、游戏 helldivers2.exe 或普通记事本），`n然后将鼠标激活该窗口并按下键盘上的 [ F8 ] 键进行实时探测...")

guiObj.AddButton("xm w200 h35", "启动【普通权限记事本】").OnEvent("Click", (*) => Run("notepad.exe"))
guiObj.AddButton("x+15 w200 h35", "启动【管理员权限记事本】").OnEvent("Click", (*) => Run('*RunAs notepad.exe'))
guiObj.AddButton("x+15 w170 h35", "关闭本工具").OnEvent("Click", (*) => ExitApp())

guiObj.Show("w640")

; F8 快捷键: 探测当前前台活动窗口的权限与 UIPI 阻断情况
~F8:: {
    targetHwnd := WinActive("A")
    if (!targetHwnd || targetHwnd == guiObj.Hwnd)
        return

    title := WinGetTitle("ahk_id " targetHwnd)
    procName := WinGetProcessName("ahk_id " targetHwnd)
    targetPid := WinGetPID("ahk_id " targetHwnd)
    targetIL := GetProcessIntegrityLevel(targetPid)
    uipiTest := TestUipiMessageDelivery(targetHwnd)

    report := "【目标窗口分析结果】`n"
    report .= "• 进程名称: " procName " (PID: " targetPid ")`n"
    report .= "• 窗口标题: " SubStr(title, 1, 40) "`n"
    report .= "• 目标完整性级别 (IL): " targetIL "`n"
    report .= "• UIPI 消息投递测试: " uipiTest.msg "`n"

    if (InStr(targetIL, "High") && !isAdmin) {
        report .= "⚠️ 结论: 目标处于高权限 (High IL)，当前为普通权限 (Medium IL)！`n   -> 键盘全局钩子将被 Windows 旁路拦截，无法响应 Enter 唤醒！`n   -> 向目标转发按键和滚轮将被拒绝！"
    } else {
        report .= "✅ 结论: 权限级别平级或当前处于高权限，键盘钩子与消息传递正常！"
    }

    statusText.Value := report
}
