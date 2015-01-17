module dlangide.ui.wspanel;

import dlangui.all;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

class WorkspacePanel : DockWindow {
    protected Workspace _workspace;
    protected TreeWidget _tree;

    this(string id) {
        super(id);
        workspace = null;
        //layoutWidth = 200;
        _caption.text = "Workspace Explorer"d;
    }

    override protected Widget createBodyWidget() {
        _tree = new TreeWidget("wstree");
        _tree.layoutHeight(FILL_PARENT).layoutHeight(FILL_PARENT);
        return _tree;
    }

    @property Workspace workspace() {
        return _workspace;
    }

    void addProjectItems(TreeItem root, ProjectItem items) {
        for (int i = 0; i < items.childCount; i++) {
            ProjectItem child = items.child(i);
            if (child.isFolder) {
                TreeItem p = root.newChild(child.filename, child.name, "folder");
                p.objectParam = child;
                addProjectItems(p, child);
            } else {
                TreeItem p = root.newChild(child.filename, child.name, "text-plain");
                p.objectParam = child;
            }
        }
    }

    @property void workspace(Workspace w) {
        _workspace = w;
        _tree.requestLayout();
        _tree.items.clear();
        if (w) {
            TreeItem root = _tree.items.newChild(w.filename, w.name, "project-development");
            foreach(project; w.projects) {
                TreeItem p = root.newChild(project.filename, project.name, "project-open");
                addProjectItems(p, project.items);
            }
        } else {
            _tree.items.newChild("none", "New workspace"d, "project-development");
        }
        _tree.onTreeContentChange(null);
    }
}
