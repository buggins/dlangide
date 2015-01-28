module dlangide.builders.builder;

import dlangide.workspace.project;

class Builder {
    protected Project _project;

    @property Project project() { return _project; }
    @property void project(Project p) { _project = p; }

}
