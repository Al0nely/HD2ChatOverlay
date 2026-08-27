#Requires AutoHotkey v2.0
; test/CliPrivilegeAudit.ahk - 命令行自动测试脚本：探测当前进程 Token 权限与 Win32 安全级别

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
            subAuthCount := NumGet(pSid, 1, "UChar")
            if (subAuthCount > 0) {
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
    }

    DllCall("CloseHandle", "Ptr", hToken)
    if (pid != 0)
        DllCall("CloseHandle", "Ptr", hProc)
    return ilStr
}

myIL := GetProcessIntegrityLevel()
isAdmin := A_IsAdmin

out := "====================================================`n"
out .= "HD2ChatOverlay 权限审计与安全性自检报告 (CLI)`n"
out .= "====================================================`n"
out .= "1. 当前进程 PID: " DllCall("GetCurrentProcessId", "UInt") "`n"
out .= "2. A_IsAdmin 状态: " (isAdmin ? "True (拥有管理员权限)" : "False (普通标准用户)") "`n"
out .= "3. 完整性级别 (Token Integrity Level): " myIL "`n"
out .= "4. AHK 解释器路径: " A_AhkPath "`n"
out .= "5. 是否编译模式 (A_IsCompiled): " (A_IsCompiled ? "True" : "False") "`n"
out .= "----------------------------------------------------`n"
out .= "【UIPI 影响分析】`n"
if (!isAdmin) {
    out .= "* 当前运行在 [Medium IL] 标准权限。`n"
    out .= "* 若游戏 helldivers2.exe 处于 [High IL] (由 GameGuard 或以管理员启动)：`n"
    out .= "  [x] 键盘钩子 (WH_KEYBOARD_LL) 将被 Windows UIPI 静默旁路，游戏内按 Enter 无法唤醒悬浮窗。`n"
    out .= "  [x] PostMessage 转发鼠标滚轮 (0x020A) 将被 Windows 拦截并抛出 ERROR_ACCESS_DENIED (5)。`n"
    out .= "  [x] IME_SET 向游戏发送输入法控制消息将被拒绝。`n"
} else {
    out .= "* 当前运行在 [High IL] 管理员特权。`n"
    out .= "* 与游戏进程平级，UIPI 特权隔离完全消除，键盘钩子与输入注入 100% 正常。`n"
}
out .= "====================================================`n"

logFile := A_ScriptDir "\privilege_audit.log"
try FileDelete(logFile)
FileAppend(out, logFile, "UTF-8")
ExitApp(0)
