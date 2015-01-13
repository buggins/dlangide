module dlangide.workspace.project;

import dlangide.workspace.workspace;
import dlangui.core.logger;
import std.path;
import std.file;
import std.json;
import std.utf;

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
    this(string fname = null) {
        super(fname);
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

