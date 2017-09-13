module dlangide.workspace.idesettings;

import dlangui.core.settings;
import dlangui.core.i18n;
import dlangui.graphics.fonts;

import std.algorithm : equal;

const AVAILABLE_THEMES = ["ide_theme_default", "ide_theme_dark"];
const AVAILABLE_LANGUAGES = ["en", "ru", "es", "cs"];

class IDESettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    override void updateDefaults() {
        Setting ed = editorSettings();
        ed.setBooleanDef("useSpacesForTabs", true);
        ed.setIntegerDef("tabSize", 4);
        ed.setBooleanDef("smartIndents", true);
        ed.setBooleanDef("smartIndentsAfterPaste", true);
        ed.setBooleanDef("showWhiteSpaceMarks", true);
        ed.setBooleanDef("showTabPositionMarks", true);
        ed.setStringDef("fontFace", "Default");
        ed.setIntegerDef("fontSize", 11);
        Setting ui = uiSettings();
        ui.setStringDef("theme", "ide_theme_default");
        ui.setStringDef("language", "en");
        ui.setIntegerDef("hintingMode", 1);
        ui.setIntegerDef("minAntialiasedFontSize", 0);
        ui.setFloatingDef("fontGamma", 0.8);
        ui.setStringDef("uiFontFace", "Default");
        ui.setIntegerDef("uiFontSize", 10);
        version (Windows) {
            debuggerSettings.setStringDef("executable", "mago-mi");
        } else {
            debuggerSettings.setStringDef("executable", "gdb");
        }
        terminalSettings.setStringDef("executable", "xterm");
        dubSettings.setStringDef("executable", "dub");
        dubSettings.setStringDef("additional_params", "");
        rdmdSettings.setStringDef("executable", "rdmd");
        rdmdSettings.setStringDef("additional_params", "");
        dmdToolchainSettings.setStringDef("executable", "dmd");
        dmdToolchainSettings.setStringDef("dub_additional_params", "");
        ldcToolchainSettings.setStringDef("executable", "ldc2");
        ldcToolchainSettings.setStringDef("dub_additional_params", "");
        ldmdToolchainSettings.setStringDef("executable", "ldmd2");
        ldmdToolchainSettings.setStringDef("dub_additional_params", "");
        gdcToolchainSettings.setStringDef("executable", "gdc");
        gdcToolchainSettings.setStringDef("dub_additional_params", "");
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
    }
    
    @property Setting editorSettings() {
        Setting res = _setting.objectByPath("editors/textEditor", true);
        return res;
    }

    @property Setting uiSettings() {
        Setting res = _setting.objectByPath("interface", true);
        return res;
    }

    @property Setting debuggerSettings() {
        Setting res = _setting.objectByPath("dlang/debugger", true);
        return res;
    }

    @property Setting terminalSettings() {
        Setting res = _setting.objectByPath("dlang/terminal", true);
        return res;
    }

    @property Setting dubSettings() {
        Setting res = _setting.objectByPath("dlang/dub", true);
        return res;
    }

    @property Setting rdmdSettings() {
        Setting res = _setting.objectByPath("dlang/rdmd", true);
        return res;
    }

    @property Setting dmdToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/dmd", true);
        return res;
    }

    @property Setting ldcToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/ldc", true);
        return res;
    }

    @property Setting ldmdToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/ldmd", true);
        return res;
    }

    @property Setting gdcToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/gdc", true);
        return res;
    }

    /// theme
    @property string uiTheme() {
        return limitString(uiSettings.getString("theme", "ide_theme_default"), AVAILABLE_THEMES);
    }
    /// theme
    @property IDESettings uiTheme(string v) {
        uiSettings.setString("theme", limitString(v, AVAILABLE_THEMES));
        return this;
    }

    /// language
    @property string uiLanguage() {
        return limitString(uiSettings.getString("language", "en"), AVAILABLE_LANGUAGES);
    }
    /// language
    @property IDESettings uiLanguage(string v) {
        uiSettings.setString("language", limitString(v, AVAILABLE_LANGUAGES));
        return this;
    }

    /// UI font face
    @property string uiFontFace() {
        return uiSettings.getString("uiFontFace", "Default");
    }

    /// UI font size
    @property int uiFontSize() {
        return pointsToPixels(cast(int)uiSettings.getInteger("uiFontSize", 10));
    }

    /// text editor setting, true if need to insert spaces instead of tabs
    @property bool useSpacesForTabs() {
        return editorSettings.getBoolean("useSpacesForTabs", true);
    }
    /// text editor setting, true if need to insert spaces instead of tabs
    @property IDESettings useSpacesForTabs(bool v) {
        editorSettings.setBoolean("useSpacesForTabs", v);
        return this;
    }

    /// text editor setting, true if need to insert spaces instead of tabs
    @property int tabSize() {
        return limitInt(editorSettings.getInteger("tabSize", 4), 1, 16);
    }
    /// text editor setting, true if need to insert spaces instead of tabs
    @property IDESettings tabSize(int v) {
        editorSettings.setInteger("tabSize", limitInt(v, 1, 16));
        return this;
    }

    /// true if smart indents are enabled
    @property bool smartIndents() { return editorSettings.getBoolean("smartIndents", true); }
    /// set smart indents enabled flag
    @property IDESettings smartIndents(bool enabled) { editorSettings.setBoolean("smartIndents", enabled); return this; }

    /// true if white space marks are enabled
    @property bool showWhiteSpaceMarks() { return editorSettings.getBoolean("showWhiteSpaceMarks", true); }
    /// set white space marks enabled flag
    @property IDESettings showWhiteSpaceMarks(bool enabled) { editorSettings.setBoolean("showWhiteSpaceMarks", enabled); return this; }

    /// true if tab position marks are enabled
    @property bool showTabPositionMarks() { return editorSettings.getBoolean("showTabPositionMarks", true); }
    /// set tab position marks enabled flag
    @property IDESettings showTabPositionMarks(bool enabled) { editorSettings.setBoolean("showTabPositionMarks", enabled); return this; }
    /// string value of font face in text editors
    @property string editorFontFace() { return editorSettings.getString("fontFace", "Default"); }
    /// int value of font size in text editors
    @property int editorFontSize() { return cast(int)editorSettings.getInteger("fontSize", 11); }

    /// true if smart indents are enabled
    @property bool smartIndentsAfterPaste() { return editorSettings.getBoolean("smartIndentsAfterPaste", true); }
    /// set smart indents enabled flag
    @property IDESettings smartIndentsAfterPaste(bool enabled) { editorSettings.setBoolean("smartIndentsAfterPaste", enabled); return this; }

    @property double fontGamma() {
        double gamma = uiSettings.getFloating("fontGamma", 1.0);
        if (gamma >= 0.5 && gamma <= 2.0)
            return gamma;
        return 1.0;
    }

    @property HintingMode hintingMode() {
        long mode = uiSettings.getInteger("hintingMode", HintingMode.Normal);
        if (mode >= HintingMode.Normal && mode <= HintingMode.Light)
            return cast(HintingMode)mode;
        return HintingMode.Normal;
    }

    @property int minAntialiasedFontSize() {
        long sz = uiSettings.getInteger("minAntialiasedFontSize", 0);
        if (sz >= 0)
            return cast(int)sz;
        return 0;
    }

    @property string debuggerExecutable() {
        version (Windows) {
            return debuggerSettings.getString("executable", "mago-mi");
        } else {
            return debuggerSettings.getString("executable", "gdb");
        }
    }

    @property string terminalExecutable() {
        return terminalSettings.getString("executable", "xterm");
    }

    @property string dubExecutable() {
        return dubSettings.getString("executable", "dub");
    }

    @property string dubAdditionalParams() {
        return dubSettings.getString("additional_params", "");
    }

    @property string rdmdExecutable() {
        return rdmdSettings.getString("executable", "rdmd");
    }

    @property string rdmdAdditionalParams() {
        return rdmdSettings.getString("additional_params", "");
    }

    string getToolchainCompilerExecutable(string toolchainName) {
        if (toolchainName.equal("dmd"))
            return dmdToolchainSettings.getString("executable", "dmd");
        if (toolchainName.equal("gdc"))
            return gdcToolchainSettings.getString("executable", "gdc");
        if (toolchainName.equal("ldc"))
            return ldcToolchainSettings.getString("executable", "ldc2");
        if (toolchainName.equal("ldmd"))
            return ldmdToolchainSettings.getString("executable", "ldmd2");
        return null;
    }

    string getToolchainAdditionalDubParams(string toolchainName) {
        if (toolchainName.equal("dmd"))
            return dmdToolchainSettings.getString("dub_additional_params", "");
        if (toolchainName.equal("gdc"))
            return gdcToolchainSettings.getString("dub_additional_params", "");
        if (toolchainName.equal("ldc"))
            return ldcToolchainSettings.getString("dub_additional_params", "");
        if (toolchainName.equal("ldmd"))
            return ldmdToolchainSettings.getString("dub_additional_params", "");
        return null;
    }

    /// get recent path for category name, returns null if not found
    @property string getRecentPath(string category = "FILE_OPEN_DLG_PATH") {
        Setting obj = _setting.objectByPath("pathHistory", true);
        return obj.getString(category, null);
    }

    /// set recent path for category name
    @property void setRecentPath(string value, string category = "FILE_OPEN_DLG_PATH") {
        Setting obj = _setting.objectByPath("pathHistory", true);
        obj.setString(category, value);
        save();
    }

    @property string[] recentWorkspaces() {
        import std.file;
        Setting obj = _setting.objectByPath("history", true);
        string[] list = obj.getStringArray("recentWorkspaces");
        string[] res;
        foreach(fn; list) {
            if (exists(fn) && isFile(fn))
                res ~= fn;
        }
        return res;
    }

    void updateRecentWorkspace(string ws) {
        import std.file;
        string[] list;
        list ~= ws;
        string[] existing = recentWorkspaces;
        foreach(fn; existing) {
            if (exists(fn) && isFile(fn) && !ws.equal(fn))
                list ~= fn;
        }
        Setting obj = _setting.objectByPath("history", true);
        obj["recentWorkspaces"] = list;
        save();
    }
    
    @property bool autoOpenLastProject() {
        Setting obj =_setting.objectByPath("common", true);
        return obj.getBoolean("autoOpenLastProject", false);
    }

    @property void autoOpenLastProject(bool value) {
        Setting obj =_setting.objectByPath("common", true);
        obj.setBoolean("autoOpenLastProject", value);
    }

    /// for saving window state, position, and other UI states
    @property Setting uiState() {
        return _setting.objectByPath("uiState", true);
    }
}

