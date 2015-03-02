module dlangide.ui.wspanel;

import dlangui;
import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.ui.commands;

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
        if (projectItem) {
            TreeItem item = _tree.findItemById(projectItem.filename);
            if (item) {
                _tree.selectItem(item);
                return true;
            }
        } else {
            _tree.clearSelection();
            return true;
        }
        return false;
    }

    void onTreeItemSelected(TreeItems source, TreeItem selectedItem, bool activated) {
        if (!selectedItem)
            return;
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
        _tree.noCollapseForSingleTopLevelItem = true;
        _tree.popupMenuListener = &onTreeItemPopupMenu;

        _workspacePopupMenu = new MenuItem();
        _workspacePopupMenu.add(ACTION_PROJECT_FOLDER_ADD_ITEM);

        _projectPopupMenu = new MenuItem();
        _projectPopupMenu.add(ACTION_PROJECT_FOLDER_ADD_ITEM, ACTION_PROJECT_FOLDER_OPEN_ITEM,
                           ACTION_PROJECT_FOLDER_REMOVE_ITEM);

        _folderPopupMenu = new MenuItem();
        _folderPopupMenu.add(ACTION_PROJECT_FOLDER_ADD_ITEM, ACTION_PROJECT_FOLDER_OPEN_ITEM, 
                             ACTION_PROJECT_FOLDER_REMOVE_ITEM, ACTION_PROJECT_FOLDER_RENAME_ITEM);
        _filePopupMenu = new MenuItem();
        _filePopupMenu.add(ACTION_PROJECT_FOLDER_ADD_ITEM, ACTION_PROJECT_FOLDER_OPEN_ITEM, 
                             ACTION_PROJECT_FOLDER_REMOVE_ITEM, ACTION_PROJECT_FOLDER_RENAME_ITEM);
        return _tree;
    }

    protected MenuItem _workspacePopupMenu;
    protected MenuItem _projectPopupMenu;
    protected MenuItem _folderPopupMenu;
    protected MenuItem _filePopupMenu;
    protected string _popupMenuSelectedItemId;
    protected void onPopupMenuItem(MenuItem item) {
        if (item.action)
            handleAction(item.action);
    }

    protected MenuItem onTreeItemPopupMenu(TreeItems source, TreeItem selectedItem) {
        MenuItem menu = null;
        _popupMenuSelectedItemId = selectedItem.id;
        if (selectedItem.intParam == ProjectItemType.SourceFolder) {
            menu = _folderPopupMenu;
        } else if (selectedItem.intParam == ProjectItemType.SourceFile) {
            menu = _filePopupMenu;
        } else if (selectedItem.intParam == ProjectItemType.Project) {
            menu = _projectPopupMenu;
        } else if (selectedItem.intParam == ProjectItemType.Workspace) {
            menu = _workspacePopupMenu;
        }
        if (menu && menu.subitemCount) {
            menu.onMenuItem = &onPopupMenuItem;
            menu.updateActionState(this);
            return menu;
        }
        return null;
    }

    @property Workspace workspace() {
        return _workspace;
    }

    ProjectSourceFile findSourceFileItem(string filename, bool fullFileName=true) {
        if (_workspace)
			return _workspace.findSourceFileItem(filename, fullFileName);
        return null;
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
                TreeItem p = root.newChild(child.filename, child.name, "text-d");
                p.intParam = ProjectItemType.SourceFile;
                p.objectParam = child;
            }
        }
    }

    void reloadItems() {
        _tree.clearAllItems();
        if (_workspace) {
            TreeItem root = _tree.items.newChild(_workspace.filename, _workspace.name, "project-development");
            root.intParam = ProjectItemType.Workspace;
            foreach(project; _workspace.projects) {
                TreeItem p = root.newChild(project.filename, project.name, project.isDependency ? "project-d-dependency" : "project-d");
                p.intParam = ProjectItemType.Project;
                addProjectItems(p, project.items);
            }
        } else {
            _tree.items.newChild("none", "No workspace"d, "project-development");
        }
        _tree.onTreeContentChange(null);
    }

    @property void workspace(Workspace w) {
        _workspace = w;
        reloadItems();
    }
}
