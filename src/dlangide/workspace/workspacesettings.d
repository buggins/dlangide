module dlangide.workspace.workspacesettings;

import dlangui.core.settings;
import dlangui.core.i18n;
import ddebug.common.debugger;
import dlangide.workspace.project;

import std.array : empty;
import std.algorithm : equal;

/// local settings for workspace (not supposed to put under source control)
class WorkspaceSettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    private Breakpoint[] _breakpoints;
    private EditorBookmark[] _bookmarks;

    private string _startupProjectName;
    @property string startupProjectName() {
        return _startupProjectName;
    }
    @property void startupProjectName(string s) {
        if (!s.equal(_startupProjectName)) {
            _startupProjectName = s;
            _setting["startupProject"] = s;
            save();
        }
    }

    /// get all breakpoints for project (for specified source file only, if specified)
    Breakpoint[] getProjectBreakpoints(string projectName, string projectFilePath) {
        Breakpoint[] res;
        for (int i = cast(int)_breakpoints.length - 1; i >= 0; i--) {
            Breakpoint bp = _breakpoints[i];
            if (!bp.projectName.equal(projectName))
                continue;
            if (!projectFilePath.empty && !bp.projectFilePath.equal(projectFilePath))
                continue;
            res ~= bp;
        }
        return res;
    }

    /// get all breakpoints for project (for specified source file only, if specified)
    void setProjectBreakpoints(string projectName, string projectFilePath, Breakpoint[] bps) {
        bool changed = false;
        for (int i = cast(int)_breakpoints.length - 1; i >= 0; i--) {
            Breakpoint bp = _breakpoints[i];
            if (!bp.projectName.equal(projectName))
                continue;
            if (!projectFilePath.empty && !bp.projectFilePath.equal(projectFilePath))
                continue;
            for (auto j = i; j < _breakpoints.length - 1; j++)
                _breakpoints[j] = _breakpoints[j + 1];
            _breakpoints.length--;
            changed = true;
        }
        if (bps.length) {
            changed = true;
            foreach(bp; bps)
                _breakpoints ~= bp;
        }
        if (changed) {
            setBreakpoints(_breakpoints);
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
        //save();
    }

    /// get all bookmarks for project (for specified source file only, if specified)
    EditorBookmark[] getProjectBookmarks(string projectName, string projectFilePath) {
        EditorBookmark[] res;
        for (int i = cast(int)_bookmarks.length - 1; i >= 0; i--) {
            EditorBookmark bp = _bookmarks[i];
            if (!bp.projectName.equal(projectName))
                continue;
            if (!projectFilePath.empty && !bp.projectFilePath.equal(projectFilePath))
                continue;
            res ~= bp;
        }
        return res;
    }

    /// get all bookmarks for project (for specified source file only, if specified)
    void setProjectBookmarks(string projectName, string projectFilePath, EditorBookmark[] bps) {
        bool changed = false;
        for (int i = cast(int)_bookmarks.length - 1; i >= 0; i--) {
            EditorBookmark bp = _bookmarks[i];
            if (!bp.projectName.equal(projectName))
                continue;
            if (!projectFilePath.empty && !bp.projectFilePath.equal(projectFilePath))
                continue;
            for (auto j = i; j < _bookmarks.length - 1; j++)
                _bookmarks[j] = _bookmarks[j + 1];
            _bookmarks.length--;
            changed = true;
        }
        if (bps.length) {
            changed = true;
            foreach(bp; bps)
                _bookmarks ~= bp;
        }
        if (changed) {
            setBookmarks(_bookmarks);
        }
    }

    void setBookmarks(EditorBookmark[] bps) {
        Setting obj = _setting.settingByPath("bookmarks", SettingType.ARRAY);
        obj.clear(SettingType.ARRAY);
        int index = 0;
        foreach(bp; bps) {
            Setting bpObj = new Setting();
            bpObj.setString("file", bp.file);
            bpObj.setInteger("line", bp.line);
            bpObj.setString("projectName", bp.projectName);
            bpObj.setString("projectFilePath", bp.projectFilePath);
            obj[index++] = bpObj;
        }
        _bookmarks = bps;
        //save();
    }

    Breakpoint[] getBreakpoints() {
        return _breakpoints;
    }

    EditorBookmark[] getBookmarks() {
        return _bookmarks;
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
        _startupProjectName = _setting.getString("startupProject");
        Setting obj = _setting.settingByPath("breakpoints", SettingType.ARRAY);
        _breakpoints = null;
        int maxBreakpointId = 0;
        for (int i = 0; i < obj.length; i++) {
            Breakpoint bp = new Breakpoint();
            Setting item = obj[i];
            bp.id = cast(int)item.getInteger("id");
            bp.file = item.getString("file");
            bp.projectName = item.getString("projectName");
            bp.projectFilePath = item.getString("projectFilePath");
            bp.line = cast(int)item.getInteger("line");
            bp.enabled = item.getBoolean("enabled");
            if (bp.id > maxBreakpointId)
                maxBreakpointId = bp.id;
            _breakpoints ~= bp;
        }
        _nextBreakpointId = maxBreakpointId + 1;
        obj = _setting.settingByPath("bookmarks", SettingType.ARRAY);
        _bookmarks = null;
        for (int i = 0; i < obj.length; i++) {
            EditorBookmark bp = new EditorBookmark();
            Setting item = obj[i];
            bp.file = item.getString("file");
            bp.projectName = item.getString("projectName");
            bp.projectFilePath = item.getString("projectFilePath");
            bp.line = cast(int)item.getInteger("line");
            _bookmarks ~= bp;
        }
    }

    override void updateDefaults() {
    }

}

