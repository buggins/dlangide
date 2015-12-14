module dlangide.workspace.workspacesettings;

import dlangui.core.settings;
import dlangui.core.i18n;
import ddebug.common.debugger;

/// local settings for workspace (not supposed to put under source control)
class WorkspaceSettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    private Breakpoint[] _breakpoints;

    private string _startupProjectName;
    @property string startupProjectName() {
        return _startupProjectName;
    }
    @property void startupProjectName(string s) {
        if (s.equal(_startupProjectName)) {
            _startupProjectName = s;
            save();
        }
    }

    void setBreakpoints(Breakpoint[] bps) {
        Setting obj = _setting.settingByPath("breakpoints", SettingType.ARRAY);
        obj.clear(SettingType.ARRAY);
        int index = 0;
        foreach(bp; bps) {
            Setting bpObj = new Setting();
            bpObj.setInteger("id", bp.id);
            bpObj.setString("file", bp.file);
            bpObj.setInteger("line", bp.line);
            bpObj.setBoolean("enabled", bp.enabled);
            bpObj.setString("projectName", bp.projectName);
            bpObj.setString("projectFilePath", bp.projectFilePath);
            obj[index++] = bpObj;
        }
        _breakpoints = bps;
        save();
    }

    Breakpoint[] getBreakpoints() {
        return _breakpoints;
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
        _startupProjectName = _setting.getString("startupProject");
        Setting obj = _setting.settingByPath("breakpoints", SettingType.ARRAY);
        _breakpoints = null;
        for (int i = 0; i < obj.length; i++) {
            Breakpoint bp = new Breakpoint();
            bp.id = cast(int)obj.getInteger("id");
            bp.file = obj.getString("file");
            bp.line = cast(int)obj.getInteger("line");
            bp.enabled = obj.getBoolean("enabled");
            _breakpoints ~= bp;
        }
    }

    override void updateDefaults() {
    }

}

