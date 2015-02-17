module dlangide.ui.settings;

import dlangui.core.settings;

class IDESettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    override void updateDefaults() {
        Setting ed = editorSettings();
        ed.setBooleanDef("useSpacesForTabs", true);
        ed.setIntegerDef("tabSize", 4);
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
    }

    @property Setting editorSettings() {
        Setting res = _setting.objectByPath("editors/textEditor", true);
        return res;
    }

    static int limitInt(long value, int minvalue, int maxvalue) {
        if (value < minvalue)
            return minvalue;
        else if (value > maxvalue)
            return maxvalue;
        return cast(int)value;
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
}
