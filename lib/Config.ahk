; lib/Config.ahk - 配置管理与 INI 持久化
; 配置节: [Coordinates], [Injection], [Debug], [UI], [Mode], [Translation], [Hotkeys]

class AppConfig {
    static iniPath := A_ScriptDir "\hd2_chat_settings.ini"
    static backupCount := 3

    ; 坐标配置
    static OffsetX := 840
    static OffsetY := 638

    ; 注入配置
    static ChunkSize := 1
    static ChunkDelay := 15

    ; 调试配置
    static EnableDebugLog := true

    ; UI 配置
    static FontName := "SimHei"
    static FontSize := 16
    static OverlayWidth := 640
    static OverlayHeight := 58

    ; 模式配置
    static GlobalTestMode := false

    ; AI 翻译配置
    static EnableAutoTranslate := false
    static ApiBase := "https://openrouter.ai/api/v1"
    static ApiKey := ""
    static Model := "google/gemini-2.5-flash"
    static TargetLanguage := "English"

    ; 术语库配置 ([Translation] 节)
    static EnableGlossary := true
    static EnablePythonScraper := true
    static GlossaryUrl := "https://raw.githubusercontent.com/Al0nely/HD2ChatOverlay/main/assets/glossary.core.json"
    static GlossaryLocalPath := A_ScriptDir "\assets\glossary.core.json"

    ; 快捷键配置 ([Hotkeys] 节, AHK 热键语法: ^=Ctrl !=Alt +=Shift)
    static TranslateKey := "!t"
    static SwitchSourceKey := "^Tab"

    ; 从 INI 加载全部配置
    static Load() {
        this.OffsetX := this._ReadInt("Coordinates", "OffsetX", 840)
        this.OffsetY := this._ReadInt("Coordinates", "OffsetY", 638)
        this.ChunkSize := this._ReadInt("Injection", "ChunkSize", 1)
        this.ChunkDelay := this._ReadInt("Injection", "ChunkDelay", 15)
        this.EnableDebugLog := this._ReadBool("Debug", "EnableDebugLog", true)
        this.FontName := this._ReadStr("UI", "FontName", "SimHei")
        this.FontSize := this._ReadInt("UI", "FontSize", 16)
        this.OverlayWidth := this._ReadInt("UI", "OverlayWidth", 640)
        this.OverlayHeight := this._ReadInt("UI", "OverlayHeight", 58)
        this.GlobalTestMode := this._ReadBool("Mode", "GlobalTestMode", false)
        this.EnableAutoTranslate := this._ReadBool("Translation", "EnableAutoTranslate", false)
        this.ApiBase := this._ReadStr("Translation", "ApiBase", "https://openrouter.ai/api/v1")
        this.ApiKey := this._ReadStr("Translation", "ApiKey", "")
        this.Model := this._ReadStr("Translation", "Model", "google/gemini-2.5-flash")
        this.TargetLanguage := this._ReadStr("Translation", "TargetLanguage", "English")
        this.EnableGlossary := this._ReadBool("Translation", "EnableGlossary", true)
        this.EnablePythonScraper := this._ReadBool("Translation", "EnablePythonScraper", true)
        this.GlossaryUrl := this._ReadStr("Translation", "GlossaryUrl", "https://raw.githubusercontent.com/Al0nely/HD2ChatOverlay/main/assets/glossary.core.json")
        this.GlossaryLocalPath := this._ReadStr("Translation", "GlossaryLocalPath", A_ScriptDir "\assets\glossary.core.json")
        this.TranslateKey := this._ReadStr("Hotkeys", "TranslateKey", "!t")
        this.SwitchSourceKey := this._ReadStr("Hotkeys", "SwitchSourceKey", "^Tab")
    }

    ; 保存全部配置到 INI (自动备份)
    static Save() {
        this._CreateBackup()

        try {
            IniWrite(String(this.OffsetX), this.iniPath, "Coordinates", "OffsetX")
            IniWrite(String(this.OffsetY), this.iniPath, "Coordinates", "OffsetY")
            IniWrite(String(this.ChunkSize), this.iniPath, "Injection", "ChunkSize")
            IniWrite(String(this.ChunkDelay), this.iniPath, "Injection", "ChunkDelay")
            IniWrite(this.EnableDebugLog ? "1" : "0", this.iniPath, "Debug", "EnableDebugLog")
            IniWrite(this.FontName, this.iniPath, "UI", "FontName")
            IniWrite(String(this.FontSize), this.iniPath, "UI", "FontSize")
            IniWrite(String(this.OverlayWidth), this.iniPath, "UI", "OverlayWidth")
            IniWrite(String(this.OverlayHeight), this.iniPath, "UI", "OverlayHeight")
            IniWrite(this.GlobalTestMode ? "1" : "0", this.iniPath, "Mode", "GlobalTestMode")
            IniWrite(this.EnableAutoTranslate ? "1" : "0", this.iniPath, "Translation", "EnableAutoTranslate")
            IniWrite(this.ApiBase, this.iniPath, "Translation", "ApiBase")
            IniWrite(this.ApiKey, this.iniPath, "Translation", "ApiKey")
            IniWrite(this.Model, this.iniPath, "Translation", "Model")
            IniWrite(this.TargetLanguage, this.iniPath, "Translation", "TargetLanguage")
            IniWrite(this.EnableGlossary ? "1" : "0", this.iniPath, "Translation", "EnableGlossary")
            IniWrite(this.EnablePythonScraper ? "1" : "0", this.iniPath, "Translation", "EnablePythonScraper")
            IniWrite(this.GlossaryUrl, this.iniPath, "Translation", "GlossaryUrl")
            IniWrite(this.GlossaryLocalPath, this.iniPath, "Translation", "GlossaryLocalPath")
            IniWrite(this.TranslateKey, this.iniPath, "Hotkeys", "TranslateKey")
            IniWrite(this.SwitchSourceKey, this.iniPath, "Hotkeys", "SwitchSourceKey")
        } catch Error as err {
            WriteLog("[Config] 保存失败: " err.Message)
        }
    }

    ; 恢复默认配置
    static ResetDefaults() {
        this.OffsetX := 840
        this.OffsetY := 638
        this.ChunkSize := 1
        this.ChunkDelay := 15
        this.EnableDebugLog := false
        this.FontName := "SimHei"
        this.FontSize := 16
        this.OverlayWidth := 640
        this.OverlayHeight := 58
        this.GlobalTestMode := false
        this.EnableAutoTranslate := false
        this.ApiBase := "https://openrouter.ai/api/v1"
        this.ApiKey := ""
        this.Model := "google/gemini-2.5-flash"
        this.TargetLanguage := "English"
        this.EnableGlossary := true
        this.EnablePythonScraper := true
        this.GlossaryUrl := "https://raw.githubusercontent.com/Al0nely/HD2ChatOverlay/main/assets/glossary.core.json"
        this.GlossaryLocalPath := A_ScriptDir "\assets\glossary.core.json"
        this.TranslateKey := "!t"
        this.SwitchSourceKey := "^Tab"
    }

    ; 创建配置备份 (滚动保留最近 N 份)
    static _CreateBackup() {
        if !FileExist(this.iniPath)
            return

        try {
            ; 滚动备份: .bak.2 -> .bak.3, .bak.1 -> .bak.2, .bak -> .bak.1
            loop this.backupCount - 1 {
                src := this.iniPath ".bak." (this.backupCount - A_Index)
                dst := this.iniPath ".bak." (this.backupCount - A_Index + 1)
                if FileExist(src)
                    FileMove(src, dst, true)
            }

            ; 当前配置 -> .bak
            FileCopy(this.iniPath, this.iniPath ".bak", true)
        } catch Error as err {
            WriteLog("[Config] 备份失败: " err.Message)
        }
    }

    ; 回滚到最近备份
    static Rollback() {
        backupPath := this.iniPath ".bak"
        if !FileExist(backupPath) {
            WriteLog("[Config] 无备份可回滚")
            return false
        }

        try {
            FileCopy(backupPath, this.iniPath, true)
            this.Load()
            WriteLog("[Config] 已回滚到备份配置")
            return true
        } catch Error as err {
            WriteLog("[Config] 回滚失败: " err.Message)
            return false
        }
    }

    ; 检查是否存在备份
    static HasBackup() {
        return FileExist(this.iniPath ".bak")
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
