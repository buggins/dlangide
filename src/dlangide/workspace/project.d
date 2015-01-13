module dlangide.workspace.project;

import dlangide.workspace.workspace;
import dlangui.core.logger;
import dlangui.core.collections;
import std.path;
import std.file;
import std.json;
import std.utf;

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
        return false;
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
        item._project = this;
    }
    bool loadDir(string path) {
        string src = relativeToAbsolutePath(path);
        if (isDir(src) && exists(src)) {
            ProjectFolder dir = new ProjectFolder(src);
            addChild(dir);
            dir.loadItems();
            return true;
        }
        return false;
    }
    bool loadFile(string path) {
        string src = relativeToAbsolutePath(path);
        if (isFile(src) && exists(src)) {
            ProjectSourceFile f = new ProjectSourceFile(src);
            addChild(f);
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

    bool save() {
        return false;
    }
}

/// DLANGIDE D project
class Project : WorkspaceItem {
    protected Workspace _workspace;
    protected bool _opened;
    protected ProjectFolder _items;
    this(string fname = null) {
        super(fname);
        _items = new ProjectFolder(fname);
    }

    string relativeToAbsolutePath(string path) {
        if (isAbsolute(path))
            return path;
        return buildNormalizedPath(_dir, path);
    }

    @property Workspace workspace() {
        return _workspace;
    }

    @property void workspace(Workspace p) {
        _workspace = p;
    }

    ProjectFolder findItems() {
        ProjectFolder folder = new ProjectFolder(_filename);
        folder.project = this;
        folder.loadDir(relativeToAbsolutePath("src"));
        folder.loadDir(relativeToAbsolutePath("source"));
        return folder;
    }

    override bool load(string fname = null) {
        if (fname.length > 0)
            filename = fname;
        if (!exists(filename) || !isFile(filename))  {
            return false;
        }
        Log.d("Reading project from file ", _filename);

        try {
            string jsonSource = readText!string(_filename);
            JSONValue json = parseJSON(jsonSource);
            _name = toUTF32(json["name"].str);
            _description = toUTF32(json["description"].str);
            Log.d("  project name: ", _name);
            Log.d("  project description: ", _description);

            _items = findItems();
        } catch (JSONException e) {
            Log.e("Cannot parse json", e);
            return false;
        } catch (Exception e) {
            Log.e("Cannot read project file", e);
            return false;
        }
        return true;
    }
}

