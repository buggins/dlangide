module dlangide.workspace.workspace;

import dlangide.workspace.project;
import dlangide.workspace.workspacesettings;
import dlangide.ui.frame;
import dlangui.core.logger;
import dlangui.core.settings;
import std.algorithm : map;
import std.conv;
import std.file;
import std.path;
import std.range : array;
import std.utf;

import ddebug.common.debugger;

enum BuildOperation {
    Build,
    Clean,
    Rebuild,
    Run,
    Upgrade,
    RunWithRdmd
}

enum BuildConfiguration {
    Debug,
    Release,
    Unittest
}


/**
    Exception thrown on Workspace errors
*/
class WorkspaceException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

immutable string WORKSPACE_EXTENSION = ".dlangidews";
immutable string WORKSPACE_SETTINGS_EXTENSION = ".wssettings";

/// return true if filename matches rules for workspace file names
bool isWorkspaceFile(string filename) {
    return filename.endsWith(WORKSPACE_EXTENSION);
}

/// DlangIDE workspace
class Workspace : WorkspaceItem {
    protected Project[] _projects;
    protected SettingsFile _workspaceFile;
    protected WorkspaceSettings _settings;
    
    protected IDEFrame _frame;
    protected BuildConfiguration _buildConfiguration;
    protected ProjectConfiguration _projectConfiguration = ProjectConfiguration.DEFAULT;
    
    this(IDEFrame frame, string fname = WORKSPACE_EXTENSION) {
        super(fname);
        _workspaceFile = new SettingsFile(fname);
        _settings = new WorkspaceSettings(fname ? fname ~ WORKSPACE_SETTINGS_EXTENSION : null);
        _frame = frame;
    }

    ProjectSourceFile findSourceFile(string projectFileName, string fullFileName) {
        foreach(p; _projects) {
            ProjectSourceFile res = p.findSourceFile(projectFileName, fullFileName);
            if (res)
                return res;
        }
        return null;
    }

    @property Project[] projects() { return _projects; }

    @property BuildConfiguration buildConfiguration() { return _buildConfiguration; }
    @property void buildConfiguration(BuildConfiguration config) { _buildConfiguration = config; }

    @property ProjectConfiguration projectConfiguration() { return _projectConfiguration; }
    @property void projectConfiguration(ProjectConfiguration config) { _projectConfiguration = config; }
     
    protected Project _startupProject;

    @property Project startupProject() { return _startupProject; }
    @property void startupProject(Project project) { 
        _startupProject = project;
        _frame.setProjectConfigurations(project.configurations.keys.map!(k => k.to!dstring).array); 
        _settings.startupProjectName = toUTF8(project.name);
    }

    /// setups currrent project configuration by name
    void setStartupProjectConfiguration(string conf)
    {
        if(_startupProject && conf in _startupProject.configurations) {
            _projectConfiguration = _startupProject.configurations[conf];
        }
    }

    private void updateBreakpointFiles(Breakpoint[] breakpoints) {
        foreach(bp; breakpoints) {
            Project project = findProjectByName(bp.projectName);
            if (project)
                bp.fullFilePath = project.relativeToAbsolutePath(bp.projectFilePath);
        }
    }

    private void updateBookmarkFiles(EditorBookmark[] bookmarks) {
        foreach(bp; bookmarks) {
            Project project = findProjectByName(bp.projectName);
            if (project)
                bp.fullFilePath = project.relativeToAbsolutePath(bp.projectFilePath);
        }
    }

    Breakpoint[] getSourceFileBreakpoints(ProjectSourceFile file) {
        Breakpoint[] res = _settings.getProjectBreakpoints(toUTF8(file.project.name), file.projectFilePath);
        updateBreakpointFiles(res);
        return res;
    }
    
    void setSourceFileBreakpoints(ProjectSourceFile file, Breakpoint[] breakpoints) {
        _settings.setProjectBreakpoints(toUTF8(file.project.name), file.projectFilePath, breakpoints);
    }

    EditorBookmark[] getSourceFileBookmarks(ProjectSourceFile file) {
        EditorBookmark[] res = _settings.getProjectBookmarks(toUTF8(file.project.name), file.projectFilePath);
        updateBookmarkFiles(res);
        return res;
    }
    
    void setSourceFileBookmarks(ProjectSourceFile file, EditorBookmark[] bookmarks) {
        _settings.setProjectBookmarks(toUTF8(file.project.name), file.projectFilePath, bookmarks);
    }

    /// returns all workspace breakpoints
    Breakpoint[] getBreakpoints() {
        Breakpoint[] res = _settings.getBreakpoints();
        updateBreakpointFiles(res);
        return res;
    }
    
    protected void fillStartupProject() {
        string s = _settings.startupProjectName;
        if ((!_startupProject || !_startupProject.name.toUTF8.equal(s)) && _projects.length) {
            if (!s.empty) {
                foreach(p; _projects) {
                    if (p.name.toUTF8.equal(s)) {
                        _startupProject = p;
                    }
                }
            }
            if (!_startupProject) {
                startupProject = _projects[0];
            }
        }
    }

    /// tries to find source file in one of projects, returns found project source file item, or null if not found
    ProjectSourceFile findSourceFileItem(string filename, bool fullFileName=true) {
        foreach (Project p; _projects) {
            ProjectSourceFile res = p.findSourceFileItem(filename, fullFileName);
            if (res)
                return res;
        }
        return null;
    }

    /// find project in workspace by filename
    Project findProject(string filename) {
        foreach (Project p; _projects) {
            if (p.filename.equal(filename))
                return p;
        }
        return null;
    }

    /// find project in workspace by filename
    Project findProjectByName(string name) {
        foreach (Project p; _projects) {
            if (p.name.toUTF8.equal(name))
                return p;
        }
        return null;
    }

    void addProject(Project p) {
        _projects ~= p;
        p.workspace = this;
        fillStartupProject();
    }

    Project removeProject(int index) {
        if (index < 0 || index > _projects.length)
            return null;
        Project res = _projects[index];
        for (int j = index; j + 1 < _projects.length; j++)
            _projects[j] = _projects[j + 1];
        return res;
    }

    bool isDependencyProjectUsed(string filename) {
        foreach(p; _projects)
            if (!p.isDependency && p.findDependencyProject(filename))
                return true;
        return false;
    }

    void cleanupUnusedDependencies() {
        for (int i = cast(int)_projects.length - 1; i >= 0; i--) {
            if (_projects[i].isDependency) {
                if (!isDependencyProjectUsed(_projects[i].filename))
                    removeProject(i);
            }
        }
    }

    bool addDependencyProject(Project p) {
        for (int i = 0; i < _projects.length; i++) {
            if (_projects[i].filename.equal(p.filename)) {
                _projects[i] = p;
                return false;
            }
        }
        addProject(p);
        return true;
    }

    string absoluteToRelativePath(string path) {
        return toForwardSlashSeparator(relativePath(path, _dir));
    }

    override bool save(string fname = null) {
        if (fname.length > 0)
            filename = fname;
        if (_filename.empty) // no file name specified
            return false;
        _settings.save(_filename ~ WORKSPACE_SETTINGS_EXTENSION);
        _workspaceFile.setString("name", toUTF8(_name));
        _workspaceFile.setString("description", toUTF8(_description));
        Setting projects = _workspaceFile.objectByPath("projects", true);
        projects.clear(SettingType.OBJECT);
        foreach (Project p; _projects) {
            if (p.isDependency)
                continue; // don't save dependency
            string pname = toUTF8(p.name);
            string ppath = absoluteToRelativePath(p.filename);
            projects[pname] = ppath;
        }
        if (!_workspaceFile.save(_filename, true)) {
            Log.e("Cannot save workspace file");
            return false;
        }
        return true;
    }

    override bool load(string fname = null) {
        if (fname.length > 0)
            filename = fname;
        if (!exists(_filename) || !isFile(_filename))  {
            return false;
        }
        Log.d("Reading workspace from file ", _filename);
        if (!_workspaceFile.load(_filename)) {
            Log.e("Cannot read workspace file");
            return false;
        }
        _settings.load(filename ~ WORKSPACE_SETTINGS_EXTENSION);
        _name = toUTF32(_workspaceFile["name"].str);
        _description = toUTF32(_workspaceFile["description"].str);
        Log.d("workspace name: ", _name);
        Log.d("workspace description: ", _description);
        if (_name.empty()) {
            Log.e("empty workspace name");
            return false;
        }
        auto originalStartupProjectName = _settings.startupProjectName;
        Setting projects = _workspaceFile.objectByPath("projects", true);
        foreach(string key, Setting value; projects) {
            string path = value.str;
            Log.d("project: ", key, " path:", path);
            if (!isAbsolute(path))
                path = buildNormalizedPath(_dir, path); //, "dub.json"
            Project project = new Project(this, path);
            _projects ~= project;
            project.load();
        }
        _settings.startupProjectName = originalStartupProjectName;
        fillStartupProject();
        return true;
    }
    void close() {
    }

    void refresh() {
        foreach (Project p; _projects) {
            p.refresh();
        }
    }
}

/// global workspace
__gshared Workspace currentWorkspace;
