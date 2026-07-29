; lib/Utils.ahk - 日志缓冲、IME 控制、Win32 封装、单实例锁

; -------------------------------------------------------------
; 日志缓冲批量写入系统
; -------------------------------------------------------------
global g_logQueue := []
global g_logFlushTimer := 0

WriteLog(text) {
    global g_logQueue
    if (!AppConfig.EnableDebugLog)
        return

    ms := A_MSec
    msStr := (ms < 10 ? "00" ms : (ms < 100 ? "0" ms : ms))
    timeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss.") msStr
    g_logQueue.Push("[" timeStr "] " text "`n")

    ; 满 10 条立即 flush
    if (g_logQueue.Length >= 10)
        FlushLogs()
    else
        _EnsureLogFlushTimer()
}

FlushLogs() {
    global g_logQueue
    if (g_logQueue.Length = 0)
        return

    logPath := A_ScriptDir "\hd2_chat_debug.log"
    batch := ""
    for _, line in g_logQueue
        batch .= line

    try {
        FileAppend(batch, logPath, "UTF-8")
    } catch {
        ; 写入失败不崩溃
    }

    g_logQueue := []
}

_EnsureLogFlushTimer() {
    global g_logFlushTimer
    if (g_logFlushTimer)
        return
    ; 500ms 后批量 flush
    g_logFlushTimer := SetTimer(_LogFlushCallback, -500)
}

_LogFlushCallback() {
    global g_logFlushTimer
    g_logFlushTimer := 0
    FlushLogs()
}

; 脚本退出时强制 flush
OnExit(_ExitFlushLogs)
_ExitFlushLogs(*) {
    FlushLogs()
}

; -------------------------------------------------------------
; 单实例锁 (Mutex)
; -------------------------------------------------------------
global g_singleInstanceMutex := 0

EnsureSingleInstance() {
    global g_singleInstanceMutex
    mutexName := "Local\HD2ChatOverlay_SingleInstance_Mutex"
    g_singleInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", true, "Str", mutexName, "Ptr")
    lastErr := DllCall("GetLastError", "UInt")

    if (lastErr = 183) { ; ERROR_ALREADY_EXISTS
        MsgBox("《绝地潜兵 2》中文输入插件已在后台运行中！`n请查看系统托盘图标。", "HD2 Chat Overlay", "Iconi")
        ExitApp()
    }
    return g_singleInstanceMutex
}

ReleaseSingleInstance() {
    global g_singleInstanceMutex
    if (g_singleInstanceMutex) {
        DllCall("ReleaseMutex", "Ptr", g_singleInstanceMutex)
        DllCall("CloseHandle", "Ptr", g_singleInstanceMutex)
        g_singleInstanceMutex := 0
    }
}

; -------------------------------------------------------------
; IME 控制
; -------------------------------------------------------------
IME_SET(SetSts, WinTitle := "A") {
    hwnd := WinExist(WinTitle)
    if !hwnd
        return 0
    if (WinActive(WinTitle)) {
        ptrSize := A_PtrSize
        cbSize := 8 + (ptrSize * 6) + 16
        stGTI := Buffer(cbSize, 0)
        NumPut("UInt", cbSize, stGTI, 0)
        if DllCall("GetGUIThreadInfo", "Uint", 0, "Ptr", stGTI.Ptr) {
            focusedHwnd := NumGet(stGTI.Ptr, 8 + ptrSize, "UPtr")
            if focusedHwnd
                hwnd := focusedHwnd
        }
    }

    hIMC := DllCall("imm32\ImmGetContext", "Ptr", hwnd, "Ptr")
    if hIMC {
        currSts := DllCall("imm32\ImmGetOpenStatus", "Ptr", hIMC, "UInt")
        DllCall("imm32\ImmReleaseContext", "Ptr", hwnd, "Ptr", hIMC)
        if (currSts == SetSts)
            return 1
    }

    defaultImeWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !defaultImeWnd
        return 0
    return DllCall("PostMessage", "Ptr", defaultImeWnd, "UInt", 0x0283, "Int", 0x006, "Int", SetSts)
}

SetCapsLockSafe(targetState) {
    currState := GetKeyState("CapsLock", "T") ? "On" : "Off"
    if (currState != targetState) {
        SetCapsLockState targetState
        WriteLog("[CapsLockManager] 状态变更: " currState " -> " targetState)
    }
}

DisableGameIME() {
    SetCapsLockSafe("On")
}

; -------------------------------------------------------------
; 多显示器工作区计算
; -------------------------------------------------------------
GetGameMonitorWorkArea(gameHwnd, &left, &top, &right, &bottom) {
    left := 0, top := 0, right := A_ScreenWidth, bottom := A_ScreenHeight
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    } catch {
    }

    if !gameHwnd
        return

    try {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " gameHwnd)
        gcx := gx + (gw // 2)
        gcy := gy + (gh // 2)

        loop MonitorGetCount() {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
            if (gcx >= ml && gcx <= mr && gcy >= mt && gcy <= mb) {
                MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
                break
            }
        }
    } catch {
    }
}

LimitGuiPos(gameHwnd, &posX, &posY, guiWidth := 510, guiHeight := 48) {
    GetGameMonitorWorkArea(gameHwnd, &minX, &minY, &maxX, &maxY)
    if (posX < minX)
        posX := minX
    if (posY < minY)
        posY := minY
    if (posX + guiWidth > maxX)
        posX := maxX - guiWidth
    if (posY + guiHeight > maxY)
        posY := maxY - guiHeight
}

; -------------------------------------------------------------
; 游戏窗口句柄缓存
; -------------------------------------------------------------
global g_cachedGameHwnd := 0

GetGameHwnd(forceRefresh := false) {
    global g_cachedGameHwnd
    if (forceRefresh || !g_cachedGameHwnd || !WinExist("ahk_id " g_cachedGameHwnd)) {
        g_cachedGameHwnd := WinExist("ahk_exe helldivers2.exe")
        WriteLog("[GameHwndCache] 刷新缓存: 0x" Format("{:X}", g_cachedGameHwnd))
    }
    return g_cachedGameHwnd
}

InvalidateGameHwndCache() {
    global g_cachedGameHwnd
    g_cachedGameHwnd := 0
}
