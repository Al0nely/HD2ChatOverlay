; lib/Utils.ahk - 日志缓冲、IME 控制、Win32 封装、单实例锁、DPI 辅助

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
; 单实例锁 (Mutex) 与平滑重启
; -------------------------------------------------------------
global g_singleInstanceMutex := 0

EnsureSingleInstance() {
    global g_singleInstanceMutex
    isRestart := InStr(DllCall("GetCommandLine", "Str"), "/restart")

    mutexName := "Local\HD2ChatOverlay_SingleInstance_Mutex"
    g_singleInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", true, "Str", mutexName, "Ptr")
    lastErr := DllCall("GetLastError", "UInt")

    if (lastErr = 183) { ; ERROR_ALREADY_EXISTS
        if (isRestart) {
            ; 若为重启启动，循环等待旧进程退出
            loop 10 {
                Sleep(150)
                DllCall("CloseHandle", "Ptr", g_singleInstanceMutex)
                g_singleInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", true, "Str", mutexName, "Ptr")
                if (DllCall("GetLastError", "UInt") != 183)
                    return g_singleInstanceMutex
            }
        }
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

SafeReload() {
    ReleaseSingleInstance()
    Reload()
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
GetGameMonitorWorkArea(targetHwnd, &left, &top, &right, &bottom) {
    left := 0, top := 0, right := A_ScreenWidth, bottom := A_ScreenHeight
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    } catch {
    }

    if (!targetHwnd || !WinExist("ahk_id " targetHwnd))
        return

    try {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " targetHwnd)
        if (gx == -32000 || gy == -32000) ; 忽略最小化窗口坐标
            return

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

LimitGuiPos(targetHwnd, &posX, &posY, guiWidth := 0, guiHeight := 0) {
    if (guiWidth = 0)
        guiWidth := 510
    if (guiHeight = 0)
        guiHeight := 50

    GetGameMonitorWorkArea(targetHwnd, &minX, &minY, &maxX, &maxY)
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
; DPI 感知与坐标换算
; -------------------------------------------------------------

; 设置进程 DPI 感知为 PerMonitorV2
SetProcessDpiAwareness() {
    try {
        ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
        DllCall("SetProcessDpiAwarenessContext", "Ptr", -4, "UInt")
        WriteLog("[DPI] 已设置 PerMonitorV2 DPI 感知")
        return true
    } catch {
        try {
            ; 兼容旧系统: SetProcessDPIAware
            DllCall("SetProcessDPIAware", "UInt")
            WriteLog("[DPI] 已设置系统级 DPI 感知")
            return true
        } catch {
            WriteLog("[DPI] DPI 感知设置失败")
            return false
        }
    }
}

; 获取窗口所属显示器的 DPI
GetWindowDpi(hwnd) {
    try {
        dpi := DllCall("GetDpiForWindow", "Ptr", hwnd, "UInt")
        return dpi ? dpi : 96
    } catch {
        return 96
    }
}

; 获取系统 DPI
GetSystemDpi() {
    try {
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        dpi := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 88, "Int")  ; LOGPIXELSX
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        return dpi ? dpi : 96
    } catch {
        return 96
    }
}

; DPI 缩放因子
GetDpiScale(hwnd := 0) {
    dpi := hwnd ? GetWindowDpi(hwnd) : GetSystemDpi()
    return dpi / 96.0
}

; 逻辑像素 -> 物理像素
LogicalToPhysical(value, hwnd := 0) {
    return Round(value * GetDpiScale(hwnd))
}

; 物理像素 -> 逻辑像素
PhysicalToLogical(value, hwnd := 0) {
    scale := GetDpiScale(hwnd)
    return scale != 0 ? Round(value / scale) : value
}

; -------------------------------------------------------------
; 游戏窗口句柄智能探测与缓存
; -------------------------------------------------------------
global g_cachedGameHwnd := 0

; 筛选可见且具备有效分辨率的《绝地潜兵 2》主渲染窗口，避开 0x0 闪屏/崩溃守护/辅助窗口
FindHelldiversWindow() {
    hwnds := WinGetList("ahk_exe helldivers2.exe")
    if (hwnds.Length = 0)
        return 0

    for hwnd in hwnds {
        try {
            style := WinGetStyle("ahk_id " hwnd)
            ; 必须为可见窗口 (WS_VISIBLE = 0x10000000)
            if !(style & 0x10000000)
                continue
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            ; 过滤 0x0 或极小辅助窗口
            if (w >= 320 && h >= 240)
                return hwnd
        }
    }
    return hwnds[1]
}

global g_lastGameSearchTick := 0

GetGameHwnd(forceRefresh := false) {
    global g_cachedGameHwnd, g_lastGameSearchTick
    now := A_TickCount
    if (g_cachedGameHwnd && WinExist("ahk_id " g_cachedGameHwnd) && !forceRefresh)
        return g_cachedGameHwnd

    ; 当未找到游戏时，至少间隔 500ms 再执行昂贵的 WinGetList 扫描 (ShellHook 会在窗口创建时主动刷新)
    if (!forceRefresh && now - g_lastGameSearchTick < 500)
        return g_cachedGameHwnd

    g_lastGameSearchTick := now
    oldHwnd := g_cachedGameHwnd
    g_cachedGameHwnd := FindHelldiversWindow()
    if (g_cachedGameHwnd != oldHwnd) {
        if (g_cachedGameHwnd)
            WriteLog("[GameHwndCache] 捕获游戏窗口: 0x" Format("{:X}", g_cachedGameHwnd))
        else
            WriteLog("[GameHwndCache] 游戏窗口已关闭或重置")
    }
    return g_cachedGameHwnd
}

InvalidateGameHwndCache() {
    global g_cachedGameHwnd, g_lastGameSearchTick
    g_lastGameSearchTick := 0
    if (g_cachedGameHwnd != 0) {
        g_cachedGameHwnd := 0
        WriteLog("[GameHwndCache] 强制清空游戏窗口缓存")
    }
}

