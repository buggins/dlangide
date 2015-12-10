module dlangide.workspace.idesettings;

import dlangui.core.settings;
import dlangui.core.i18n;
import dlangui.graphics.fonts;

const AVAILABLE_THEMES = ["ide_theme_default", "ide_theme_dark"];
const AVAILABLE_LANGUAGES = ["en", "ru", "es"];

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
        Setting ui = uiSettings();
        ui.setStringDef("theme", "ide_theme_default");
        ui.setStringDef("language", "en");
        ui.setIntegerDef("hintingMode", 1);
        ui.setIntegerDef("minAntialiasedFontSize", 0);
        ui.setFloatingDef("fontGamma", 0.8);
        debuggerSettings.setStringDef("executable", "gdb");
        terminalSettings.setStringDef("executable", "xterm");
        dubSettings.setStringDef("executable", "dub");
        dubSettings.setStringDef("additional_params", "");
        dmdToolchainSettings.setStringDef("executable", "dmd");
        ldcToolchainSettings.setStringDef("executable", "ldc2");
        gdcToolchainSettings.setStringDef("executable", "gdc");
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

    @property Setting dmdToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/dmd", true);
        return res;
    }

    @property Setting ldcToolchainSettings() {
        Setting res = _setting.objectByPath("dlang/toolchains/ldc", true);
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
        return debuggerSettings.getString("executable", "gdb");
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

    string getToolchainSettings(string toolchainName) {
        if (toolchainName.equal("dmd"))
            return dmdToolchainSettings.getString("executable", "dmd");
        if (toolchainName.equal("gdc"))
            return dmdToolchainSettings.getString("executable", "gdc");
        if (toolchainName.equal("ldc"))
            return dmdToolchainSettings.getString("executable", "ldc2");
        return null;
    }

}

