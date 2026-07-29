; lib/Tray.ahk - 系统托盘菜单系统

global SCRIPT_VERSION := "1.0.0"

InitTrayMenu() {
    ; 清空默认菜单
    A_TrayMenu.Delete()

    ; 标题项
    A_TrayMenu.Add("HD2 Chat Overlay v" SCRIPT_VERSION, _TrayNoop)
    A_TrayMenu.Disable("HD2 Chat Overlay v" SCRIPT_VERSION)
    A_TrayMenu.Add() ; 分隔线

    ; 配置窗口
    A_TrayMenu.Add("⚙️ 打开配置窗口", _TrayOpenConfig)

    ; 全局测试模式开关
    A_TrayMenu.Add("🧪 全局测试模式", _TrayToggleTestMode)
    if (AppConfig.GlobalTestMode)
        A_TrayMenu.Check("🧪 全局测试模式")

    ; 位置调整模式提示
    A_TrayMenu.Add("📐 位置调整: Ctrl+Alt+方向键", _TrayNoop)
    A_TrayMenu.Disable("📐 位置调整: Ctrl+Alt+方向键")

    A_TrayMenu.Add() ; 分隔线

    ; 关于
    A_TrayMenu.Add("ℹ️ 关于", _TrayAbout)

    ; 退出
    A_TrayMenu.Add("🚪 退出", _TrayExit)

    ; 默认双击行为
    A_TrayMenu.Default := "⚙️ 打开配置窗口"

    ; 托盘图标提示
    A_IconTip := "HD2 Chat Overlay v" SCRIPT_VERSION "`n在游戏中按 Enter 唤醒输入框"
}

_TrayNoop(*) {
    ; 无操作
}

_TrayOpenConfig(*) {
    ShowConfigGui()
}

_TrayToggleTestMode(*) {
    AppConfig.GlobalTestMode := !AppConfig.GlobalTestMode
    if (AppConfig.GlobalTestMode) {
        A_TrayMenu.Check("🧪 全局测试模式")
        TrayTip("测试模式已开启", "按 Enter 可在任意窗口唤醒输入框", 1)
    } else {
        A_TrayMenu.Uncheck("🧪 全局测试模式")
        TrayTip("测试模式已关闭", "仅在《绝地潜兵 2》中响应 Enter", 1)
    }
    AppConfig.Save()
}

_TrayAbout(*) {
    MsgBox(
        "HD2 Chat Overlay v" SCRIPT_VERSION "`n`n"
        "《绝地潜兵 2》中文输入悬浮窗插件`n`n"
        "快捷键:`n"
        "  Enter - 唤醒输入框`n"
        "  Enter - 发送文本`n"
        "  Esc - 取消输入`n"
        "  Ctrl+Alt+方向键 - 调整窗口位置`n"
        "  滚轮/PgUp/PgDn - 滚动聊天记录`n`n"
        "配置保存于: hd2_chat_settings.ini",
        "关于 HD2 Chat Overlay",
        "Iconi"
    )
}

_TrayExit(*) {
    ReleaseSingleInstance()
    ExitApp()
}
