module dlangide.workspace.project;

import dlangide.workspace.workspace;
import dlangide.workspace.projectsettings;
import dlangui.core.logger;
import dlangui.core.collections;
import dlangui.core.settings;
import std.algorithm;
import std.array : empty;
import std.file;
import std.path;
import std.process;
import std.utf;

string[] includePath;

/// return true if filename matches rules for workspace file names
bool isProjectFile(in string filename) pure nothrow {
    return filename.baseName.equal("dub.json") || filename.baseName.equal("DUB.JSON") || filename.baseName.equal("package.json") ||
        filename.baseName.equal("dub.sdl") || filename.baseName.equal("DUB.SDL");
}

string toForwardSlashSeparator(in string filename) pure nothrow {
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

    @property ProjectItem parent() { return _parent; }

    @property Project project() { return _project; }

    @property void project(Project p) { _project = p; }

    @property string filename() { return _filename; }

    @property string directory() {
        import std.path : dirName;
        return _filename.dirName;
    }

    @property dstring name() { return _name; }

    @property string name8() {
        return _name.toUTF8;
    }

    /// returns true if item is folder
    @property const bool isFolder() { return false; }
    /// returns child object count
    @property int childCount() { return 0; }
    /// returns child item by index
    ProjectItem child(int index) { return null; }

    void refresh() {
    }

    ProjectSourceFile findSourceFile(string projectFileName, string fullFileName) {
        if (fullFileName.equal(_filename))
            return cast(ProjectSourceFile)this;
        if (project && projectFileName.equal(project.absoluteToRelativePath(_filename)))
            return cast(ProjectSourceFile)this;
        return null;
    }

    @property bool isDSourceFile() {
        if (isFolder)
            return false;
        return filename.endsWith(".d") || filename.endsWith(".dd") || filename.endsWith(".dd")  || filename.endsWith(".di") || filename.endsWith(".dh") || filename.endsWith(".ddoc");
    }

    @property bool isJsonFile() {
        if (isFolder)
            return false;
        return filename.endsWith(".json") || filename.endsWith(".JSON");
    }

    @property bool isDMLFile() {
        if (isFolder)
            return false;
        return filename.endsWith(".dml") || filename.endsWith(".DML");
    }

    @property bool isXMLFile() {
        if (isFolder)
            return false;
        return filename.endsWith(".xml") || filename.endsWith(".XML");
    }
}

/// Project folder
class ProjectFolder : ProjectItem {
    protected ObjectList!ProjectItem _children;

    this(string filename) {
        super(filename);
    }

    @property override const bool isFolder() {
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
    ProjectItem childByPathName(string path) {
        for (int i = 0; i < _children.count; i++) {
            if (_children[i].filename.equal(path))
                return _children[i];
        }
        return null;
    }
    ProjectItem childByName(dstring s) {
        for (int i = 0; i < _children.count; i++) {
            if (_children[i].name.equal(s))
                return _children[i];
        }
        return null;
    }

    override ProjectSourceFile findSourceFile(string projectFileName, string fullFileName) {
        for (int i = 0; i < _children.count; i++) {
            if (ProjectSourceFile res = _children[i].findSourceFile(projectFileName, fullFileName))
                return res;
        }
        return null;
    }

    bool loadDir(string path) {
        string src = relativeToAbsolutePath(path);
        if (exists(src) && isDir(src)) {
            ProjectFolder existing = cast(ProjectFolder)childByPathName(src);
            if (existing) {
                if (existing.isFolder)
                    existing.loadItems();
                return true;
            }
            auto dir = new ProjectFolder(src);
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
            ProjectItem existing = childByPathName(src);
            if (existing)
                return true;
            auto f = new ProjectSourceFile(src);
            addChild(f);
            Log.d("    added project file ", src);
            return true;
        }
        return false;
    }

    void loadItems() {
        bool[string] loaded;
        string path = _filename;
        if (exists(path) && isFile(path))
            path = dirName(path);
        foreach(e; dirEntries(path, SpanMode.shallow)) {
            string fn = baseName(e.name);
            if (e.isDir) {
                loadDir(fn);
                loaded[fn] = true;
            } else if (e.isFile) {
                loadFile(fn);
                loaded[fn] = true;
            }
        }
        // removing non-reloaded items
        for (int i = _children.count - 1; i >= 0; i--) {
            if (!(toUTF8(_children[i].name) in loaded)) {
                _children.remove(i);
            }
        }
        sortItems();
    }

    /// predicate for sorting project items
    static bool compareProjectItemsLess(ProjectItem item1, ProjectItem item2) {
        return ((item1.isFolder && !item2.isFolder) || ((item1.isFolder == item2.isFolder) && (item1.name < item2.name)));
    }

    void sortItems() {
        import std.algorithm.sorting : sort;
        sort!compareProjectItemsLess(_children.asArray);
    }

    string relativeToAbsolutePath(string path) {
        if (isAbsolute(path))
            return path;
        string fn = _filename;
        if (exists(fn) && isFile(fn))
            fn = dirName(fn);
        return buildNormalizedPath(fn, path);
    }

    override void refresh() {
        loadItems();
    }
}


/// Project source file
class ProjectSourceFile : ProjectItem {
    this(string filename) {
        super(filename);
    }
    /// file path relative to project directory
    @property string projectFilePath() {
        return project.absoluteToRelativePath(filename);
    }

    void setFilename(string filename) {
        _filename = buildNormalizedPath(filename);
        _name = toUTF32(baseName(_filename));
    }
}

class WorkspaceItem {
    protected string _filename;
    protected string _dir;
    protected dstring _name;
    protected dstring _originalName;
    protected dstring _description;

    this(string fname = null) {
        filename = fname;
    }

    /// file name of workspace item
    @property string filename() { return _filename; }

    /// workspace item directory
    @property string dir() { return _dir; }

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
    @property dstring name() { return _name; }

    @property string name8() {
        return _name.toUTF8;
    }

    /// name
    @property void name(dstring s) {  _name = s; }

    /// description
    @property dstring description() { return _description; }
    /// description
    @property void description(dstring s) { _description = s; }

    /// load
    bool load(string fname) {
        // override it
        return false;
    }

    bool save(string fname = null) {
        return false;
    }
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
    static ProjectConfiguration[] load(Setting s)
    {
        ProjectConfiguration[] res;
        Setting configs = s.objectByPath("configurations");
        if(configs is null || configs.type != SettingType.ARRAY) {
            res ~= DEFAULT;
            return res;
        }

        foreach(conf; configs) {
            if(!conf.isObject) continue;
            Type t = Type.Default;
            if(auto typeName = conf.getString("targetType"))
                t = parseType(typeName);
            if (string confName = conf.getString("name")) {
                res ~= ProjectConfiguration(confName, t);
            }
        }
        return res;
    }
}

/// DLANGIDE D project
class Project : WorkspaceItem {
    import dlangide.workspace.idesettings : IDESettings;
    protected Workspace _workspace;
    protected bool _opened;
    protected ProjectFolder _items;
    protected ProjectSourceFile _mainSourceFile;
    protected SettingsFile _projectFile;
    protected ProjectSettings _settingsFile;
    protected bool _isDependency;
    protected bool _isSubproject;
    protected bool _isEmbeddedSubproject;
    protected dstring _baseProjectName;
    protected string _dependencyVersion;

    protected string[] _sourcePaths;
    protected ProjectConfiguration[] _configurations;
    protected ProjectConfiguration _projectConfiguration = ProjectConfiguration.DEFAULT;

    @property int projectConfigurationIndex() {
        ProjectConfiguration config = projectConfiguration();
        foreach(i, value; _configurations) {
            if (value.name == config.name)
                return cast(int)i;
        }
        return 0;
    }

    @property ProjectConfiguration projectConfiguration() {
        if (_configurations.length == 0)
            return ProjectConfiguration.DEFAULT;
        string configName = settings.projectConfiguration;
        foreach(config; _configurations) {
            if (configName == config.name)
                return config;
        }
        return _configurations[0];
    }

    @property void projectConfiguration(ProjectConfiguration config) {
        settings.projectConfiguration = config.name;
        settings.save();
    }

    @property void projectConfiguration(string configName) {
        foreach(name, config; _configurations) {
            if (configName == config.name) {
                settings.projectConfiguration = config.name;
                settings.save();
                return;
            }
        }
    }

    this(Workspace ws, string fname = null, string dependencyVersion = null) {
        super(fname);
        _workspace = ws;

        if (_workspace) {
    		foreach(obj; _workspace.includePath.array)
    			includePath ~= obj.str;
        }

        _items = new ProjectFolder(fname);
        _dependencyVersion = dependencyVersion;
        _isDependency = _dependencyVersion.length > 0;
        _projectFile = new SettingsFile(fname);
    }

    void setBaseProject(Project p) {
        if (p) {
            _isSubproject = true;
            _isDependency = p._isDependency;
            _baseProjectName = p._originalName;
            _dependencyVersion = p._dependencyVersion;
        } else {
            _isSubproject = false;
        }
    }

    void setSubprojectJson(Setting s) {
        if (!_projectFile)
            _projectFile = new SettingsFile();
        _isEmbeddedSubproject = true;
        _projectFile.replaceSetting(s.clone);
    }

    @property ProjectSettings settings() {
        if (!_settingsFile) {
            _settingsFile = new ProjectSettings(settingsFileName);
            _settingsFile.updateDefaults();
            _settingsFile.load();
            _settingsFile.save();
        }
        return _settingsFile;
    }

    @property string settingsFileName() {
        return buildNormalizedPath(dir, toUTF8(name) ~ ".settings");
    }

    @property bool isDependency() { return _isDependency; }
    @property string dependencyVersion() { return _dependencyVersion; }

    /// returns project configurations
    @property const(ProjectConfiguration[]) configurations() const
    {
        return _configurations;
    }

    /// returns project configurations
    @property dstring[] configurationNames() const
    {
        dstring[] res;
        res.assumeSafeAppend;
        foreach(conf; _configurations)
            res ~= conf.name.toUTF32;
        return res;
    }

    /// direct access to project file (json)
    @property SettingsFile content() { return _projectFile; }

    /// name
    override @property dstring name() {
        return super.name();
    }

    /// name
    override @property void name(dstring s) {
        super.name(s);
        _projectFile.setString("name", toUTF8(s));
    }

    /// name
    override @property dstring description() {
        return super.description();
    }

    /// name
    override @property void description(dstring s) {
        super.description(s);
        _projectFile.setString("description", toUTF8(s));
    }

    /// returns project's own source paths
    @property string[] sourcePaths() { return _sourcePaths; }
    /// returns project's current toolchain import paths
    string[] builderSourcePaths(IDESettings ideSettings) {
        string compilerName = settings.getToolchain(ideSettings);
        if (!compilerName)
            compilerName = "default";
        return compilerImportPathsCache.getImportPathsFor(compilerName);
    }

    /// returns first source folder for project or null if not found
    ProjectFolder firstSourceFolder() {
        for(int i = 0; i < _items.childCount; i++) {
            if (_items.child(i).isFolder)
                return cast(ProjectFolder)_items.child(i);
        }
        return null;
    }

    ProjectSourceFile findSourceFile(string projectFileName, string fullFileName) {
        return _items ? _items.findSourceFile(projectFileName, fullFileName) : null;
    }

    private static void addUnique(ref string[] dst, string[] items) {
        foreach(item; items) {
            if (!canFind(dst, item))
                dst ~= item;
        }
    }
    @property string[] importPaths(IDESettings ideSettings) {
        string[] res;
        addUnique(res, sourcePaths);
        addUnique(res, builderSourcePaths(ideSettings));
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

    string absoluteToRelativePath(string path) {
        if (!isAbsolute(path))
            return path;
        return relativePath(path, _dir);
    }

    @property ProjectSourceFile mainSourceFile() { return _mainSourceFile; }
    @property ProjectFolder items() { return _items; }

    @property Workspace workspace() { return _workspace; }

    @property void workspace(Workspace p) { _workspace = p; }

    @property string defWorkspaceFile() {
        return buildNormalizedPath(_filename.dirName, toUTF8(name) ~ WORKSPACE_EXTENSION);
    }

    @property bool isExecutable() {
        // TODO: use targetType
        return true;
    }

    /// return executable file name, or null if it's library project or executable is not found
    @property string executableFileName() {
        if (!isExecutable)
            return null;
        string exename = toUTF8(name);
        exename = _projectFile.getString("targetName", exename);
        // TODO: use targetName
        version (Windows) {
            exename = exename ~ ".exe";
        }
        string targetPath = _projectFile.getString("targetPath", null);
        string exePath;
        if (targetPath.length)
            exePath = buildNormalizedPath(_filename.dirName, targetPath, exename); // int $targetPath directory
        else
            exePath = buildNormalizedPath(_filename.dirName, exename); // in project directory
        return exePath;
    }

    /// working directory for running and debugging project
    @property string workingDirectory() {
        // TODO: get from settings
        return _filename.dirName;
    }

    /// commandline parameters for running and debugging project
    @property string runArgs() {
        // TODO: get from settings
        return null;
    }

    @property bool runInExternalConsole() {
        // TODO
        return settings.runInExternalConsole;
    }

    ProjectFolder findItems(string[] srcPaths) {
        auto folder = new ProjectFolder(_filename);
        folder.project = this;
        foreach(customPath; srcPaths) {
            string path = relativeToAbsolutePath(customPath);
            if (folder.loadDir(path))
                _sourcePaths ~= path;
        }
        return folder;
    }

    void refresh() {
        for (int i = _items._children.count - 1; i >= 0; i--) {
            if (_items._children[i].isFolder)
                _items._children[i].refresh();
        }
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
        foreach(i; 0 .. dir.childCount) {
            ProjectItem item = dir.child(i);
            if (item.isFolder) {
                ProjectSourceFile res = findSourceFileItem(item, filename, fullFileName);
                if (res)
                    return res;
            } else {
                auto res = cast(ProjectSourceFile)item;
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

    protected Project[] _subPackages;

    /// add item to string array ignoring duplicates
    protected static void addUnique(ref string[] list, string item) {
        foreach(s; list)
            if (s == item)
                return;
        list ~= item;
    }

    /// add item to string array ignoring duplicates
    protected void addRelativePathIfExists(ref string[] list, string item) {
        item = relativeToAbsolutePath(item);
        if (item.exists && item.isDir)
            addUnique(list, item);
    }

    /// find source paths for project
    protected string[] findSourcePaths() {
        string[] res;
        res.assumeSafeAppend;
        string[] srcPaths = _projectFile.getStringArray("sourcePaths");
        foreach(s; srcPaths)
            addRelativePathIfExists(res, s);
        Setting configs = _projectFile.objectByPath("configurations");
        if (configs) {
            for (int i = 0; i < configs.length; i++) {
                Setting s = configs[i];
                if (s) {
                    string[] paths = s.getStringArray("sourcePaths");
                    foreach(path; paths)
                        addRelativePathIfExists(res, path);
                }
            }
        }
        if (!res.length) {
            addRelativePathIfExists(res, "src");
            addRelativePathIfExists(res, "source");
        }

        return res;
    }

    void processSubpackages() {
        import dlangui.core.files;
        _subPackages.length = 0;
        Setting subPackages = _projectFile.settingByPath("subPackages", SettingType.ARRAY, false);
        if (subPackages) {
            string p = _projectFile.filename.dirName;
            for(int i = 0; i < subPackages.length; i++) {
                Setting sp = subPackages[i];
                if (sp.isString) {
                    // string
                    string path = convertPathDelimiters(sp.str);
                    string relative = relativePath(path, p);
                    path = buildNormalizedPath(absolutePath(relative, p));
                    //Log.d("Subproject path: ", path);
                    string fn = DubPackageFinder.findPackageFile(path);
                    //Log.d("Subproject file: ", fn);
                    Project prj = new Project(_workspace, fn);
                    prj.setBaseProject(this);
                    if (prj.load()) {
                        Log.d("Loaded subpackage from file: ", fn);
                        _subPackages ~= prj;
                        if (_workspace)
                            _workspace.addDependencyProject(prj);
                    } else {
                        Log.w("Failed to load subpackage from file: ", fn);
                    }
                } else if (sp.isObject) {
                    // object - file inside base project dub.json
                    Log.d("Subpackage is JSON object");
                    string subname = sp.getString("name");
                    if (subname) {
                        Project prj = new Project(_workspace, _filename ~ "@" ~ subname);
                        prj.setBaseProject(this);
                        prj.setSubprojectJson(sp);
                        bool res = prj.processLoadedProject();
                        if (res) {
                            Log.d("Added embedded subpackage ", subname);
                            _subPackages ~= prj;
                            if (_workspace)
                                _workspace.addDependencyProject(prj);
                        } else {
                            Log.w("Error while processing embedded subpackage");
                        }
                    }
                }
            }
        }
    }

    /// parse data from _projectFile after loading
    bool processLoadedProject() {
        //
        _mainSourceFile = null;
        try {
            _name = toUTF32(_projectFile.getString("name"));
            _originalName = _name;
            if (_baseProjectName) {
                _name = _baseProjectName ~ ":" ~ _name;
            }
            if (_isDependency) {
                _name ~= "-"d;
                _name ~= toUTF32(_dependencyVersion.startsWith("~") ? _dependencyVersion[1..$] : _dependencyVersion);
            }
            _description = toUTF32(_projectFile.getString("description"));
            Log.d("  project name: ", _name);
            Log.d("  project description: ", _description);

            processSubpackages();

            string[] srcPaths = findSourcePaths();
            _sourcePaths = null;
            _items = findItems(srcPaths);
            findMainSourceFile();

            Log.i("Project source paths: ", sourcePaths);
            //Log.i("Builder source paths: ", builderSourcePaths(_settings));
            if (!_isDependency)
                loadSelections();

            _configurations = ProjectConfiguration.load(_projectFile);
            Log.i("Project configurations: ", _configurations);


        } catch (Exception e) {
            Log.e("Cannot read project file", e);
            return false;
        }
        _items.loadFile(filename);
        return true;
    }

    override bool load(string fname = null) {
        if (!_projectFile)
            _projectFile = new SettingsFile();
        if (fname.length > 0)
            filename = fname;
        if (!_projectFile.load(_filename)) {
            Log.e("failed to load project from file ", _filename);
            return false;
        }
        Log.d("Reading project from file ", _filename);
        return processLoadedProject();

    }

    override bool save(string fname = null) {
        if (_isEmbeddedSubproject)
            return false;
        if (fname !is null)
            filename = fname;
        assert(filename !is null);
        return _projectFile.save(filename, true);
    }

    protected Project[] _dependencies;
    @property Project[] dependencies() { return _dependencies; }

    Project findDependencyProject(string filename) {
        foreach(dep; _dependencies) {
            if (dep.filename.equal(filename))
                return dep;
        }
        return null;
    }

    bool loadSelections() {
        Project[] newdeps;
        _dependencies.length = 0;
        auto finder = new DubPackageFinder;
        scope(exit) destroy(finder);
        SettingsFile selectionsFile = new SettingsFile(buildNormalizedPath(_dir, "dub.selections.json"));
        if (!selectionsFile.load()) {
            _dependencies = newdeps;
            return false;
        }
        Setting versions = selectionsFile.objectByPath("versions");
        if (!versions.isObject) {
            _dependencies = newdeps;
            return false;
        }
        string[string] versionMap = versions.strMap;
        foreach(packageName, packageVersion; versionMap) {
            string fn = finder.findPackage(packageName, packageVersion);
            Log.d("dependency ", packageName, " ", packageVersion, " : ", fn ? fn : "NOT FOUND");
            if (fn) {
                Project p = findDependencyProject(fn);
                if (p) {
                    Log.d("Found existing dependency project ", fn);
                    newdeps ~= p;
                    continue;
                }
                p = new Project(_workspace, fn, packageVersion);
                if (p.load()) {
                    newdeps ~= p;
                    if (_workspace)
                        _workspace.addDependencyProject(p);
                } else {
                    Log.e("cannot load dependency package ", packageName, " ", packageVersion, " from file ", fn);
                    destroy(p);
                }
            }
        }
        _dependencies = newdeps;
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

    /// find package file (dub.json, package.json) in specified dir; returns absoulute path to found file or null if not found
    static string findPackageFile(string pathName) {
        string fn = buildNormalizedPath(pathName, "dub.json");
        if (fn.exists && fn.isFile)
            return fn;
        fn = buildNormalizedPath(pathName, "dub.sdl");
        if (fn.exists && fn.isFile)
            return fn;
        fn = buildNormalizedPath(pathName, "package.json");
        if (fn.exists && fn.isFile)
            return fn;
        return null;
    }

    protected string findPackage(string packageDir, string packageName, string packageVersion) {
        string fullName = packageVersion.startsWith("~") ? packageName ~ "-" ~ packageVersion[1..$] : packageName ~ "-" ~ packageVersion;
        string pathName = absolutePath(buildNormalizedPath(packageDir, fullName));
        if (pathName.exists && pathName.isDir) {
            string fn = findPackageFile(pathName);
            if (fn)
                return fn;
            // new DUB support - with package subdirectory
            fn = findPackageFile(buildNormalizedPath(pathName, packageName));
            if (fn)
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

bool isValidProjectName(in string s) pure {
    if (s.empty)
        return false;
    return reduce!q{ a && (b == '_' || b == '-' || std.ascii.isAlphaNum(b)) }(true, s);
}

bool isValidModuleName(in string s) pure {
    if (s.empty)
        return false;
    return reduce!q{ a && (b == '_' || std.ascii.isAlphaNum(b)) }(true, s);
}

bool isValidFileName(in string s) pure {
    if (s.empty)
        return false;
    return reduce!q{ a && (b == '_' || b == '.' || b == '-' || std.ascii.isAlphaNum(b)) }(true, s);
}

unittest {
    assert(!isValidProjectName(""));
    assert(isValidProjectName("project"));
    assert(isValidProjectName("cool_project"));
    assert(isValidProjectName("project-2"));
    assert(!isValidProjectName("project.png"));
    assert(!isValidProjectName("[project]"));
    assert(!isValidProjectName("<project/>"));
    assert(!isValidModuleName(""));
    assert(isValidModuleName("module"));
    assert(isValidModuleName("awesome_module2"));
    assert(!isValidModuleName("module-2"));
    assert(!isValidModuleName("module.png"));
    assert(!isValidModuleName("[module]"));
    assert(!isValidModuleName("<module>"));
    assert(!isValidFileName(""));
    assert(isValidFileName("file"));
    assert(isValidFileName("file_2"));
    assert(isValidFileName("file-2"));
    assert(isValidFileName("file.txt"));
    assert(!isValidFileName("[file]"));
    assert(!isValidFileName("<file>"));
}

class EditorBookmark {
    string file;
    string fullFilePath;
    string projectFilePath;
    int line;
    string projectName;
}


string[] splitByLines(string s) {
    string[] res;
    int start = 0;
    for(int i = 0; i <= s.length; i++) {
        if (i == s.length) {
            if (start < i)
                res ~= s[start .. i];
            break;
        }
        if (s[i] == '\r' || s[i] == '\n') {
            if (start < i)
                res ~= s[start .. i];
            start = i + 1;
        }
    }
    return res;
}

struct CompilerImportPathsCache {

    private static class Entry {
        string[] list;
    }
    private Entry[string] _cache;

    string[] getImportPathsFor(string compiler) {
        import dlangui.core.files : findExecutablePath;
        if (!compiler.length)
            return [];
        if (auto p = compiler in _cache) {
            // found in cache
            return p.list;
        }
        Log.d("Searching for compiler path: ", compiler);
        import std.path : isAbsolute;
        string compilerPath = compiler;
        if (compiler == "default") {
            // try to autodetect default compiler
            compilerPath = findExecutablePath("dmd");
            if (!compilerPath)
                compilerPath = findExecutablePath("ldc");
            if (!compilerPath)
                compilerPath = findExecutablePath("gdc");
        } else if (compilerPath && !compilerPath.isAbsolute)
            compilerPath = findExecutablePath(compiler);
        string[] res;
        if (compilerPath)
            res = detectImportPathsForCompiler(compilerPath);
        else
            Log.w("Compiler executable not found for `", compiler, "`");
        Entry newItem = new Entry();
        newItem.list = res;
        _cache[compiler] = newItem;
        return res;
    }
}

__gshared CompilerImportPathsCache compilerImportPathsCache;

string[] detectImportPathsForCompiler(string compiler) {
    string[] res;
    import std.process : pipeProcess, Redirect, wait;
    import std.string : startsWith, indexOf;
    import std.path : buildNormalizedPath;
    import std.file : write, remove;
    import dlangui.core.files;
    try {
        string sourcefilename = appDataPath(".dlangide") ~ PATH_DELIMITER ~ "tmp_dummy_file_to_get_import_paths.d";
        write(sourcefilename, "import module_that_does_not_exist;\n");
        auto pipes = pipeProcess([compiler, sourcefilename], Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout, null, Config.suppressConsole);
        char[4096] buffer;
        char[] s = pipes.stdout.rawRead(buffer);
        wait(pipes.pid);
        //auto ls = execute([compiler, sourcefilename]);
        remove(sourcefilename);
        //string s = ls.output;
        string[] lines = splitByLines(cast(string)s);
        debug Log.d("compiler output:\n", s);
        foreach(line; lines) {
            if (line.startsWith("import path[")) {
                auto p = line.indexOf("] = ");
                if (p > 0) {
                    line = line[p + 4 .. $];
                    string path = line.buildNormalizedPath;
                    debug Log.d("import path found: `", path, "`");
                    res ~= path;
                }
            }
        }
        return res;
    } catch (Exception e) {
        return null;
    }
}
