module dlangide.ui.frame;

import dlangui.widgets.menu;
import dlangui.widgets.tabs;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;
import dlangui.widgets.controls;
import dlangui.widgets.appframe;
import dlangui.widgets.docks;
import dlangui.widgets.toolbars;
import dlangui.widgets.combobox;
import dlangui.widgets.popup;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import dlangui.core.stdaction;
import dlangui.core.files;

import dlangide.ui.commands;
import dlangide.ui.wspanel;
import dlangide.ui.outputpanel;
import dlangide.ui.dsourceedit;
import dlangide.ui.homescreen;
import dlangide.tools.d.dcdserver;
import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.builders.builder;
import dlangide.tools.editorTool;

import std.conv;
import std.utf;
import std.algorithm;
import std.path;

bool isSupportedSourceTextFileFormat(string filename) {
    return (filename.endsWith(".d") || filename.endsWith(".txt") || filename.endsWith(".cpp") || filename.endsWith(".h") || filename.endsWith(".c")
        || filename.endsWith(".json") || filename.endsWith(".dd") || filename.endsWith(".ddoc") || filename.endsWith(".xml") || filename.endsWith(".html")
        || filename.endsWith(".html") || filename.endsWith(".css") || filename.endsWith(".log") || filename.endsWith(".hpp"));
}

class BackgroundOperationWatcherTest : BackgroundOperationWatcher {
    this(AppFrame frame) {
        super(frame);
    }
    int _counter;
    /// returns description of background operation to show in status line
    override @property dstring description() { return "Test progress: "d ~ to!dstring(_counter); }
    /// returns icon of background operation to show in status line
    override @property string icon() { return "folder"; }
    /// update background operation status
    override void update() {
        _counter++;
        if (_counter >= 100)
            _finished = true;
        super.update();
    }
}

/// DIDE app frame
class IDEFrame : AppFrame {

    MenuItem mainMenuItems;
    WorkspacePanel _wsPanel;
    OutputPanel _logPanel;
    DockHost _dockHost;
    TabWidget _tabs;
    EditorTool _editorTool;
    DCDServer _dcdServer;

    dstring frameWindowCaptionSuffix = "DLangIDE"d;

    this(Window window) {
        super();
        window.mainWidget = this;
        window.onFilesDropped = &onFilesDropped;
        window.onCanClose = &onCanClose;
        window.onClose = &onWindowClose;
    }

    override protected void init() {
        _appName = "dlangide";
        _editorTool = new DEditorTool(this);
        _dcdServer = new DCDServer();

        super.init();
    }

    /// move focus to editor in currently selected tab
    void focusEditor(string id) {
        Widget w = _tabs.tabBody(id);
        if (w) {
            if (w.visible)
                w.setFocus();
        }
    }

    /// source file selected in workspace tree
    bool onSourceFileSelected(ProjectSourceFile file, bool activate) {
        Log.d("onSourceFileSelected ", file.filename);
        return openSourceFile(file.filename, file, activate);
    }

	///
	bool onCompilerLogIssueClick(dstring filename, int line, int column)
	{
		Log.d("onCompilerLogIssueClick ", filename);

		import std.conv:to;
		openSourceFile(to!string(filename));

		currentEditor().setCaretPos(line-1,column);

		return true;
	}

    void onModifiedStateChange(Widget source, bool modified) {
        //
        Log.d("onModifiedStateChange ", source.id, " modified=", modified);
        int index = _tabs.tabIndex(source.id);
        if (index >= 0) {
            dstring name = toUTF32((modified ? "* " : "") ~ baseName(source.id));
            _tabs.renameTab(index, name);
        }
    }

    bool openSourceFile(string filename, ProjectSourceFile file = null, bool activate = true) {
        if (!file && !filename)
            return false;
        if (!file)
            file = _wsPanel.findSourceFileItem(filename, false);

		//if(!file)
		//	return false;

        if (file)
		    filename = file.filename;

		Log.d("openSourceFile ", filename);
		int index = _tabs.tabIndex(filename);
        if (index >= 0) {
            // file is already opened in tab
            _tabs.selectTab(index, true);
        } else {
            // open new file
            DSourceEdit editor = new DSourceEdit(filename);
            if (file ? editor.load(file) : editor.load(filename)) {
                _tabs.addTab(editor, toUTF32(baseName(filename)), null, true);
                index = _tabs.tabIndex(filename);
                TabItem tab = _tabs.tab(filename);
                tab.objectParam = file;
                editor.onModifiedStateChangeListener = &onModifiedStateChange;
                _tabs.selectTab(index, true);
            } else {
                destroy(editor);
                if (window)
                    window.showMessageBox(UIString("File open error"d), UIString("Failed to open file "d ~ toUTF32(file.filename)));
                return false;
            }
        }
        if (activate) {
            focusEditor(filename);
        }
        requestLayout();
        return true;
    }

    static immutable HOME_SCREEN_ID = "HOME_SCREEN";
    void showHomeScreen() {
        int index = _tabs.tabIndex(HOME_SCREEN_ID);
        if (index >= 0) {
            _tabs.selectTab(index, true);
        } else {
            HomeScreen home = new HomeScreen(HOME_SCREEN_ID, this);
            _tabs.addTab(home, "Home"d, null, true);
            _tabs.selectTab(HOME_SCREEN_ID, true);
        }
    }

    void onTabChanged(string newActiveTabId, string previousTabId) {
        int index = _tabs.tabIndex(newActiveTabId);
        if (index >= 0) {
            TabItem tab = _tabs.tab(index);
            ProjectSourceFile file = cast(ProjectSourceFile)tab.objectParam;
            if (file) {
                //setCurrentProject(file.project);
                // tab is source file editor
                _wsPanel.selectItem(file);
                focusEditor(file.filename);
            }
            window.windowCaption(tab.text.value ~ " - "d ~ frameWindowCaptionSuffix);
        }
    }

    // returns DSourceEdit from currently active tab (if it's editor), null if current tab is not editor or no tabs open
    DSourceEdit currentEditor() {
        return cast(DSourceEdit)_tabs.selectedTabBody();
    }

    /// close tab w/o confirmation
    void closeTab(string tabId) {
        _wsPanel.selectItem(null);
        _tabs.removeTab(tabId);
    }

    /// close all editor tabs
    void closeAllDocuments() {
        for (int i = _tabs.tabCount - 1; i >= 0; i--) {
            DSourceEdit ed = cast(DSourceEdit)_tabs.tabBody(i);
            if (ed) {
                closeTab(ed.id);
            }
        }
    }

    /// returns first unsaved document
    protected DSourceEdit hasUnsavedEdits() {
        for (int i = _tabs.tabCount - 1; i >= 0; i--) {
            DSourceEdit ed = cast(DSourceEdit)_tabs.tabBody(i);
            if (ed && ed.content.modified) {
                return ed;
            }
        }
        return null;
    }

    protected void askForUnsavedEdits(void delegate() onConfirm) {
        DSourceEdit ed = hasUnsavedEdits();
        if (!ed) {
            // no unsaved edits
            onConfirm();
            return;
        }
        string tabId = ed.id;
        // tab content is modified - ask for confirmation
        window.showMessageBox(UIString("Close file "d ~ toUTF32(baseName(tabId))), UIString("Content of this file has been changed."d), 
                              [ACTION_SAVE, ACTION_SAVE_ALL, ACTION_DISCARD_CHANGES, ACTION_DISCARD_ALL, ACTION_CANCEL], 
                              0, delegate(const Action result) {
                                  if (result == StandardAction.Save) {
                                      // save and close
                                      ed.save();
                                      askForUnsavedEdits(onConfirm);
                                  } else if (result == StandardAction.DiscardChanges) {
                                      // close, don't save
                                      closeTab(tabId);
                                      closeAllDocuments();
                                      onConfirm();
                                  } else if (result == StandardAction.SaveAll) {
                                      ed.save();
                                      for(;;) {
                                          DSourceEdit editor = hasUnsavedEdits();
                                          if (!editor)
                                              break;
                                          editor.save();
                                      }
                                      closeAllDocuments();
                                      onConfirm();
                                  } else if (result == StandardAction.DiscardAll) {
                                      // close, don't save
                                      closeAllDocuments();
                                      onConfirm();
                                  }
                                  // else ignore
                                  return true;
                              });
    }

    protected void onTabClose(string tabId) {
        Log.d("onTabClose ", tabId);
        int index = _tabs.tabIndex(tabId);
        if (index >= 0) {
            DSourceEdit d = cast(DSourceEdit)_tabs.tabBody(tabId);
            if (d && d.content.modified) {
                // tab content is modified - ask for confirmation
                window.showMessageBox(UIString("Close tab"d), UIString("Content of "d ~ toUTF32(baseName(tabId)) ~ " file has been changed."d), 
                                      [ACTION_SAVE, ACTION_DISCARD_CHANGES, ACTION_CANCEL], 
                                      0, delegate(const Action result) {
                                          if (result == StandardAction.Save) {
                                              // save and close
                                              d.save();
                                              closeTab(tabId);
                                          } else if (result == StandardAction.DiscardChanges) {
                                              // close, don't save
                                              closeTab(tabId);
                                          }
                                          // else ignore
                                          return true;
                                      });
            } else {
                closeTab(tabId);
            }
        }
    }

    /// create app body widget
    override protected Widget createBody() {
        _dockHost = new DockHost();

        //=============================================================
        // Create body - Tabs

        // editor tabs
        _tabs = new TabWidget("TABS");
        _tabs.hiddenTabsVisibility = Visibility.Gone;
        _tabs.setStyles(STYLE_DOCK_HOST_BODY, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT);
        _tabs.onTabChangedListener = &onTabChanged;
        _tabs.onTabCloseListener = &onTabClose;

        _dockHost.bodyWidget = _tabs;

        //=============================================================
        // Create workspace docked panel
        _wsPanel = new WorkspacePanel("workspace");
        _wsPanel.sourceFileSelectionListener = &onSourceFileSelected;
        _wsPanel.dockAlignment = DockAlignment.Left;
        _dockHost.addDockedWindow(_wsPanel);

        _logPanel = new OutputPanel("output");
		_logPanel.compilerLogIssueClickHandler = &onCompilerLogIssueClick;
        _logPanel.appendText(null, "DlangIDE is started\nHINT: Try to open some DUB project\n"d);
        string dubPath = findExecutablePath("dub");
        string dmdPath = findExecutablePath("dmd");
        string ldcPath = findExecutablePath("ldc2");
        string gdcPath = findExecutablePath("gdc");
        _logPanel.appendText(null, dubPath ? ("dub path: "d ~ toUTF32(dubPath) ~ "\n"d) : ("dub is not found! cannot build projects without DUB\n"d));
        _logPanel.appendText(null, dmdPath ? ("dmd path: "d ~ toUTF32(dmdPath) ~ "\n"d) : ("dmd compiler is not found!\n"d));
        _logPanel.appendText(null, ldcPath ? ("ldc path: "d ~ toUTF32(ldcPath) ~ "\n"d) : ("ldc compiler is not found!\n"d));
        _logPanel.appendText(null, gdcPath ? ("gdc path: "d ~ toUTF32(gdcPath) ~ "\n"d) : ("gdc compiler is not found!\n"d));

        if (_dcdServer.start()) {
            _logPanel.appendText(null, "dcd-server is started on port "d ~ to!dstring(_dcdServer.port) ~ "\n"d);
        } else {
            _logPanel.appendText(null, "cannot start dcd-server: code completion for D code will not work"d);
        }

        _dockHost.addDockedWindow(_logPanel);

        return _dockHost;
    }

    /// create main menu
    override protected MainMenu createMainMenu() {

        mainMenuItems = new MenuItem();
        MenuItem fileItem = new MenuItem(new Action(1, "MENU_FILE"));
        MenuItem fileNewItem = new MenuItem(new Action(1, "MENU_FILE_NEW"));
        fileNewItem.add(ACTION_FILE_NEW_SOURCE_FILE, ACTION_FILE_NEW_WORKSPACE, ACTION_FILE_NEW_PROJECT);
        fileItem.add(fileNewItem);
        fileItem.add(ACTION_FILE_OPEN_WORKSPACE, ACTION_FILE_OPEN, 
                     ACTION_FILE_SAVE, ACTION_FILE_SAVE_AS, ACTION_FILE_SAVE_ALL, ACTION_FILE_EXIT);

        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));
		editItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, 
                     ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO);
        MenuItem editItemAdvanced = new MenuItem(new Action(221, "MENU_EDIT_ADVANCED"));
		editItemAdvanced.add(ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT, ACTION_EDIT_TOGGLE_BLOCK_COMMENT);
		editItem.add(editItemAdvanced);

		editItem.add(ACTION_EDIT_PREFERENCES);

        MenuItem navItem = new MenuItem(new Action(21, "MENU_NAVIGATE"));
        navItem.add(ACTION_GO_TO_DEFINITION, ACTION_GET_COMPLETIONS);

        MenuItem projectItem = new MenuItem(new Action(21, "MENU_PROJECT"));
        projectItem.add(ACTION_PROJECT_SET_STARTUP, ACTION_PROJECT_REFRESH, ACTION_PROJECT_UPDATE_DEPENDENCIES, ACTION_PROJECT_SETTINGS);

        MenuItem buildItem = new MenuItem(new Action(22, "MENU_BUILD"));
        buildItem.add(ACTION_WORKSPACE_BUILD, ACTION_WORKSPACE_REBUILD, ACTION_WORKSPACE_CLEAN,
                     ACTION_PROJECT_BUILD, ACTION_PROJECT_REBUILD, ACTION_PROJECT_CLEAN);

        MenuItem debugItem = new MenuItem(new Action(23, "MENU_DEBUG"));
        debugItem.add(ACTION_DEBUG_START, ACTION_DEBUG_START_NO_DEBUG, 
                      ACTION_DEBUG_CONTINUE, ACTION_DEBUG_STOP, ACTION_DEBUG_PAUSE);


		MenuItem windowItem = new MenuItem(new Action(3, "MENU_WINDOW"c));
        windowItem.add(new Action(30, "MENU_WINDOW_PREFERENCES"));
        windowItem.add(ACTION_WINDOW_CLOSE_ALL_DOCUMENTS);
        MenuItem helpItem = new MenuItem(new Action(4, "MENU_HELP"c));
        helpItem.add(new Action(40, "MENU_HELP_VIEW_HELP"));
        helpItem.add(ACTION_HELP_ABOUT);
        mainMenuItems.add(fileItem);
        mainMenuItems.add(editItem);
        mainMenuItems.add(projectItem);
        mainMenuItems.add(navItem);
        mainMenuItems.add(buildItem);
        mainMenuItems.add(debugItem);
		//mainMenuItems.add(viewItem);
		mainMenuItems.add(windowItem);
        mainMenuItems.add(helpItem);

        MainMenu mainMenu = new MainMenu(mainMenuItems);
        mainMenu.backgroundColor = 0xd6dbe9;
        return mainMenu;
    }

    /// override it
    override protected void updateShortcuts() {
        if (applyShortcutsSettings()) {
            Log.d("Shortcut actions loaded");
        } else {
            Log.d("Saving default shortcuts");
            const(Action)[] actions;
            actions ~= [
                ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, 
                ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, 
                ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT, ACTION_EDIT_TOGGLE_BLOCK_COMMENT, 
                ACTION_EDIT_PREFERENCES, 
                ACTION_FILE_NEW_SOURCE_FILE, ACTION_FILE_NEW_WORKSPACE, ACTION_FILE_NEW_PROJECT, ACTION_FILE_OPEN_WORKSPACE, ACTION_FILE_OPEN, 
                ACTION_FILE_SAVE, ACTION_FILE_SAVE_AS, ACTION_FILE_SAVE_ALL, ACTION_FILE_EXIT, 
                ACTION_PROJECT_SET_STARTUP, ACTION_PROJECT_REFRESH, ACTION_PROJECT_UPDATE_DEPENDENCIES, 
                ACTION_PROJECT_SETTINGS, ACTION_WORKSPACE_BUILD, ACTION_WORKSPACE_REBUILD, ACTION_WORKSPACE_CLEAN,
                ACTION_PROJECT_BUILD, ACTION_PROJECT_REBUILD, ACTION_PROJECT_CLEAN, ACTION_DEBUG_START, 
                ACTION_DEBUG_START_NO_DEBUG, ACTION_DEBUG_CONTINUE, ACTION_DEBUG_STOP, ACTION_DEBUG_PAUSE, 
                ACTION_WINDOW_CLOSE_ALL_DOCUMENTS, ACTION_HELP_ABOUT];
            actions ~= STD_EDITOR_ACTIONS;
            saveShortcutsSettings(actions);
        }
    }

    /// create app toolbars
    override protected ToolBarHost createToolbars() {
        ToolBarHost res = new ToolBarHost();
        ToolBar tb;
        tb = res.getOrAddToolbar("Standard");
        tb.addButtons(ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_SEPARATOR);

        tb.addButtons(ACTION_DEBUG_START);
        ToolBarComboBox cbBuildConfiguration = new ToolBarComboBox("buildConfig", ["Debug"d, "Release"d, "Unittest"d]);
        cbBuildConfiguration.onItemClickListener = delegate(Widget source, int index) {
            if (currentWorkspace && index < 3) {
                currentWorkspace.buildConfiguration = [BuildConfiguration.Debug, BuildConfiguration.Release, BuildConfiguration.Unittest][index];
            }
            return true;
        };
        cbBuildConfiguration.action = ACTION_BUILD_CONFIGURATIONS;
        tb.addControl(cbBuildConfiguration);
        tb.addButtons(ACTION_PROJECT_BUILD);

        tb = res.getOrAddToolbar("Edit");
        tb.addButtons(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_SEPARATOR,
                      ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT);
        return res;
    }

	/// override to handle specific actions state (e.g. change enabled state for supported actions)
	override bool handleActionStateRequest(const Action a) {
        switch (a.id) {
            case IDEActions.FileExit:
            case IDEActions.FileOpen:
            case IDEActions.WindowCloseAllDocuments:
            case IDEActions.FileOpenWorkspace:
                // disable when background operation in progress
                if (!_currentBackgroundOperation)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.HelpAbout:
            case StandardAction.OpenUrl:
                // always enabled
                a.state = ACTION_STATE_ENABLED;
                return true;
            case IDEActions.BuildProject:
            case IDEActions.BuildWorkspace:
            case IDEActions.RebuildProject:
            case IDEActions.RebuildWorkspace:
            case IDEActions.CleanProject:
            case IDEActions.CleanWorkspace:
            case IDEActions.DebugStart:
            case IDEActions.DebugStartNoDebug:
            case IDEActions.DebugContinue:
            case IDEActions.UpdateProjectDependencies:
            case IDEActions.RefreshProject:
			case IDEActions.SetStartupProject:
			case IDEActions.ProjectSettings:
                // enable when project exists
                if (currentWorkspace && currentWorkspace.startupProject && !_currentBackgroundOperation)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            default:
                return super.handleActionStateRequest(a);
        }
	}

    FileDialog createFileDialog(UIString caption) {
        FileDialog dlg = new FileDialog(caption, window, null);
        dlg.filetypeIcons[".d"] = "text-d";
        dlg.filetypeIcons["dub.json"] = "project-d";
        dlg.filetypeIcons["package.json"] = "project-d";
        dlg.filetypeIcons[".dlangidews"] = "project-development";
        return dlg;
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case IDEActions.FileExit:
                    if (onCanClose())
                        window.close();
                    return true;
                case IDEActions.HelpAbout:
                    Window wnd = Platform.instance.createWindow("About...", window, WindowFlag.Modal);
                    wnd.mainWidget = createAboutWidget();
                    wnd.show();
                    return true;
                case StandardAction.OpenUrl:
                    platform.openURL(a.stringParam);
                    return true;
                case IDEActions.FileOpen:
                    UIString caption;
                    caption = "Open Text File"d;
                    FileDialog dlg = createFileDialog(caption);
                    dlg.addFilter(FileFilterEntry(UIString("Source files"d), "*.d;*.dd;*.ddoc;*.dh;*.json;*.xml;*.ini"));
                    dlg.onDialogResult = delegate(Dialog dlg, const Action result) {
						if (result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                            if (isSupportedSourceTextFileFormat(filename)) {
                                openSourceFile(filename);
                            }
                        }
                    };
                    dlg.show();
                    return true;
                case IDEActions.BuildProject:
                case IDEActions.BuildWorkspace:
                    buildProject(BuildOperation.Build);
                    return true;
                case IDEActions.RebuildProject:
                case IDEActions.RebuildWorkspace:
                    buildProject(BuildOperation.Rebuild);
                    return true;
                case IDEActions.CleanProject:
                case IDEActions.CleanWorkspace:
                    buildProject(BuildOperation.Clean);
                    return true;
                case IDEActions.DebugStart:
                case IDEActions.DebugStartNoDebug:
                case IDEActions.DebugContinue:
                    buildProject(BuildOperation.Run);
                    return true;
                case IDEActions.UpdateProjectDependencies:
                    buildProject(BuildOperation.Upgrade);
                    return true;
                case IDEActions.RefreshProject:
                    refreshWorkspace();
                    return true;
                case IDEActions.WindowCloseAllDocuments:
                    askForUnsavedEdits(delegate() {
                        closeAllDocuments();
                    });
                    return true;
                case IDEActions.FileOpenWorkspace:
                    UIString caption;
                    caption = "Open Workspace or Project"d;
                    FileDialog dlg = createFileDialog(caption);
                    dlg.addFilter(FileFilterEntry(UIString("Workspace and project files"d), "*.dlangidews;dub.json;package.json"));
                    dlg.onDialogResult = delegate(Dialog dlg, const Action result) {
						if (result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                            if (filename.length)
                                openFileOrWorkspace(filename);
                        }
                    };
                    dlg.show();
                    return true;
                case IDEActions.GoToDefinition:
                    Log.d("Trying to go to definition.");
                    _editorTool.goToDefinition(currentEditor(), currentEditor.getCaretPosition());
                    return true;
                case IDEActions.GetCompletionSuggestions:
                    Log.d("Getting auto completion suggestions.");
                    auto results = _editorTool.getCompletions(currentEditor, currentEditor.getCaretPosition);
                    currentEditor.showCompletionPopup(results);
                    return true;
                default:
                    return super.handleAction(a);
            }
        }
		return false;
	}

    void openFileOrWorkspace(string filename) {
        if (filename.isWorkspaceFile) {
            Workspace ws = new Workspace();
            if (ws.load(filename)) {
                askForUnsavedEdits(delegate() {
                    setWorkspace(ws);
                });
            } else {
                window.showMessageBox(UIString("Cannot open workspace"d), UIString("Error occured while opening workspace"d));
                return;
            }
        } else if (filename.isProjectFile) {
            _logPanel.clear();
            _logPanel.logLine("Trying to open project from " ~ filename);
            Project project = new Project();
            if (!project.load(filename)) {
                _logPanel.logLine("Cannot read project file " ~ filename);
                window.showMessageBox(UIString("Cannot open project"d), UIString("Error occured while opening project"d));
                return;
            }
            _logPanel.logLine("Project file is opened ok");
            string defWsFile = project.defWorkspaceFile;
            if (currentWorkspace) {
                Project existing = currentWorkspace.findProject(project.filename);
                if (existing) {
                    _logPanel.logLine("This project already exists in current workspace");
                    window.showMessageBox(UIString("Open project"d), UIString("Project is already in workspace"d));
                    return;
                }
                window.showMessageBox(UIString("Open project"d), UIString("Do you want to create new workspace or use current one?"d),
                                      [ACTION_ADD_TO_CURRENT_WORKSPACE, ACTION_CREATE_NEW_WORKSPACE, ACTION_CANCEL], 0, delegate(const Action result) {
                                          if (result.id == IDEActions.CreateNewWorkspace) {
                                              // new ws
                                              createNewWorkspaceForExistingProject(project);
                                          } else if (result.id == IDEActions.AddToCurrentWorkspace) {
                                              // add to current
                                              currentWorkspace.addProject(project);
                                              currentWorkspace.save();
                                              refreshWorkspace();
                                          }
                                          return true;
                                      });
            } else {
                // new workspace file
                createNewWorkspaceForExistingProject(project);
            }
        } else {
            _logPanel.logLine("File is not recognized as DlangIDE project or workspace file");
            window.showMessageBox(UIString("Invalid workspace file"d), UIString("This file is not a valid workspace or project file"d));
        }
    }

    void refreshWorkspace() {
        _logPanel.logLine("Refreshing workspace");
        _wsPanel.reloadItems();
    }

    void createNewWorkspaceForExistingProject(Project project) {
        string defWsFile = project.defWorkspaceFile;
        _logPanel.logLine("Creating new workspace " ~ defWsFile);
        // new ws
        Workspace ws = new Workspace();
        ws.name = project.name;
        ws.description = project.description;
        ws.addProject(project);
        ws.save(defWsFile);
        setWorkspace(ws);
        _logPanel.logLine("Done");
    }

    //bool loadWorkspace(string path) {
    //    // testing workspace loader
    //    Workspace ws = new Workspace();
    //    ws.load(path);
    //    setWorkspace(ws);
    //    //ws.save(ws.filename ~ ".bak");
    //    return true;
    //}

    void setWorkspace(Workspace ws) {
        closeAllDocuments();
        currentWorkspace = ws;
        _wsPanel.workspace = ws;
        requestActionsUpdate();
        if (ws && ws.startupProject && ws.startupProject.mainSourceFile) {
            openSourceFile(ws.startupProject.mainSourceFile.filename);
            _tabs.setFocus();
        }
    }

    void buildProject(BuildOperation buildOp) {
        if (!currentWorkspace || !currentWorkspace.startupProject) {
            _logPanel.logLine("No project is opened");
            return;
        }
        Builder op = new Builder(this, currentWorkspace.startupProject, _logPanel, currentWorkspace.buildConfiguration, buildOp, false);
        setBackgroundOperation(op);
    }

    /// handle files dropped to application window
    void onFilesDropped(string[] filenames) {
        //Log.d("onFilesDropped(", filenames, ")");
        bool first = true;
        for (int i = 0; i < filenames.length; i++) {
            if (isSupportedSourceTextFileFormat(filenames[i])) {
                openSourceFile(filenames[i], null, first);
                first = false;
            }
        }
    }

    /// return false to prevent closing
    bool onCanClose() {
        askForUnsavedEdits(delegate() {
            window.close();
        });
        return false;
    }
    /// called when main window is closing
    void onWindowClose() {
        Log.i("onWindowClose()");
        if (_dcdServer) {
            if (_dcdServer.isRunning)
                _dcdServer.stop();
            destroy(_dcdServer);
            _dcdServer = null;
        }
    }
}

Widget createAboutWidget() 
{
	LinearLayout res = new VerticalLayout();
	res.padding(Rect(10,10,10,10));
	res.addChild(new TextWidget(null, "DLangIDE"d));
	res.addChild(new TextWidget(null, "(C) Vadim Lopatin, 2014"d));
	res.addChild(new TextWidget(null, "http://github.com/buggins/dlangide"d));
	res.addChild(new TextWidget(null, "IDE for D programming language written in D"d));
	res.addChild(new TextWidget(null, "Uses DlangUI library for GUI"d));
	Button closeButton = new Button("close", "Close"d);
	closeButton.onClickListener = delegate(Widget src) {
		Log.i("Closing window");
		res.window.close();
		return true;
	};
	res.addChild(closeButton);
	return res;
}
