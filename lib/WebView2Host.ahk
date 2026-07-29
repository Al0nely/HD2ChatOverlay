; lib/WebView2Host.ahk - WebView2 Runtime 检测、Edge App 宿主与 HTTP 消息桥
; 方案: Edge --app 模式 + PowerShell HttpListener 桥接服务器

; -------------------------------------------------------------
; WebView2 Runtime 检测与自动安装
; -------------------------------------------------------------

class WebView2Runtime {
    static IsInstalled() {
        try {
            regPath := "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
            version := RegRead(regPath, "pv", "")
            if (version != "")
                return true
        }
        try {
            regPath := "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
            version := RegRead(regPath, "pv", "")
            if (version != "")
                return true
        }

        edgePaths := [
            EnvGet("ProgramFiles(x86)") "\Microsoft\Edge\Application\msedge.exe",
            EnvGet("ProgramFiles") "\Microsoft\Edge\Application\msedge.exe",
            EnvGet("LocalAppData") "\Microsoft\Edge\Application\msedge.exe"
        ]
        for _, path in edgePaths {
            if FileExist(path)
                return true
        }
        return false
    }

    static GetVersion() {
        try {
            regPath := "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
            return RegRead(regPath, "pv", "")
        } catch {
            try {
                regPath := "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
                return RegRead(regPath, "pv", "")
            } catch {
                return ""
            }
        }
    }

    static GetEdgePath() {
        edgePaths := [
            EnvGet("ProgramFiles(x86)") "\Microsoft\Edge\Application\msedge.exe",
            EnvGet("ProgramFiles") "\Microsoft\Edge\Application\msedge.exe",
            EnvGet("LocalAppData") "\Microsoft\Edge\Application\msedge.exe"
        ]
        for _, path in edgePaths {
            if FileExist(path)
                return path
        }
        return ""
    }

    static InstallSilent() {
        bootstrapperUrl := "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
        tempPath := A_Temp "\MicrosoftEdgeWebview2Setup.exe"

        WriteLog("[WebView2Runtime] 开始下载 Bootstrapper...")
        try {
            Download(bootstrapperUrl, tempPath)
        } catch Error as err {
            WriteLog("[WebView2Runtime] 下载失败: " err.Message)
            return false
        }

        if !FileExist(tempPath) {
            WriteLog("[WebView2Runtime] 下载文件不存在")
            return false
        }

        WriteLog("[WebView2Runtime] 下载完成,开始静默安装...")
        try {
            RunWait(tempPath " /silent /install", , "Hide")
        } catch Error as err {
            WriteLog("[WebView2Runtime] 安装失败: " err.Message)
            try FileDelete(tempPath)
            return false
        }

        try FileDelete(tempPath)

        if (this.IsInstalled()) {
            WriteLog("[WebView2Runtime] 安装成功,版本: " this.GetVersion())
            return true
        } else {
            WriteLog("[WebView2Runtime] 安装后验证失败")
            return false
        }
    }

    static EnsureAvailable() {
        if (this.IsInstalled()) {
            WriteLog("[WebView2Runtime] 已安装,版本: " this.GetVersion())
            return true
        }
        WriteLog("[WebView2Runtime] 未检测到 WebView2 Runtime,尝试自动安装...")
        return this.InstallSilent()
    }
}

; -------------------------------------------------------------
; HTTP 桥接服务器管理
; -------------------------------------------------------------

class BridgeServer {
    static Port := 0
    static Pid := 0
    static MsgDir := A_Temp "\HD2ChatOverlay_Bridge_" A_ScriptHwnd
    static _isRunning := false

    static Start() {
        if (this._isRunning)
            return true

        ; 清理旧消息目录
        try DirDelete(this.MsgDir, true)
        try DirCreate(this.MsgDir)

        ; 随机端口
        this.Port := 9280 + Random(0, 100)

        psScript := A_ScriptDir "\lib\WebView2Bridge.ps1"
        if !FileExist(psScript) {
            WriteLog("[BridgeServer] PowerShell 脚本不存在: " psScript)
            return false
        }

        ; 启动 PowerShell HTTP 服务器
        ; 使用 -File 参数,避免 -Command 的复杂转义
        psCommand := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"" psScript "`" -Port " this.Port " -RootDir `"" A_ScriptDir "`" -MsgDir `"" this.MsgDir "`""

        WriteLog("[BridgeServer] 启动: " psCommand)

        try {
            Run(psCommand, , "Hide", &pid)
            this.Pid := pid
        } catch Error as err {
            WriteLog("[BridgeServer] 启动失败: " err.Message)
            return false
        }

        ; 等待端口文件出现
        portFile := this.MsgDir "\bridge.port"
        startTime := A_TickCount
        while (A_TickCount - startTime < 5000) {
            if FileExist(portFile) {
                this._isRunning := true
                WriteLog("[BridgeServer] 启动成功,端口: " this.Port)
                return true
            }
            Sleep(100)
        }

        WriteLog("[BridgeServer] 等待端口文件超时")
        return false
    }

    static Stop() {
        if (this.Pid) {
            try ProcessClose(this.Pid)
            this.Pid := 0
        }
        this._isRunning := false
        try DirDelete(this.MsgDir, true)
        WriteLog("[BridgeServer] 已停止")
    }

    static IsRunning => this._isRunning
    static BaseUrl => "http://127.0.0.1:" this.Port
}

; -------------------------------------------------------------
; WebView2 宿主管理
; -------------------------------------------------------------

class WebView2Host {
    static _isInitialized := false
    static _initFailedCount := 0
    static _maxInitRetries := 3
    static _overlayInstance := ""
    static _configInstance := ""

    static Init() {
        if (this._isInitialized)
            return true

        if (!WebView2Runtime.EnsureAvailable()) {
            this._initFailedCount++
            WriteLog("[WebView2Host] Runtime 不可用,初始化失败 (" this._initFailedCount "/" this._maxInitRetries ")")
            return false
        }

        if (!BridgeServer.Start()) {
            this._initFailedCount++
            WriteLog("[WebView2Host] 桥接服务器启动失败 (" this._initFailedCount "/" this._maxInitRetries ")")
            return false
        }

        this._isInitialized := true
        WriteLog("[WebView2Host] 初始化成功")
        return true
    }

    static IsAvailable => this._isInitialized
    static ShouldFallback => (this._initFailedCount >= this._maxInitRetries)

    static CreateOverlay() {
        if (!this.Init())
            return ""

        if (this._overlayInstance)
            this._overlayInstance.Destroy()

        this._overlayInstance := WebView2HostInstance("overlay", "ui/overlay/index.html")
        return this._overlayInstance
    }

    static CreateConfigWindow() {
        if (!this.Init())
            return ""

        if (this._configInstance)
            this._configInstance.Destroy()

        this._configInstance := WebView2HostInstance("config", "ui/config/index.html")
        return this._configInstance
    }

    static GetOverlay() => this._overlayInstance
    static GetConfigWindow() => this._configInstance

    static Shutdown() {
        if (this._overlayInstance)
            this._overlayInstance.Destroy()
        if (this._configInstance)
            this._configInstance.Destroy()
        BridgeServer.Stop()
        this._overlayInstance := ""
        this._configInstance := ""
        this._isInitialized := false
        WriteLog("[WebView2Host] 已关闭")
    }
}

; -------------------------------------------------------------
; WebView2 宿主实例
; -------------------------------------------------------------

class WebView2HostInstance {
    __New(name, htmlPath) {
        this.Name := name
        this.HtmlPath := A_ScriptDir "\" htmlPath
        this.WindowTitle := "HD2ChatOverlay_" name "_" A_ScriptHwnd
        this.Hwnd := 0
        this.Pid := 0
        this.IsReady := false
        this._messageHandlers := Map()
        this._edgePath := WebView2Runtime.GetEdgePath()
        this._userDataDir := A_Temp "\HD2ChatOverlay_WebView2_" name

        try DirCreate(this._userDataDir)

        WriteLog("[WebView2HostInstance] 创建实例: " name)
    }

    ; 启动 Edge App 窗口
    Start() {
        if (!this._edgePath) {
            WriteLog("[WebView2HostInstance] Edge 路径未找到")
            return false
        }

        if !FileExist(this.HtmlPath) {
            WriteLog("[WebView2HostInstance] HTML 文件不存在: " this.HtmlPath)
            return false
        }

        ; 通过桥接服务器加载页面
        pageUrl := BridgeServer.BaseUrl "/" this.Name

        ; 构建 Edge 启动参数
        ; 注意: --app 参数的值需要用引号包裹,防止 URL 中的特殊字符被解析
        args := Format(
            '--app={1} --user-data-dir={2} --no-first-run --no-default-browser-check --disable-features=msHubApps,CalculateNativeWinOcclusion --disable-extensions --disable-plugins --disable-notifications --disable-popup-blocking --disable-background-networking --disable-sync --disable-translate --no-service-autorun',
            pageUrl,
            this._userDataDir
        )

        WriteLog("[WebView2HostInstance] 启动 Edge: " args)

        try {
            Run('"' this._edgePath '" ' args, , "Hide", &pid)
            this.Pid := pid
        } catch Error as err {
            WriteLog("[WebView2HostInstance] 启动失败: " err.Message)
            return false
        }

        ; 给 Edge 更多初始化时间
        Sleep(1000)

        if (!this._WaitForWindow(20000)) {
            WriteLog("[WebView2HostInstance] 等待窗口超时")
            return false
        }

        this._ApplyOverlayStyles()

        ; 启动消息轮询
        SetTimer(this._PollInbox.Bind(this), 30)

        WriteLog("[WebView2HostInstance] 启动成功,Hwnd: 0x" Format("{:X}", this.Hwnd))
        return true
    }

    _ApplyOverlayStyles() {
        if (!this.Hwnd || this.Name != "overlay")
            return

        try {
            hwnd := this.Hwnd
            ; GWL_STYLE = -16: 移除 WS_CAPTION (0x00C00000), WS_THICKFRAME (0x00040000), WS_MINIMIZEBOX, WS_MAXIMIZEBOX, WS_SYSMENU
            style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
            newStyle := style & ~0x00C00000 & ~0x00040000 & ~0x00020000 & ~0x00010000 & ~0x00080000
            DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", newStyle)

            ; GWL_EXSTYLE = -20: 添加 WS_EX_TOPMOST (0x00000008), WS_EX_TOOLWINDOW (0x00000080)
            exStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
            newExStyle := (exStyle | 0x00000008 | 0x00000080) & ~0x00040000
            DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", newExStyle)

            ; 强制刷新框架 SWP_NOMOVE(0x2) | SWP_NOSIZE(0x1) | SWP_NOZORDER(0x4) | SWP_FRAMECHANGED(0x20) = 0x27
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027)

            ; 禁用 DWM 窗口动画
            dwmDisableAnim := Buffer(4, 0)
            NumPut("Int", 1, dwmDisableAnim)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 3, "Ptr", dwmDisableAnim, "UInt", 4)

            WriteLog("[WebView2HostInstance] 已应用无边框置顶 overlay 样式")
        } catch Error as err {
            WriteLog("[WebView2HostInstance] 应用窗口样式失败: " err.Message)
        }
    }

    _WaitForWindow(timeoutMs) {
        startTime := A_TickCount
        while (A_TickCount - startTime < timeoutMs) {
            ; 方法1: 按 PID 查找 (可能找到多个窗口,取第一个可见的)
            try {
                for hwnd in WinGetList("ahk_pid " this.Pid) {
                    if (WinExist("ahk_id " hwnd)) {
                        style := WinGetStyle("ahk_id " hwnd)
                        ; 检查是否是顶层可见窗口
                        if (style & 0x10000000) {  ; WS_VISIBLE
                            this.Hwnd := hwnd
                            WriteLog("[WebView2HostInstance] 按 PID 找到窗口: 0x" Format("{:X}", hwnd))
                            return true
                        }
                    }
                }
            }

            ; 方法2: 按窗口标题模糊查找 (包括 URL 和页面标题)
            try {
                ; Edge --app 模式的标题可能是页面 title 或 URL
                titles := ["HD2 Chat Overlay", "127.0.0.1", "localhost"]
                for _, titlePattern in titles {
                    hwnd := WinExist(titlePattern)
                    if (hwnd) {
                        pid := WinGetPID("ahk_id " hwnd)
                        if (pid = this.Pid) {
                            this.Hwnd := hwnd
                            WriteLog("[WebView2HostInstance] 按标题 '" titlePattern "' 找到窗口: 0x" Format("{:X}", hwnd))
                            return true
                        }
                    }
                }
            }

            ; 方法3: 遍历所有 Edge 窗口,匹配 PID 和窗口类名
            try {
                for hwnd in WinGetList("ahk_exe msedge.exe") {
                    pid := WinGetPID("ahk_id " hwnd)
                    if (pid = this.Pid) {
                        ; 检查窗口类名 (Chrome_WidgetWin_1 是 Edge/Chrome 窗口类)
                        class := WinGetClass("ahk_id " hwnd)
                        if (InStr(class, "Chrome_WidgetWin")) {
                            this.Hwnd := hwnd
                            title := WinGetTitle("ahk_id " hwnd)
                            WriteLog("[WebView2HostInstance] 按进程找到窗口: 0x" Format("{:X}", hwnd) " 标题: " title " 类名: " class)
                            return true
                        }
                    }
                }
            }

            Sleep(300)
        }
        WriteLog("[WebView2HostInstance] 未找到窗口,超时")
        return false
    }

    ; 轮询 JS 发送的消息
    _PollInbox() {
        inboxPattern := BridgeServer.MsgDir "\inbox_*.json"
        try {
            loop files, inboxPattern, "F" {
                content := FileRead(A_LoopFileFullPath, "UTF-8")
                try FileDelete(A_LoopFileFullPath)

                if (content != "") {
                    this._HandleMessage(content)
                }
            }
        }
    }

    _HandleMessage(jsonStr) {
        WriteLog("[WebView2HostInstance] 收到消息: " jsonStr)

        ; 简单解析: 提取 type 和 payload
        if (RegExMatch(jsonStr, '"type"\s*:\s*"([^"]+)"', &typeMatch)) {
            msgType := typeMatch[1]

            payload := ""
            if (RegExMatch(jsonStr, '"payload"\s*:\s*(\{.*\}|\[.*\]|"[^"]*"|[0-9.]+|true|false|null)', &payloadMatch)) {
                payload := payloadMatch[1]
            }

            if (this._messageHandlers.Has(msgType)) {
                this._messageHandlers[msgType](payload)
            }

            if (msgType = "ready") {
                this.IsReady := true
            }
        }
    }

    ; 向 JS 发送消息 (写入队列文件, JS 通过 /api/poll 批量获取)
    PostMessage(json) {
        if (!BridgeServer.IsRunning)
            return

        try {
            outFile := BridgeServer.MsgDir "\outbox_" A_TickCount "_" Random(1000, 9999) ".json"
            FileAppend(json, outFile, "UTF-8")
        } catch Error as err {
            WriteLog("[WebView2HostInstance] PostMessage 错误: " err.Message)
        }
    }

    OnMessage(type, callback) {
        this._messageHandlers[type] := callback
    }

    AddHostObject(name, callback) {
        this._messageHandlers["call_" name] := callback
    }

    Show(x := -9999, y := -9999, w := 510, h := 120) {
        WriteLog("[WebView2HostInstance] Show: Hwnd=0x" Format("{:X}", this.Hwnd) " x=" x " y=" y)

        if (!this.Hwnd || !WinExist("ahk_id " this.Hwnd)) {
            WriteLog("[WebView2HostInstance] Show: 窗口无效或不存在, 重新启动 Edge...")
            this.Hwnd := 0
            this.IsReady := false
            if (!this.Start()) {
                WriteLog("[WebView2HostInstance] Show: 重新启动失败")
                return
            }
        }

        this._ApplyOverlayStyles()

        try {
            if (x != -9999 && y != -9999)
                WinMove(x, y, w, h, "ahk_id " this.Hwnd)
            WinShow("ahk_id " this.Hwnd)
            WinActivate("ahk_id " this.Hwnd)
            WriteLog("[WebView2HostInstance] Show: 窗口已显示")
        } catch Error as err {
            WriteLog("[WebView2HostInstance] Show 错误: " err.Message)
        }
    }

    Hide() {
        if (!this.Hwnd || !WinExist("ahk_id " this.Hwnd)) {
            WriteLog("[WebView2HostInstance] Hide: 窗口句柄无效")
            return
        }
        try {
            WinHide("ahk_id " this.Hwnd)
        } catch Error as err {
            WriteLog("[WebView2HostInstance] Hide 错误: " err.Message)
        }
    }

    Move(x, y) {
        if (!this.Hwnd || !WinExist("ahk_id " this.Hwnd)) {
            WriteLog("[WebView2HostInstance] Move: 窗口句柄无效")
            return
        }
        try {
            WinMove(x, y, , , "ahk_id " this.Hwnd)
        } catch Error as err {
            WriteLog("[WebView2HostInstance] Move 错误: " err.Message)
        }
    }

    Resize(w, h) {
        if (!this.Hwnd)
            return
        WinMove( , , w, h, "ahk_id " this.Hwnd)
    }

    Destroy() {
        SetTimer(this._PollInbox.Bind(this), 0)
        if (this.Hwnd) {
            try WinClose("ahk_id " this.Hwnd)
            Sleep(500)
        }
        if (this.Pid) {
            try ProcessClose(this.Pid)
        }
        this.Hwnd := 0
        this.Pid := 0
        this.IsReady := false
        WriteLog("[WebView2HostInstance] 已销毁: " this.Name)
    }
}
