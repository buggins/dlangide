module dlangide.ui.settings;

import dlangui.core.settings;
import dlangui.core.i18n;
import dlangui.graphics.fonts;
import dlangui.widgets.lists;
import dlangui.dialogs.settingsdialog;


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

    static int limitInt(long value, int minvalue, int maxvalue) {
        if (value < minvalue)
            return minvalue;
        else if (value > maxvalue)
            return maxvalue;
        return cast(int)value;
    }

    static string limitString(string value, const string[] values) {
        assert(values.length > 0);
        foreach(v; values)
            if (v.equal(value))
                return value;
        return values[0];
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

}

/// create DlangIDE settings pages tree
SettingsPage createSettingsPages() {
    SettingsPage res = new SettingsPage("", UIString(""d));
    SettingsPage ed = res.addChild("editors", UIString("Editors"d));
    SettingsPage texted = ed.addChild("editors/textEditor", UIString("Text Editors"d));
    texted.addNumberEdit("editors/textEditor/tabSize", UIString("Tab size"d), 1, 16, 4);
    texted.addCheckbox("editors/textEditor/useSpacesForTabs", UIString("Use spaces for tabs"d));
    texted.addCheckbox("editors/textEditor/smartIndents", UIString("Smart indents"d));
    texted.addCheckbox("editors/textEditor/smartIndentsAfterPaste", UIString("Smart indent after paste"d));
    SettingsPage ui = res.addChild("interface", UIString("Interface"d));
    ui.addStringComboBox("interface/theme", UIString("Theme"d), [
            StringListValue("ide_theme_default", "Default"d), 
            StringListValue("ide_theme_dark", "Dark"d)]);
	ui.addStringComboBox("interface/language", UIString("Language"d), [
			StringListValue("en", "English"d), 
			StringListValue("ru", "Russian"d), 
			StringListValue("es", "Spanish"d)]);
    ui.addIntComboBox("interface/hintingMode", UIString("Font hinting mode"d), [StringListValue(0, "Normal"d), StringListValue(1, "Force Auto Hint"d), 
                StringListValue(2, "Disabled"d), StringListValue(3, "Light"d)]);
    ui.addIntComboBox("interface/minAntialiasedFontSize", UIString("Minimum font size for antialiasing"d), 
                      [StringListValue(0, "Always ON"d), 
                      StringListValue(12, "12"d), 
                      StringListValue(14, "14"d), 
                      StringListValue(16, "16"d), 
                      StringListValue(20, "20"d), 
                      StringListValue(24, "24"d), 
                      StringListValue(32, "32"d), 
                      StringListValue(48, "48"d), 
                      StringListValue(255, "Always OFF"d)]);
    ui.addFloatComboBox("interface/fontGamma", UIString("Font gamma"d), 
                   [
                    StringListValue(500,  "0.5   "d),
                    StringListValue(600,  "0.6   "d),
                    StringListValue(700,  "0.7   "d),
                    StringListValue(800,  "0.8   "d),
                    StringListValue(850,  "0.85  "d),
                    StringListValue(900,  "0.9   "d),
                    StringListValue(950,  "0.95  "d),
                    StringListValue(1000, "1.0   "d),
                    StringListValue(1050, "1.05  "d),
                    StringListValue(1100, "1.1   "d), 
                    StringListValue(1150, "1.15  "d), 
                    StringListValue(1200, "1.2   "d), 
                    StringListValue(1250, "1.25  "d), 
                    StringListValue(1300, "1.3   "d), 
                    StringListValue(1400, "1.4   "d), 
                    StringListValue(1500, "1.5   "d), 
                    StringListValue(1700, "1.7   "d), 
                    StringListValue(2000, "2.0   "d)]);
    return res;
}
