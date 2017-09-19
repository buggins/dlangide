module dlangide.ui.wspanel;

import std.string;
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
        if (_workspace) {
            // save selected item id
            ProjectItem item = cast(ProjectItem)selectedItem.objectParam;
            if (item) {
                string id = item.filename;
                if (id)
                    _workspace.selectedWorkspaceItem = id;
            }
        }
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
        _tree = new TreeWidget("wstree", ScrollBarMode.Auto, ScrollBarMode.Auto);
        _tree.layoutHeight(FILL_PARENT).layoutHeight(FILL_PARENT);
        _tree.selectionChange = &onTreeItemSelected;
        _tree.expandedChange.connect(&onTreeExpandedStateChange);
        _tree.fontSize = 16;
        _tree.noCollapseForSingleTopLevelItem = true;
        _tree.popupMenu = &onTreeItemPopupMenu;

        _workspacePopupMenu = new MenuItem();
        _workspacePopupMenu.add(ACTION_PROJECT_FOLDER_REFRESH,
                                ACTION_FILE_WORKSPACE_CLOSE,
                                ACTION_PROJECT_FOLDER_EXPAND_ALL,
                                ACTION_PROJECT_FOLDER_COLLAPSE_ALL
                                );

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
                              ACTION_PROJECT_FOLDER_EXPAND_ALL,
                              ACTION_PROJECT_FOLDER_COLLAPSE_ALL
                              //ACTION_PROJECT_FOLDER_REMOVE_ITEM
                              );

        _folderPopupMenu = new MenuItem();
        _folderPopupMenu.add(ACTION_FILE_NEW_SOURCE_FILE, ACTION_PROJECT_FOLDER_REFRESH, ACTION_PROJECT_FOLDER_OPEN_ITEM,
                             ACTION_PROJECT_FOLDER_EXPAND_ALL, ACTION_PROJECT_FOLDER_COLLAPSE_ALL
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
    protected TreeItem _popupMenuSelectedItem;
    protected void onPopupMenuItem(MenuItem item) {
        if (item.action)
            handleAction(item.action);
    }

    protected MenuItem onTreeItemPopupMenu(TreeItems source, TreeItem selectedItem) {
        MenuItem menu = null;
        _popupMenuSelectedItemId = selectedItem.id;
        _popupMenuSelectedItem = selectedItem;
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

    /// returns currently selected project item
    @property ProjectItem selectedProjectItem() {
        TreeItem ti = _tree.items.selectedItem;
        if (!ti)
            return null;
        Object obj = ti.objectParam;
        if (!obj)
            return null;
        return cast(ProjectItem)obj;
    }

    ProjectSourceFile findSourceFileItem(string filename, bool fullFileName=true) {
        if (_workspace)
            return _workspace.findSourceFileItem(filename, fullFileName);
        return null;
    }

    /// Adding elements to the tree
    void addProjectItems(TreeItem root, ProjectItem items) {
        for (int i = 0; i < items.childCount; i++) {
            ProjectItem child = items.child(i);
            if (child.isFolder) {
                TreeItem p = root.newChild(child.filename, child.name, "folder");
                p.intParam = ProjectItemType.SourceFolder;
                p.objectParam = child;
                if (restoreItemState(child.filename))
                    p.expand();
                else
                    p.collapse();
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

    void expandAll(const Action a) {
        if (!_workspace)
            return;
        if (_popupMenuSelectedItem)
            _popupMenuSelectedItem.expandAll();
    }

    void collapseAll(const Action a) {
        if (!_workspace)
            return;
        if (_popupMenuSelectedItem)
            _popupMenuSelectedItem.collapseAll();
    }

    protected bool[string] _itemStates;
    protected bool _itemStatesDirty;
    protected void readExpandedStateFromWorkspace() {
        _itemStates.clear();
        if (_workspace) {
            string[] items = _workspace.expandedItems;
            foreach(item; items)
                _itemStates[item] = true;
        }
    }

    /// Saving items collapse/expand state
    protected void saveItemState(string itemPath, bool expanded) {
        bool changed = restoreItemState(itemPath) != expanded;
        if (!_itemStatesDirty && changed)
            _itemStatesDirty = true;
        if (changed) {
            if (expanded) {
                _itemStates[itemPath] = true;
            } else {
                _itemStates.remove(itemPath);
            }
            string[] items;
            items.assumeSafeAppend;
            foreach(k,v; _itemStates) {
                items ~= k;
            }
            _workspace.expandedItems = items;
        }
        debug Log.d("stored Expanded state ", expanded, " for ", itemPath);
    }
    /// Is need to expand item?
    protected bool restoreItemState(string itemPath) {
        if (auto p = itemPath in _itemStates) {
            // Item itself must expand, but upper items may be collapsed
            auto path = itemPath;
            while (path.length > 0 && !path.endsWith("src") && path in _itemStates) {
                auto pos = lastIndexOf(path, '/');
                path = pos > -1 ? path[ 0 ..  pos ] : "";
            }
            if (path.length == 0 || path.endsWith("src")) {
                debug Log.d("restored Expanded state for ", itemPath);
                return *p;
            }
        }
        return false;
    }

    void onTreeExpandedStateChange(TreeItems source, TreeItem item) {
        bool expanded = item.expanded;
        ProjectItem prjItem = cast(ProjectItem)item.objectParam;
        if (prjItem) {
            string fn = prjItem.filename;
            debug Log.d("onTreeExpandedStateChange expanded=", expanded, " fn=", fn);
            saveItemState(fn, expanded);
        }
    }

    void reloadItems() {
        _tree.expandedChange.disconnect(&onTreeExpandedStateChange);
        _tree.clearAllItems();
        if (_workspace) {
            TreeItem defaultItem = null;
            TreeItem root = _tree.items.newChild(_workspace.filename, _workspace.name, "project-development");
            root.intParam = ProjectItemType.Workspace;
            foreach(project; _workspace.projects) {
                TreeItem p = root.newChild(project.filename, project.name, project.isDependency ? "project-d-dependency" : "project-d");
                p.intParam = ProjectItemType.Project;
                p.objectParam = project;
                if (restoreItemState(project.filename))
                    p.expand();
                else
                    p.collapse();
                if (project && _workspace.startupProject is project)
                    defaultItem = p;
                addProjectItems(p, project.items);
            }
            _tree.items.setDefaultItem(defaultItem);
        } else {
            _tree.items.newChild("none", "No workspace"d, "project-development");
        }
        _tree.expandedChange.connect(&onTreeExpandedStateChange);

        // expand default project if no information about expanded items
        if (!_itemStates.length) {
            if (_workspace && _workspace.startupProject) {
                string fn = _workspace.startupProject.filename;
                TreeItem startupProjectItem = _tree.items.findItemById(fn);
                if (startupProjectItem) {
                    startupProjectItem.expand();
                    saveItemState(fn, true);
                }
            }
        }
        if (_workspace) {
            // restore selection
            string id = _workspace.selectedWorkspaceItem;
            _tree.selectItem(id);
        }

        updateDefault();
    }

    @property void workspace(Workspace w) {
        _workspace = w;
        readExpandedStateFromWorkspace();
        reloadItems();
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        if (workspaceActionListener.assigned)
            return workspaceActionListener(a);
        return false;
    }

    override protected bool onCloseButtonClick(Widget source) {
        hide();
        return true;
    }

    /// hide workspace panel
    void hide() {
        visibility = Visibility.Gone;
        parent.layout(parent.pos);
    }

    // activate workspace panel if hidden
    void activate() {
        if (visibility == Visibility.Gone) {
            visibility = Visibility.Visible;
            parent.layout(parent.pos);
        }
        setFocus();
    }
}
