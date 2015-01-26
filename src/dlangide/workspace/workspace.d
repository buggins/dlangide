module dlangide.workspace.workspace;

import dlangide.workspace.project;
import dlangui.core.logger;
import std.path;
import std.file;
import std.json;
import std.utf;

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


/// DlangIDE workspace
class Workspace : WorkspaceItem {
    protected Project[] _projects;

    this(string fname = null) {
        super(fname);
    }

    @property Project[] projects() {
        return _projects;
    }

    /// tries to find source file in one of projects, returns found project source file item, or null if not found
    ProjectSourceFile findSourceFileItem(string filename) {
        foreach (Project p; _projects) {
            ProjectSourceFile res = p.findSourceFileItem(filename);
            if (res)
                return res;
        }
        return null;
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
                    path = buildNormalizedPath(_dir, path, "dub.json");
                Project project = new Project(path);
                _projects ~= project;
                project.load();

            }
        } catch (JSONException e) {
            Log.e("Cannot parse json", e);
            return false;
        } catch (Exception e) {
            Log.e("Cannot read workspace file", e);
            return false;
        }
        return true;
    }
    void close() {
    }
}

/// global workspace
__gshared Workspace currentWorkspace;
