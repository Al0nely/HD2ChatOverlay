; lib/Config.ahk - 配置管理与 INI 持久化
; 配置节: [Coordinates], [Injection], [Debug], [UI], [Mode]

class AppConfig {
    static iniPath := A_ScriptDir "\hd2_chat_settings.ini"

    ; 坐标配置
    static OffsetX := 840
    static OffsetY := 638

    ; 注入配置
    static ChunkSize := 8
    static ChunkDelay := 5

    ; 调试配置
    static EnableDebugLog := false

    ; UI 配置
    static FontName := "SimHei"
    static FontSize := 18

    ; 模式配置
    static GlobalTestMode := false

    ; 从 INI 加载全部配置
    static Load() {
        this.OffsetX := this._ReadInt("Coordinates", "OffsetX", 840)
        this.OffsetY := this._ReadInt("Coordinates", "OffsetY", 638)
        this.ChunkSize := this._ReadInt("Injection", "ChunkSize", 8)
        this.ChunkDelay := this._ReadInt("Injection", "ChunkDelay", 5)
        this.EnableDebugLog := this._ReadBool("Debug", "EnableDebugLog", false)
        this.FontName := this._ReadStr("UI", "FontName", "SimHei")
        this.FontSize := this._ReadInt("UI", "FontSize", 18)
        this.GlobalTestMode := this._ReadBool("Mode", "GlobalTestMode", false)
    }

    ; 保存全部配置到 INI
    static Save() {
        try {
            IniWrite(String(this.OffsetX), this.iniPath, "Coordinates", "OffsetX")
            IniWrite(String(this.OffsetY), this.iniPath, "Coordinates", "OffsetY")
            IniWrite(String(this.ChunkSize), this.iniPath, "Injection", "ChunkSize")
            IniWrite(String(this.ChunkDelay), this.iniPath, "Injection", "ChunkDelay")
            IniWrite(this.EnableDebugLog ? "1" : "0", this.iniPath, "Debug", "EnableDebugLog")
            IniWrite(this.FontName, this.iniPath, "UI", "FontName")
            IniWrite(String(this.FontSize), this.iniPath, "UI", "FontSize")
            IniWrite(this.GlobalTestMode ? "1" : "0", this.iniPath, "Mode", "GlobalTestMode")
        } catch Error as err {
            WriteLog("[Config] 保存失败: " err.Message)
        }
    }

    ; 恢复默认配置
    static ResetDefaults() {
        this.OffsetX := 840
        this.OffsetY := 638
        this.ChunkSize := 8
        this.ChunkDelay := 5
        this.EnableDebugLog := false
        this.FontName := "SimHei"
        this.FontSize := 18
        this.GlobalTestMode := false
    }

    static _ReadInt(section, key, defaultVal) {
        valStr := IniRead(this.iniPath, section, key, String(defaultVal))
        try {
            return Integer(valStr)
        } catch {
            return defaultVal
        }
    }

    static _ReadBool(section, key, defaultVal) {
        valStr := IniRead(this.iniPath, section, key, defaultVal ? "1" : "0")
        return (valStr = "1" || valStr = "true")
    }

    static _ReadStr(section, key, defaultVal) {
        return IniRead(this.iniPath, section, key, defaultVal)
    }
}
