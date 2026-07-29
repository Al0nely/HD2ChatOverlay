#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
KeyHistory 0

; 🎯 统一屏幕坐标系
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; -------------------------------------------------------------
; 💾 路径与配置系统
; -------------------------------------------------------------
global iniPath := A_ScriptDir "\hd2_chat_settings.ini"
global logPath := A_ScriptDir "\hd2_chat_debug.log"
global enableDebugLog := false

WriteLog(text) {
    global logPath, enableDebugLog
    if (!enableDebugLog)
        return
    try {
        ms := A_MSec
        msStr := (ms < 10 ? "00" ms : (ms < 100 ? "0" ms : ms))
        timeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss.") msStr
        FileAppend("[" timeStr "] " text "`n", logPath, "UTF-8")
    }
    OutputDebug("[HD2Chat] " text "`n")
}

ReadIntSetting(section, key, defaultVal) {
    global iniPath
    valStr := IniRead(iniPath, section, key, String(defaultVal))
    try {
        return Integer(valStr)
    } catch {
        return defaultVal
    }
}

global OffsetX := ReadIntSetting("Coordinates", "OffsetX", 840)
global OffsetY := ReadIntSetting("Coordinates", "OffsetY", 638)
global isChatActive := false
global isAdjusting := false
global lastShowTime := 0
global isBoundToGame := false

; -------------------------------------------------------------
; 🏛️ 静态常驻窗口初始化 (暗色类刷子 + 防动画 + 离屏驻留)
; -------------------------------------------------------------
global chatGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
chatGui.BackColor := "111317"
chatGui.MarginX := 15
chatGui.MarginY := 10
chatGui.SetFont("s18 Bold cFFFFFF", "SimHei")

; 💡 -E0x0200 抹除 Win32 Edit 控件默认的 3D 白边 (WS_EX_CLIENTEDGE)，实现纯黑无边框融为一体
global editBox := chatGui.AddEdit("w480 -Border -E0x0200 Background111317 cFFFFFF")

; 💡 修改 Win32 窗口类的默认背景刷子为暗色 (#111317 -> COLORREF 0x00171311)
global hDarkBrush := DllCall("CreateSolidBrush", "UInt", 0x00171311, "Ptr")
DllCall("SetClassLongPtr", "Ptr", chatGui.Hwnd, "Int", -10, "Ptr", hDarkBrush) ; -10 = GCLP_HBRBACKGROUND

; 💡 禁用 DWM 窗口过渡动画
dwmDisableAnim := Buffer(4, 0)
NumPut("Int", 1, dwmDisableAnim)
DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", chatGui.Hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

; 💡 离屏驻留挂载
chatGui.Show("x-9999 y-9999 w510 h48 NA")

; -------------------------------------------------------------
; 🔤 核心：WM_CHAR (0x0102) 微秒级小写映射 (Zero-CapsLock Toggle 架构)
; 当游戏内 CapsLock 为大写 On 状态时，Win32 Edit 控件原生会产生大写字符 (65-90)
; 若未按下物理 Shift，拦截并转换为小写 (97-122) 投递给拼音 IME 引擎
; 若按下了物理 Shift，允许输出原生大写字母！
; -------------------------------------------------------------
OnMessage(0x0102, WM_CHAR_Callback)

WM_CHAR_Callback(wParam, lParam, msg, hwnd) {
    global editBox, isChatActive
    if (isChatActive && hwnd == editBox.Hwnd) {
        if (wParam >= 65 && wParam <= 90) {
            ; 物理按住 Shift 时，允许输入大写英文字母！
            if GetKeyState("Shift", "P")
                return

            lowerWParam := wParam + 32
            DllCall("PostMessage", "Ptr", editBox.Hwnd, "UInt", 0x0102, "Ptr", lowerWParam, "Ptr", lParam)
            return 0 ; 拦截原本的大写 WM_CHAR 消息
        }
    }
}

OnMessage(0x0201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global chatGui, editBox
    if (hwnd == chatGui.Hwnd) {
        editBox.Focus()
        SetEditCaret()
    }
}

SetEditCaret() {
    global editBox
    try {
        DllCall("CreateCaret", "Ptr", editBox.Hwnd, "Ptr", 0, "Int", 2, "Int", 22)
        DllCall("ShowCaret", "Ptr", editBox.Hwnd)
    }
}

; -------------------------------------------------------------
; 🌐 输入法与键盘布局底层控制
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

SetGuiLayoutToChinese() {
    try {
        IME_SET(1, "ahk_id " chatGui.Hwnd)
    } catch Error as err {
        WriteLog("[SetGuiLayoutToChinese] 异常: " err.Message)
    }
}

DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
global shellMessageNum := DllCall("RegisterWindowMessage", "Str", "ShellHook")
OnMessage(shellMessageNum, ShellMessageCallback)

global lastActiveHwnd := 0

ShellMessageCallback(wParam, lParam, *) {
    if (wParam = 1 || wParam = 4 || wParam = 32769 || wParam = 32772) {
        SetTimer(_ProcessShellEvent.Bind(lParam), -1)
    }
}

_ProcessShellEvent(activeHwnd) {
    global lastActiveHwnd, isChatActive, isBoundToGame
    gameHwnd := WinExist("ahk_exe helldivers2.exe")

    if !activeHwnd || activeHwnd == chatGui.Hwnd
        return

    procName := ""
    try {
        procName := WinGetProcessName("ahk_id " activeHwnd)
    } catch {
        procName := "Unknown"
    }

    guiThreadId := DllCall("GetWindowThreadProcessId", "Ptr", chatGui.Hwnd, "Ptr", 0, "UInt")
    activeThreadId := DllCall("GetWindowThreadProcessId", "Ptr", activeHwnd, "Ptr", 0, "UInt")
    activeOwner := DllCall("GetWindow", "Ptr", activeHwnd, "UInt", 4, "Ptr")

    if (procName ~= "i)(TextInputHost|ctfmon|SogouInput|QQInput|BaiduInput)\.exe"
        || activeThreadId == guiThreadId
        || activeOwner == chatGui.Hwnd) {
        return
    }

    if (gameHwnd && activeHwnd = gameHwnd) {
        if DllCall("IsHungAppWindow", "Ptr", gameHwnd)
            return
        if isChatActive
            return
        DisableGameIME()
    } else if (activeHwnd != 0) {
        if (isChatActive && !isAdjusting) {
            CloseGui(false)
        }
        SetCapsLockSafe("Off")
        isBoundToGame := false
    }
    lastActiveHwnd := activeHwnd
}

GetGameMonitorWorkArea(&left, &top, &right, &bottom) {
    left := 0, top := 0, right := A_ScreenWidth, bottom := A_ScreenHeight
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    } catch {
    }

    gameHwnd := WinExist("ahk_exe helldivers2.exe")
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

LimitGuiPos(&posX, &posY, guiWidth := 510, guiHeight := 48) {
    GetGameMonitorWorkArea(&minX, &minY, &maxX, &maxY)
    if (posX < minX)
        posX := minX
    if (posY < minY)
        posY := minY
    if (posX + guiWidth > maxX)
        posX := maxX - guiWidth
    if (posY + guiHeight > maxY)
        posY := maxY - guiHeight
}

#HotIf WinActive("ahk_exe helldivers2.exe") && !isChatActive && !isAdjusting

$~$Enter::
$~$NumpadEnter:: {
    global isChatActive, chatGui, editBox, OffsetX, OffsetY, lastShowTime, isBoundToGame
    if (isChatActive || (A_TickCount - lastShowTime < 200))
        return

    isChatActive := true
    lastShowTime := A_TickCount

    gameHwnd := WinExist("ahk_exe helldivers2.exe")
    if gameHwnd {
        try {
            if (!isBoundToGame || DllCall("GetWindow", "Ptr", chatGui.Hwnd, "UInt", 4, "Ptr") != gameHwnd) {
                DllCall("SetWindowLongPtr", "Ptr", chatGui.Hwnd, "Int", -8, "Ptr", gameHwnd)
                isBoundToGame := true
            }

            WinGetPos(&X, &Y, &W, &H, "ahk_id " gameHwnd)
            posX := X + W - OffsetX
            posY := Y + H - OffsetY
            LimitGuiPos(&posX, &posY)

            chatGui.Move(posX, posY)
        } catch TargetError {
            chatGui.Move(100, 100)
        }
    } else {
        chatGui.Move(100, 100)
    }

    chatGui.Show()
    editBox.Value := ""
    editBox.Focus()
    SetEditCaret()
    SetGuiLayoutToChinese()
}

#HotIf

HideGuiToOffscreen() {
    global chatGui
    chatGui.Move(-9999, -9999)
    chatGui.Hide()
    gameHwnd := WinExist("ahk_exe helldivers2.exe")
    if gameHwnd {
        try WinActivate("ahk_id " gameHwnd)
    }
}

SubmitText(*) {
    global isChatActive, editBox
    if !isChatActive
        return

    isChatActive := false
    rawText := editBox.Value
    editBox.Value := ""

    HideGuiToOffscreen()

    if WinExist("ahk_exe helldivers2.exe") {
        if (rawText != "") {
            SendInput("{Alt Up}{Ctrl Up}{Shift Up}")
            sanitizedText := RegExReplace(rawText, "[\r\n]+", " ")
            SendOptimizedText(sanitizedText)
            Sleep(30)
            SendInput("{Alt Up}{Ctrl Up}{Shift Up}")
            SendEvent("{Enter}")
            DisableGameIME()
        } else {
            SendInput("{Alt Up}{Ctrl Up}{Shift Up}")
            SendEvent("{Enter}")
            DisableGameIME()
        }
    }
}

CloseGui(sendEsc := false) {
    global isChatActive, editBox
    if !isChatActive
        return
    isChatActive := false
    editBox.Value := ""

    HideGuiToOffscreen()

    if WinExist("ahk_exe helldivers2.exe") {
        if (sendEsc) {
            SendInput("{Alt Up}{Ctrl Up}{Shift Up}")
            SendEvent("{Escape}")
        }
        DisableGameIME()
    }
}

ForwardScrollToGame(direction) {
    gameHwnd := WinExist("ahk_exe helldivers2.exe")
    if !gameHwnd
        return

    MouseGetPos &mx, &my, &mHwnd
    if (mHwnd != chatGui.Hwnd) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " chatGui.Hwnd)
            mx := gx + (gw // 2)
            my := gy + (gh // 2)
        } catch {
        }
    }

    lParam := ((my & 0xFFFF) << 16) | (mx & 0xFFFF)
    wParam := (direction = "WheelUp") ? (120 << 16) : ((-120 << 16) & 0xFFFFFFFF)

    PostMessage(0x020A, wParam, lParam, , "ahk_id " gameHwnd)
}

SendOptimizedText(rawText) {
    if (rawText = "")
        return
    ; 💡 8 字符分片注入：防止长文本在游戏帧处理队列中溢出丢字
    chunkSize := 8
    pos := 1
    len := StrLen(rawText)
    while (pos <= len) {
        chunk := SubStr(rawText, pos, chunkSize)
        SendInput("{Text}" chunk)
        Sleep(5)
        pos += chunkSize
    }
}

; 💡 状态判定防护：只要 AHK 框开启 (isChatActive = true)，Enter/Esc 100% 绝对生效，防止卡死！
#HotIf isChatActive || WinActive("ahk_id " chatGui.Hwnd)
Enter:: SubmitText()
NumpadEnter:: SubmitText()
Escape:: CloseGui(true)

WheelUp:: ForwardScrollToGame("WheelUp")
WheelDown:: ForwardScrollToGame("WheelDown")
PgUp:: ForwardScrollToGame("WheelUp")
PgDn:: ForwardScrollToGame("WheelDown")

^!Left:: AdjustGuiPos(-10, 0)
^!Right:: AdjustGuiPos(10, 0)
^!Up:: AdjustGuiPos(0, -10)
^!Down:: AdjustGuiPos(0, 10)
#HotIf

AdjustGuiPos(deltaX, deltaY) {
    global OffsetX, OffsetY, chatGui, isAdjusting, editBox
    isAdjusting := true

    OffsetX := OffsetX - deltaX
    OffsetY := OffsetY - deltaY

    if WinExist("ahk_exe helldivers2.exe") {
        try {
            WinGetPos(&X, &Y, &W, &H, "ahk_exe helldivers2.exe")
            posX := X + W - OffsetX
            posY := Y + H - OffsetY
            LimitGuiPos(&posX, &posY)
            OffsetX := X + W - posX
            OffsetY := Y + H - posY

            chatGui.Move(posX, posY)
        } catch TargetError {
        }
    }

    editBox.Focus()
    SetEditCaret()
    SetTimer(OnAdjustTimeout, -200)
}

OnAdjustTimeout() {
    global isAdjusting, chatGui, OffsetX, OffsetY, iniPath
    isAdjusting := false

    try {
        IniWrite(String(OffsetX), iniPath, "Coordinates", "OffsetX")
        IniWrite(String(OffsetY), iniPath, "Coordinates", "OffsetY")
    } catch {
    }

    activeHwnd := WinActive("A")
    if (activeHwnd != chatGui.Hwnd) {
        CloseGui(false)
    }
}

#HotIf WinActive("ahk_exe helldivers2.exe")
F12:: Reload()
#HotIf