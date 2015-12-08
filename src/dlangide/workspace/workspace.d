module dlangide.workspace.workspace;

import dlangide.workspace.project;
import dlangide.ui.frame;
import dlangui.core.logger;
import std.conv;
import std.path;
import std.file;
import std.json;
import std.range;
import std.utf;
import std.algorithm;

enum BuildOperation {
    Build,
    Clean,
    Rebuild,
    Run,
    Upgrade
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

/// return true if filename matches rules for workspace file names
bool isWorkspaceFile(string filename) {
    return filename.endsWith(WORKSPACE_EXTENSION);
}

/// DlangIDE workspace
class Workspace : WorkspaceItem {
    protected Project[] _projects;
    
    protected IDEFrame _frame;
    protected BuildConfiguration _buildConfiguration;
    protected ProjectConfiguration _projectConfiguration = ProjectConfiguration.DEFAULT;
    
    this(IDEFrame frame, string fname = null) {
        super(fname);
        _frame = frame;
    }

    @property Project[] projects() {
        return _projects;
    }

    @property BuildConfiguration buildConfiguration() { return _buildConfiguration; }
    @property void buildConfiguration(BuildConfiguration config) { _buildConfiguration = config; }

    @property ProjectConfiguration projectConfiguration() { return _projectConfiguration; }
    @property void projectConfiguration(ProjectConfiguration config) { _projectConfiguration = config; }
     
    protected Project _startupProject;

    @property Project startupProject() { return _startupProject; }
    @property void startupProject(Project project) { 
        _startupProject = project;
        _frame.setProjectConfigurations(project.configurations.keys.map!(k => k.to!dstring).array); 
    }

    /// setups currrent project configuration by name
    void setStartupProjectConfiguration(string conf)
    {
        if(_startupProject && conf in _startupProject.configurations) {
            _projectConfiguration = _startupProject.configurations[conf];
        }
    }
    
    protected void fillStartupProject() {
        if (!_startupProject && _projects.length)
            startupProject = _projects[0];
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

    void addProject(Project p) {
        _projects ~= p;
        p.workspace = this;
        fillStartupProject();
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
        try {
            JSONValue content;
            JSONValue[string] json;
            json["name"] = JSONValue(toUTF8(_name));
            json["description"] = JSONValue(toUTF8(_description));
            JSONValue[string] projects;
            foreach (Project p; _projects) {
                if (p.isDependency)
                    continue; // don't save dependency
                string pname = toUTF8(p.name);
                string ppath = absoluteToRelativePath(p.filename);
                projects[pname] = JSONValue(ppath);
            }
            json["projects"] = projects;
            content = json;
            string js = content.toPrettyString;
            write(_filename, js);
        } catch (JSONException e) {
            Log.e("Cannot parse json", e);
            return false;
        } catch (Exception e) {
            Log.e("Cannot read workspace file", e);
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

        try {
            string jsonSource = readText!string(_filename);
            JSONValue json = parseJSON(jsonSource);
            _name = toUTF32(json["name"].str);
            _description = toUTF32(json["description"].str);
            Log.d("workspace name: ", _name);
            Log.d("workspace description: ", _description);
            JSONValue projects = json["projects"];
            foreach(string key, ref JSONValue value; projects) {
                string path = value.str;
                Log.d("project: ", key, " path:", path);
                if (!isAbsolute(path))
                    path = buildNormalizedPath(_dir, path); //, "dub.json"
                Project project = new Project(this, path);
                _projects ~= project;
                project.load();

            }
            string js = json.toPrettyString;
            write(_filename, js);
        } catch (JSONException e) {
            Log.e("Cannot parse json", e);
            return false;
        } catch (Exception e) {
            Log.e("Cannot read workspace file", e);
            return false;
        }
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
