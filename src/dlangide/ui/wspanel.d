module dlangide.ui.wspanel;

import dlangui.all;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

enum ProjectItemType : int {
    None,
    SourceFile,
    SourceFolder,
    Project,
    Workspace
}

interface SourceFileSelectionHandler {
    bool onSourceFileSelected(ProjectSourceFile file, bool activate);
}

class WorkspacePanel : DockWindow {
    protected Workspace _workspace;
    protected TreeWidget _tree;

    /// handle source file selection change
    Signal!SourceFileSelectionHandler sourceFileSelectionListener;

    this(string id) {
        super(id);
        workspace = null;
        //layoutWidth = 200;
        _caption.text = "Workspace Explorer"d;
    }

    bool selectItem(ProjectItem projectItem) {
        TreeItem item = _tree.findItemById(projectItem.filename);
        if (item) {
            _tree.selectItem(item);
            return true;
        }
        return false;
    }

    void onTreeItemSelected(TreeItems source, TreeItem selectedItem, bool activated) {
        if (selectedItem.intParam == ProjectItemType.SourceFile) {
            // file selected
            if (sourceFileSelectionListener.assigned) {
                ProjectSourceFile sourceFile = cast(ProjectSourceFile)selectedItem.objectParam;
                if (sourceFile) {
                    sourceFileSelectionListener(sourceFile, activated);
                }
            }
        } else if (selectedItem.intParam == ProjectItemType.SourceFolder) {
            // folder selected
        }
    }

    override protected Widget createBodyWidget() {
        _tree = new TreeWidget("wstree");
        _tree.layoutHeight(FILL_PARENT).layoutHeight(FILL_PARENT);
        _tree.selectionListener = &onTreeItemSelected;
		_tree.fontSize = 16;
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
                p.intParam = ProjectItemType.SourceFolder;
                p.objectParam = child;
                addProjectItems(p, child);
            } else {
                TreeItem p = root.newChild(child.filename, child.name, "text-plain");
                p.intParam = ProjectItemType.SourceFile;
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
            root.intParam = ProjectItemType.Workspace;
            foreach(project; w.projects) {
                TreeItem p = root.newChild(project.filename, project.name, "project-open");
                p.intParam = ProjectItemType.Project;
                addProjectItems(p, project.items);
            }
        } else {
            _tree.items.newChild("none", "New workspace"d, "project-development");
        }
        _tree.onTreeContentChange(null);
    }
}
