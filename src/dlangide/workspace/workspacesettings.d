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
    /// Last opened files in workspace
    private WorkspaceFile[] _files;

    private string _startupProjectName;
    private int _buildConfiguration;

    @property int buildConfiguration() {
        return _buildConfiguration;
    }
    @property void buildConfiguration(int config) {
        _setting.setInteger("buildConfiguration", config);
        _buildConfiguration = config;
        save();
    }

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

    /// Last opened files in workspace    
    @property WorkspaceFile[] files() {
        return _files;
    }
    
    /// Last opened files in workspace
    @property void files(WorkspaceFile[] fs) {
        _files = fs;
        // Save to settings file
        Setting obj = _setting.settingByPath("files", SettingType.ARRAY);
        obj.clear(SettingType.ARRAY);
        int index = 0;
        foreach(file; fs) {
            Setting single = new Setting();
            single.setString("file", file.filename);
            single.setInteger("column", file.column);
            single.setInteger("row", file.row);
            obj[index++] = single;
        }
    }

    /// list of expanded workspace explorer items
    @property string[] expandedItems() {
        Setting obj = _setting.settingByPath("expandedItems", SettingType.ARRAY);
        return obj.strArray;
    }

    /// update list of expanded workspace explorer items
    @property void expandedItems(string[] items) {
        Setting obj = _setting.settingByPath("expandedItems", SettingType.ARRAY);
        obj.strArray = items;
    }

    /// last selected workspace item in workspace explorer
    @property string selectedWorkspaceItem() {
        Setting obj = _setting.settingByPath("selectedWorkspaceItem", SettingType.STRING);
        return obj.str;
    }

    /// update last selected workspace item in workspace explorer
    @property void selectedWorkspaceItem(string item) {
        Setting obj = _setting.settingByPath("selectedWorkspaceItem", SettingType.STRING);
        obj.str = item;
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
        // Loading breakpoints
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
        // Loading bookmarks
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
        // Loading files
        _files = null;
        obj = _setting.settingByPath("files", SettingType.ARRAY);
        for (int i = 0; i < obj.length; i++) {
            Setting item = obj[i];
            WorkspaceFile file = new WorkspaceFile;
            file.filename(item.getString("file"));
            file.column(cast(int)item.getInteger("column"));
            file.row(cast(int)item.getInteger("row"));
            _files ~= file;
        }
        _buildConfiguration = cast(int)_setting.getInteger("buildConfiguration", 0);
        if (_buildConfiguration < 0)
            _buildConfiguration = 0;
        if (_buildConfiguration > 2)
            _buildConfiguration = 2;
    }

    override void updateDefaults() {
    }

}

/// Description for workspace file
class WorkspaceFile {
    /// File name with full path
    private string _filename;
    /// Cursor position column
    private int _column;
    /// Cursor position row
    private int _row;
    
    @property string filename() {
        return _filename;
    }
    @property void filename(string _fn) {
        this._filename = _fn;
    }
    
    @property int column() {
        return _column;
    }
    @property void column(int col) {
        _column = col;
    }
     
    @property int row() {
        return _row;
    }
    @property void row(int r) {
        _row = r;
    }
}
