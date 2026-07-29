; test/TestWithNotepad.ahk - 记事本模拟测试脚本
; 用于在无游戏环境下测试悬浮窗功能

#Requires AutoHotkey v2.0

; 启动记事本
Run("notepad.exe")
WinWait("ahk_exe notepad.exe", , 5)
if !WinExist("ahk_exe notepad.exe") {
    MsgBox("无法启动记事本")
    ExitApp()
}

WinActivate("ahk_exe notepad.exe")
WinMove(100, 100, 800, 600, "ahk_exe notepad.exe")

MsgBox(
    "记事本已启动,用于模拟游戏窗口。`n`n"
    "测试步骤:`n"
    "1. 确保 HD2 Chat Overlay 已运行 (托盘图标)`n"
    "2. 确保已开启 '全局测试模式'`n"
    "3. 在记事本窗口按 Enter 唤醒悬浮窗`n"
    "4. 输入中文文本,按 Enter 发送`n"
    "5. 检查文本是否正确注入到记事本`n`n"
    "按确定关闭此提示...",
    "HD2 Chat Overlay - 测试模式",
    "Icon!"
)

; 保持脚本运行,等待用户测试
Persistent()
