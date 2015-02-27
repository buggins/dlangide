module dlangide.workspace.project;

import dlangide.workspace.workspace;
import dlangui.core.logger;
import dlangui.core.collections;
import dlangui.core.settings;
import std.path;
import std.file;
import std.json;
import std.utf;
import std.algorithm;
import std.process;

/// return true if filename matches rules for workspace file names
bool isProjectFile(string filename) {
    return filename.baseName.equal("dub.json") || filename.baseName.equal("package.json");
}

string toForwardSlashSeparator(string filename) {
    char[] res;
    foreach(ch; filename) {
        if (ch == '\\')
            res ~= '/';
        else
            res ~= ch;
    }
    return cast(string)res;
}

/// project item
class ProjectItem {
    protected Project _project;
    protected ProjectItem _parent;
    protected string _filename;
    protected dstring _name;

    this(string filename) {
        _filename = buildNormalizedPath(filename);
        _name = toUTF32(baseName(_filename));
    }

    this() {
    }

    @property ProjectItem parent() {
        return _parent;
    }

    @property Project project() {
        return _project;
    }

    @property void project(Project p) {
        _project = p;
    }

    @property string filename() {
        return _filename;
    }

    @property dstring name() {
        return _name;
    }

    /// returns true if item is folder
    @property bool isFolder() {
        return false;
    }
    /// returns child object count
    @property int childCount() {
        return 0;
    }
    /// returns child item by index
    ProjectItem child(int index) {
        return null;
    }
}

/// Project folder
class ProjectFolder : ProjectItem {
    protected ObjectList!ProjectItem _children;

    this(string filename) {
        super(filename);
    }

    @property override bool isFolder() {
        return true;
    }
    @property override int childCount() {
        return _children.count;
    }
    /// returns child item by index
    override ProjectItem child(int index) {
        return _children[index];
    }
    void addChild(ProjectItem item) {
        _children.add(item);
        item._parent = this;
        item._project = _project;
    }
    bool loadDir(string path) {
        string src = relativeToAbsolutePath(path);
        if (exists(src) && isDir(src)) {
            ProjectFolder dir = new ProjectFolder(src);
            addChild(dir);
            Log.d("    added project folder ", src);
            dir.loadItems();
            return true;
        }
        return false;
    }
    bool loadFile(string path) {
        string src = relativeToAbsolutePath(path);
        if (exists(src) && isFile(src)) {
            ProjectSourceFile f = new ProjectSourceFile(src);
            addChild(f);
            Log.d("    added project file ", src);
            return true;
        }
        return false;
    }
    void loadItems() {
        foreach(e; dirEntries(_filename, SpanMode.shallow)) {
            string fn = baseName(e.name);
            if (e.isDir) {
                loadDir(fn);
            } else if (e.isFile) {
                loadFile(fn);
            }
        }
    }
    string relativeToAbsolutePath(string path) {
        if (isAbsolute(path))
            return path;
        return buildNormalizedPath(_filename, path);
    }
}

/// Project source file
class ProjectSourceFile : ProjectItem {
    this(string filename) {
        super(filename);
    }
}

class WorkspaceItem {
    protected string _filename;
    protected string _dir;
    protected dstring _name;
    protected dstring _description;

    this(string fname = null) {
        filename = fname;
    }

    /// file name of workspace item
    @property string filename() {
        return _filename;
    }

    /// workspace item directory
    @property string dir() {
        return _dir;
    }

    /// file name of workspace item
    @property void filename(string fname) {
        if (fname.length > 0) {
            _filename = buildNormalizedPath(fname);
            _dir = dirName(filename);
        } else {
            _filename = null;
            _dir = null;
        }
    }

    /// name
    @property dstring name() {
        return _name;
    }

    /// name
    @property void name(dstring s) {
        _name = s;
    }

    /// name
    @property dstring description() {
        return _description;
    }

    /// name
    @property void description(dstring s) {
        _description = s;
    }

    /// load
    bool load(string fname) {
        // override it
        return false;
    }

    bool save(string fname = null) {
        return false;
    }
}

/// detect DMD source paths
string[] dmdSourcePaths() {
    string[] res;
    version(Windows) {
        import dlangui.core.files;
        string dmdPath = findExecutablePath("dmd");
        if (dmdPath) {
            string dmdDir = buildNormalizedPath(dirName(dmdPath), "..", "..", "src");
            res ~= absolutePath(buildNormalizedPath(dmdDir, "druntime", "import"));
            res ~= absolutePath(buildNormalizedPath(dmdDir, "phobos"));
        }
    } else {
        res ~= "/usr/include/dmd/druntime/import";
        res ~= "/usr/include/dmd/phobos";
    }
    return res;
}

/// Stores info about project configuration
struct ProjectConfiguration {
    /// name used to build the project
    string name;
    /// type, for libraries one can run tests, for apps - execute them
    Type type;
    
    /// How to display default configuration in ui
    immutable static string DEFAULT_NAME = "default";
    /// Default project configuration
    immutable static ProjectConfiguration DEFAULT = ProjectConfiguration(DEFAULT_NAME, Type.Default);
    
    /// Type of configuration
    enum Type {
        Default,
        Executable,
        Library
    }
    
    private static Type parseType(string s)
    {
        switch(s)
        {
            case "executable": return Type.Executable;
            case "library": return Type.Library;
            case "dynamicLibrary": return Type.Library;
            case "staticLibrary": return Type.Library;
            default: return Type.Default;
        }
    }
    
    /// parsing from setting file
    static ProjectConfiguration[string] load(Setting s)
    {
        ProjectConfiguration[string] res = [DEFAULT_NAME: DEFAULT];
        if(s.map is null || "configurations" !in s.map || s.map["configurations"].array is null) 
        	return res;
        
        foreach(conf; s.map["configurations"].array)
        {
            if(conf.map is null || "name" !in conf.map) continue;
            Type t = Type.Default;
            if("targetType" in conf.map) {
                t = parseType(conf.map["targetType"].str);
            }
            string confName = conf.map["name"].str;
            res[confName] = ProjectConfiguration(confName, t);
        }
        
        return res;
    }
}

/// DLANGIDE D project
class Project : WorkspaceItem {
    protected Workspace _workspace;
    protected bool _opened;
    protected ProjectFolder _items;
    protected ProjectSourceFile _mainSourceFile;
    protected SettingsFile _projectFile;
    protected bool _isDependency;
    protected string _dependencyVersion;

    protected string[] _sourcePaths;
    protected string[] _builderSourcePaths;
    protected ProjectConfiguration[string] _configurations;

    this(Workspace ws, string fname = null, string dependencyVersion = null) {
        super(fname);
        _workspace = ws;
        _items = new ProjectFolder(fname);
        _dependencyVersion = dependencyVersion;
        _isDependency = _dependencyVersion.length > 0;
    }

    @property bool isDependency() { return _isDependency; }
    @property string dependencyVersion() { return _dependencyVersion; }

    /// returns project configurations
    @property const(ProjectConfiguration[string]) configurations() const
    {
        return _configurations;
    }
    
    /// returns project's own source paths
    @property string[] sourcePaths() { return _sourcePaths; }
    /// returns project's own source paths
    @property string[] builderSourcePaths() { 
        if (!_builderSourcePaths) {
            _builderSourcePaths = dmdSourcePaths();
        }
        return _builderSourcePaths; 
    }

    private static void addUnique(ref string[] dst, string[] items) {
        foreach(item; items) {
            bool found = false;
            foreach(existing; dst) {
                if (item.equal(existing)) {
                    found = true;
                    break;
                }
            }
            if (!found)
                dst ~= item;
        }
    }
    @property string[] importPaths() {
        string[] res;
        addUnique(res, sourcePaths);
        addUnique(res, builderSourcePaths);
        foreach(dep; _dependencies) {
            addUnique(res, dep.sourcePaths);
        }
        return res;
    }

    string relativeToAbsolutePath(string path) {
        if (isAbsolute(path))
            return path;
        return buildNormalizedPath(_dir, path);
    }

    @property ProjectSourceFile mainSourceFile() { return _mainSourceFile; }
    @property ProjectFolder items() {
        return _items;
    }

    @property Workspace workspace() {
        return _workspace;
    }

    @property void workspace(Workspace p) {
        _workspace = p;
    }

    @property string defWorkspaceFile() {
        return buildNormalizedPath(_filename.dirName, toUTF8(name) ~ WORKSPACE_EXTENSION);
    }

    ProjectFolder findItems(string[] srcPaths) {
        ProjectFolder folder = new ProjectFolder(_filename);
        folder.project = this;
        string path = relativeToAbsolutePath("src");
        if (folder.loadDir(path))
            _sourcePaths ~= path;
        path = relativeToAbsolutePath("source");
        if (folder.loadDir(path))
            _sourcePaths ~= path;
        foreach(customPath; srcPaths) {
            path = relativeToAbsolutePath(customPath);
            foreach(existing; _sourcePaths)
                if (path.equal(existing))
                    continue; // already exists
            if (folder.loadDir(path))
                _sourcePaths ~= path;
        }
        return folder;
    }

    void findMainSourceFile() {
        string n = toUTF8(name);
        string[] mainnames = ["app.d", "main.d", n ~ ".d"];
        foreach(sname; mainnames) {
            _mainSourceFile = findSourceFileItem(buildNormalizedPath(_dir, "src", sname));
            if (_mainSourceFile)
                break;
            _mainSourceFile = findSourceFileItem(buildNormalizedPath(_dir, "source", sname));
            if (_mainSourceFile)
                break;
        }
    }

    /// tries to find source file in project, returns found project source file item, or null if not found
	ProjectSourceFile findSourceFileItem(ProjectItem dir, string filename, bool fullFileName=true) {
        for (int i = 0; i < dir.childCount; i++) {
            ProjectItem item = dir.child(i);
            if (item.isFolder) {
                ProjectSourceFile res = findSourceFileItem(item, filename, fullFileName);
                if (res)
                    return res;
            } else {
                ProjectSourceFile res = cast(ProjectSourceFile)item;
				if(res)
				{
					if(fullFileName && res.filename.equal(filename))
						return res;
					else if (!fullFileName && res.filename.endsWith(filename))
                    	return res;
				}
            }
        }
        return null;
    }

	ProjectSourceFile findSourceFileItem(string filename, bool fullFileName=true) {
		return findSourceFileItem(_items, filename, fullFileName);
    }

    override bool load(string fname = null) {
        if (!_projectFile)
            _projectFile = new SettingsFile();
        _mainSourceFile = null;
        if (fname.length > 0)
            filename = fname;
        if (!_projectFile.load(_filename)) {
            Log.e("failed to load project from file ", _filename);
            return false;
        }
        Log.d("Reading project from file ", _filename);

        try {
            _name = toUTF32(_projectFile.getString("name"));
            if (_isDependency) {
                _name ~= "-"d;
                _name ~= toUTF32(_dependencyVersion.startsWith("~") ? _dependencyVersion[1..$] : _dependencyVersion);
            }
            _description = toUTF32(_projectFile.getString("description"));
            Log.d("  project name: ", _name);
            Log.d("  project description: ", _description);
            string[] srcPaths = _projectFile.getStringArray("sourcePaths");
            _items = findItems(srcPaths);
            findMainSourceFile();

            Log.i("Project source paths: ", sourcePaths);
            Log.i("Builder source paths: ", builderSourcePaths);
            if (!_isDependency)
                loadSelections();

            _configurations = ProjectConfiguration.load(_projectFile);
            Log.i("Project configurations: ", _configurations);
            
        } catch (JSONException e) {
            Log.e("Cannot parse json", e);
            return false;
        } catch (Exception e) {
            Log.e("Cannot read project file", e);
            return false;
        }
        return true;
    }

    protected Project[] _dependencies;
    @property Project[] dependencies() { return _dependencies; }
    protected bool addDependency(Project dep) {
        if (_workspace)
            _workspace.addDependencyProject(dep);
        _dependencies ~= dep;
        return true;
    }
    bool loadSelections() {
        _dependencies.length = 0;
        DubPackageFinder finder = new DubPackageFinder();
        scope(exit) destroy(finder);
        SettingsFile selectionsFile = new SettingsFile(buildNormalizedPath(_dir, "dub.selections.json"));
        if (!selectionsFile.load())
            return false;
        Setting versions = selectionsFile.objectByPath("versions");
        if (!versions)
            return false;
        string[string] versionMap = versions.strMap;
        foreach(packageName, packageVersion; versionMap) {
            string fn = finder.findPackage(packageName, packageVersion);
            Log.d("dependency ", packageName, " ", packageVersion, " : ", fn ? fn : "NOT FOUND");
            if (fn) {
                Project p = new Project(_workspace, fn, packageVersion);
                if (p.load()) {
                    addDependency(p);
                } else {
                    Log.e("cannot load dependency package ", packageName, " ", packageVersion, " from file ", fn);
                    destroy(p);
                }
            }
        }
        return true;
    }
}

class DubPackageFinder {
    string systemDubPath;
    string userDubPath;
    string tempPath;
    this() {
        version(Windows){
            systemDubPath = buildNormalizedPath(environment.get("ProgramData"), "dub", "packages");
            userDubPath = buildNormalizedPath(environment.get("APPDATA"), "dub", "packages");
            tempPath = buildNormalizedPath(environment.get("TEMP"), "dub", "packages");
        } else version(Posix){
            systemDubPath = "/var/lib/dub/packages";
            userDubPath = buildNormalizedPath(environment.get("HOME"), ".dub", "packages");
            if(!userDubPath.isAbsolute)
                userDubPath = buildNormalizedPath(getcwd(), userDubPath);
            tempPath = "/tmp/packages";
        }
    }

    protected string findPackage(string packageDir, string packageName, string packageVersion) {
        string fullName = packageVersion.startsWith("~") ? packageName ~ "-" ~ packageVersion[1..$] : packageName ~ "-" ~ packageVersion;
        string pathName = absolutePath(buildNormalizedPath(packageDir, fullName));
        if (pathName.exists && pathName.isDir) {
            string fn = buildNormalizedPath(pathName, "dub.json");
            if (fn.exists && fn.isFile)
                return fn;
            fn = buildNormalizedPath(pathName, "package.json");
            if (fn.exists && fn.isFile)
                return fn;
        }
        return null;
    }

    string findPackage(string packageName, string packageVersion) {
        string res = null;
        res = findPackage(userDubPath, packageName, packageVersion);
        if (res)
            return res;
        res = findPackage(systemDubPath, packageName, packageVersion);
        return res;
    }
}

