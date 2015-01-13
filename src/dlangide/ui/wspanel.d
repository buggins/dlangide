module dlangide.ui.wspanel;

import dlangui.all;
import dlangide.workspace.workspace;

class WorkspacePanel : VerticalLayout {
    protected Workspace _workspace;
    protected TreeWidget _tree;

    this(string id) {
        super(id);
        layoutHeight = FILL_PARENT;
        layoutWidth = 200;
        _tree = new TreeWidget("wstree");
        _tree.layoutHeight = FILL_PARENT;
        addChild(_tree);
        workspace = null;
    }

    @property Workspace workspace() {
        return _workspace;
    }

    @property void workspace(Workspace w) {
        _workspace = w;
        _tree.requestLayout();
        _tree.items.clear();
        if (w) {
            TreeItem root = _tree.items.newChild(w.filename, w.name, "project-development");
            foreach(project; w.projects) {
                TreeItem p = root.newChild(project.filename, project.name, "project-open");
            }
        } else {
            _tree.items.newChild("none", "New workspace"d, "project-development");
        }
        _tree.onTreeContentChange(null);
    }
}
