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

interface WorkspaceActionHandler {
    bool onWorkspaceAction(const Action a);
}

class WorkspacePanel : DockWindow {
    protected Workspace _workspace;
    protected TreeWidget _tree;

    /// handle source file selection change
    Signal!SourceFileSelectionHandler sourceFileSelectionListener;
    Signal!WorkspaceActionHandler workspaceActionListener;

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
        _tree.selectionChange = &onTreeItemSelected;
        _tree.fontSize = 16;
        _tree.noCollapseForSingleTopLevelItem = true;
        _tree.popupMenu = &onTreeItemPopupMenu;

        _workspacePopupMenu = new MenuItem();
        _workspacePopupMenu.add(ACTION_PROJECT_FOLDER_REFRESH, 
                                ACTION_FILE_WORKSPACE_CLOSE);

        _projectPopupMenu = new MenuItem();
        _projectPopupMenu.add(ACTION_PROJECT_SET_STARTUP,
                              ACTION_PROJECT_FOLDER_REFRESH,
                              ACTION_FILE_NEW_SOURCE_FILE,
                              //ACTION_PROJECT_FOLDER_OPEN_ITEM,
                              ACTION_PROJECT_BUILD,
                              ACTION_PROJECT_REBUILD,
                              ACTION_PROJECT_CLEAN,
                              ACTION_PROJECT_UPDATE_DEPENDENCIES,
                              ACTION_PROJECT_REVEAL_IN_EXPLORER,
                              ACTION_PROJECT_SETTINGS,
                              //ACTION_PROJECT_FOLDER_REMOVE_ITEM
                              );

        _folderPopupMenu = new MenuItem();
        _folderPopupMenu.add(ACTION_FILE_NEW_SOURCE_FILE, ACTION_PROJECT_FOLDER_REFRESH, ACTION_PROJECT_FOLDER_OPEN_ITEM, 
                             //ACTION_PROJECT_FOLDER_REMOVE_ITEM, 
                             //ACTION_PROJECT_FOLDER_RENAME_ITEM
                             );

        _filePopupMenu = new MenuItem();
        _filePopupMenu.add(ACTION_FILE_NEW_SOURCE_FILE, ACTION_PROJECT_FOLDER_REFRESH, 
                           ACTION_PROJECT_FOLDER_OPEN_ITEM, 
                           ACTION_PROJECT_FOLDER_REMOVE_ITEM, 
                           //ACTION_PROJECT_FOLDER_RENAME_ITEM
                           );
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
            for (int i = 0; i < menu.subitemCount; i++) {
                Action a = menu.subitem(i).action.clone();
                a.objectParam = selectedItem.objectParam;
                menu.subitem(i).action = a;
                //menu.subitem(i).menuItemAction = &handleAction;
            }
            //menu.onMenuItem = &onPopupMenuItem;
            //menu.menuItemClick = &onPopupMenuItem;
            menu.menuItemAction = &handleAction;
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
                string icon = "text-other";
                if (child.isDSourceFile)
                    icon = "text-d";
                if (child.isJsonFile)
                    icon = "text-json";
                if (child.isDMLFile)
                    icon = "text-dml";
                TreeItem p = root.newChild(child.filename, child.name, icon);
                p.intParam = ProjectItemType.SourceFile;
                p.objectParam = child;
            }
        }
    }

    void updateDefault() {
        TreeItem defaultItem = null;
        if (_workspace && _tree.items.childCount && _workspace.startupProject) {
            for (int i = 0; i < _tree.items.child(0).childCount; i++) {
                TreeItem p = _tree.items.child(0).child(i);
                if (p.objectParam is _workspace.startupProject)
                    defaultItem = p;
            }
        }
        _tree.items.setDefaultItem(defaultItem);
    }

    void reloadItems() {
        _tree.clearAllItems();
        if (_workspace) {
            TreeItem defaultItem = null;
            TreeItem root = _tree.items.newChild(_workspace.filename, _workspace.name, "project-development");
            root.intParam = ProjectItemType.Workspace;
            foreach(project; _workspace.projects) {
                TreeItem p = root.newChild(project.filename, project.name, project.isDependency ? "project-d-dependency" : "project-d");
                p.intParam = ProjectItemType.Project;
                p.objectParam = project;
                if (project && _workspace.startupProject is project)
                    defaultItem = p;
                addProjectItems(p, project.items);
            }
            _tree.items.setDefaultItem(defaultItem);
        } else {
            _tree.items.newChild("none", "No workspace"d, "project-development");
        }
        _tree.onTreeContentChange(null);
        if (_workspace) {
            TreeItem root = _tree.items.child(0);
            for (int i = 0; i < root.childCount; i++) {
                TreeItem child = root.child(i);
                if (child.intParam == ProjectItemType.Project) {
                    Object obj = child.objectParam;
                    Project prj = cast(Project)obj;
                    if (prj && prj.isDependency)
                        child.collapse();
                }
            }
        }
        updateDefault();
    }

    @property void workspace(Workspace w) {
        _workspace = w;
        reloadItems();
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        if (workspaceActionListener.assigned)
            return workspaceActionListener(a);
        return false;
    }
}
