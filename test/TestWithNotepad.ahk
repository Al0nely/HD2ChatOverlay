#Requires AutoHotkey v2.0
#SingleInstance Force

; -------------------------------------------------------------
; test/TestWithNotepad.ahk - 使用记事本模拟游戏窗口进行测试
; 用法: 先启动本脚本,再启动主程序 hd2_chat.ahk
; 主程序的全局测试模式需开启(托盘菜单 -> 全局测试模式)
; -------------------------------------------------------------

; 启动记事本作为模拟游戏窗口
Run("notepad.exe")
Sleep(1000)

; 获取记事本窗口句柄
notepadHwnd := WinExist("ahk_exe notepad.exe")
if (!notepadHwnd) {
    MsgBox("无法启动记事本,测试失败", "Test Error", "IconX")
    ExitApp()
}

; 激活记事本窗口
WinActivate("ahk_id " notepadHwnd)
WinWaitActive("ahk_id " notepadHwnd, , 2)

; 显示测试说明
testGui := Gui("+AlwaysOnTop +ToolWindow", "HD2 Chat Overlay - 测试模式")
testGui.BackColor := "1E1E1E"
testGui.SetFont("s10 cFFFFFF", "Segoe UI")
testGui.AddText("w400", "测试步骤:`n`n"
    "1. 确保主程序 hd2_chat.ahk 已启动`n"
    "2. 确保托盘菜单中已开启 '全局测试模式'`n"
    "3. 保持记事本窗口处于激活状态`n"
    "4. 按 Enter 键测试悬浮窗唤醒`n"
    "5. 输入文本后按 Enter 测试提交`n"
    "6. 按 Esc 测试取消`n"
    "7. 按 Ctrl+Alt+方向键测试位置调整`n`n"
    "按 Ctrl+Shift+Q 退出测试")
testGui.AddButton("w100 h30", "关闭说明").OnEvent("Click", (*) => testGui.Hide())
testGui.Show("x100 y100")

; 快捷键: Ctrl+Shift+Q 退出测试
^+q:: {
    testGui.Destroy()
    WinClose("ahk_id " notepadHwnd)
    ExitApp()
}

; 保持脚本运行
Persistent()
