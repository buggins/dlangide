module dlangide.ui.settings;

import dlangui.core.settings;


const AVAILABLE_THEMES = ["theme_default", "theme_dark"];
const AVAILABLE_LANGUAGES = ["en", "ru"];

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
        ui.setStringDef("theme", "theme_default");
        ui.setStringDef("language", "en");
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
        return limitString(uiSettings.getString("theme", "theme_default"), AVAILABLE_THEMES);
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
}
