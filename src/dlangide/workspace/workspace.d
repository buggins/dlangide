module dlangide.workspace.workspace;

import dlangide.workspace.project;

/// DlangIDE workspace
class Workspace {
    protected string _dir;
    protected dstring _name;
    protected dstring _description;
    protected Project[] _projects;
}
