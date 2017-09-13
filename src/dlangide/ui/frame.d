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
import dlangui.dialogs.settingsdialog;
import dlangui.core.stdaction;
import dlangui.core.files;

import dlangide.ui.commands;
import dlangide.ui.wspanel;
import dlangide.ui.outputpanel;
import dlangide.ui.newfile;
import dlangide.ui.newproject;
import dlangide.ui.dsourceedit;
import dlangide.ui.homescreen;
import dlangide.ui.settings;
import dlangide.ui.debuggerui;

import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.builders.builder;
import dlangide.tools.editorTool;

import ddebug.common.execution;
import ddebug.common.nodebug;
import ddebug.common.debugger;
import ddebug.gdb.gdbinterface;

import std.conv;
import std.utf;
import std.algorithm : equal, endsWith;
import std.array : empty;
import std.string : split;
import std.path;

// TODO: get version from GIT commit
//version is now stored in file views/VERSION
immutable dstring DLANGIDE_VERSION = toUTF32(import("VERSION"));

bool isSupportedSourceTextFileFormat(string filename) {
    return (filename.endsWith(".d") || filename.endsWith(".di") || filename.endsWith(".dt") || filename.endsWith(".txt") || filename.endsWith(".cpp") || filename.endsWith(".h") || filename.endsWith(".c")
        || filename.endsWith(".json") || filename.endsWith(".sdl") || filename.endsWith(".dd") || filename.endsWith(".ddoc") || filename.endsWith(".xml") || filename.endsWith(".html")
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
class IDEFrame : AppFrame, ProgramExecutionStatusListener, BreakpointListChangeListener, BookmarkListChangeListener {

    private ToolBarComboBox projectConfigurationCombo;
    
    MenuItem mainMenuItems;
    WorkspacePanel _wsPanel;
    OutputPanel _logPanel;
    DockHost _dockHost;
    TabWidget _tabs;
    // Is any workspace already opened?
    private auto openedWorkspace = false;

    ///Cache for parsed D files for autocomplete and symbol finding
    import dlangide.tools.d.dcdinterface;
    private DCDInterface _dcdInterface;
    @property DCDInterface dcdInterface() {
        if (!_dcdInterface)
            _dcdInterface = new DCDInterface();
        return _dcdInterface; 
    }

    IDESettings _settings;
    ProgramExecution _execution;

    dstring frameWindowCaptionSuffix = "DLangIDE"d;

    this(Window window) {
        super();
        window.mainWidget = this;
        window.onFilesDropped = &onFilesDropped;
        window.onCanClose = &onCanClose;
        window.onClose = &onWindowClose;
        applySettings(_settings);
    }

    ~this() {
        if (_dcdInterface) {
            destroy(_dcdInterface);
            _dcdInterface = null;
        }
    }

    @property DockHost dockHost() { return _dockHost; }
    @property OutputPanel logPanel() { return _logPanel; }

    /// stop current program execution
    void stopExecution() {
        if (_execution) {
            _logPanel.logLine("Stopping program execution");
            Log.d("Stopping execution");
            _execution.stop();
            //destroy(_execution);
            _execution = null;
        }
    }

    /// returns true if program execution or debugging is active
    @property bool isExecutionActive() {
        return _execution !is null;
    }
    
    /// Is any workspace already opened?
    @property bool isOpenedWorkspace() {
        return openedWorkspace;
    }
    
    /// Is any workspace already opened?
    @property void isOpenedWorkspace(bool opened) {
        openedWorkspace = opened;    
    }

    /// called when program execution is stopped
    protected void onProgramExecutionStatus(ProgramExecution process, ExecutionStatus status, int exitCode) {
        executeInUiThread(delegate() {
            Log.d("onProgramExecutionStatus process: ", process.executableFile, " status: ", status, " exitCode: ", exitCode);
            _execution = null;
            // TODO: update state
            switch(status) {
                case ExecutionStatus.Error:
                    _logPanel.logLine("Cannot run program " ~ process.executableFile);
                    break;
                case ExecutionStatus.Finished:
                    _logPanel.logLine("Program " ~ process.executableFile ~ " finished with exit code " ~ to!string(exitCode));
                    break;
                case ExecutionStatus.Killed:
                    _logPanel.logLine("Program " ~ process.executableFile ~ " is killed");
                    break;
                default:
                    _logPanel.logLine("Program " ~ process.executableFile ~ " is finished");
                    break;
            }
            _statusLine.setBackgroundOperationStatus(null, null);
        });
    }

    protected void handleBuildError(int result, Project project) {
        ErrorPosition err = _logPanel.firstError;
        if (err) {
            onCompilerLogIssueClick(err.filename, err.line, err.pos);
        }
    }

    protected void buildAndDebugProject(Project project) {
        if (!currentWorkspace)
            return;
        if (!project)
            project = currentWorkspace.startupProject;
        if (!project) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_DEBUG_PROJECT"c), UIString.fromId("ERROR_STARTUP_PROJECT_ABSENT"c));
            return;
        }
        buildProject(BuildOperation.Build, project, delegate(int result) {
            if (!result) {
                Log.i("Build completed successfully. Starting debug for project.");
                debugProject(project);
            } else {
                handleBuildError(result, project);
            }
        });
    }

    void debugFinished(ProgramExecution process, ExecutionStatus status, int exitCode) {
        _execution = null;
        _debugHandler = null;
        switch(status) {
            case ExecutionStatus.Error:
                _logPanel.logLine("Cannot run program " ~ process.executableFile);
                _logPanel.activateLogTab();
                break;
            case ExecutionStatus.Finished:
                _logPanel.logLine("Program " ~ process.executableFile ~ " finished with exit code " ~ to!string(exitCode));
                break;
            case ExecutionStatus.Killed:
                _logPanel.logLine("Program " ~ process.executableFile ~ " is killed");
                break;
            default:
                _logPanel.logLine("Program " ~ process.executableFile ~ " is finished");
                break;
        }
        _statusLine.setBackgroundOperationStatus(null, null);
    }

    DebuggerUIHandler _debugHandler;
    protected void debugProject(Project project) {
        import std.file;
        stopExecution();
        if (!project) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_DEBUG_PROJECT"c), UIString.fromId("ERROR_STARTUP_PROJECT_ABSENT"c));
            return;
        }
        string executableFileName = project.executableFileName;
        if (!executableFileName || !exists(executableFileName) || !isFile(executableFileName)) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_DEBUG_PROJECT"c), UIString.fromId("ERROR_CANNOT_FIND_EXEC"c));
            return;
        }
        string debuggerExecutable = _settings.debuggerExecutable;
        if (debuggerExecutable.empty) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_DEBUG_PROJECT"c), UIString.fromId("ERROR_NO_DEBUGGER"c));
            return;
        }

        GDBInterface program = new GDBInterface();
        DebuggerProxy debuggerProxy = new DebuggerProxy(program, &executeInUiThread);
        debuggerProxy.setDebuggerExecutable(debuggerExecutable);
        setExecutableParameters(debuggerProxy, project, executableFileName);
        _execution = debuggerProxy;
        _debugHandler = new DebuggerUIHandler(this, debuggerProxy);
        _debugHandler.onBreakpointListUpdated(currentWorkspace.getBreakpoints());
        _debugHandler.run();
    }

    protected void buildAndRunProject(Project project) {
        if (!currentWorkspace)
            return;
        if (!project)
            project = currentWorkspace.startupProject;
        if (!project) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_RUN_PROJECT"c), UIString.fromId("ERROR_CANNOT_RUN_PROJECT"c));
            return;
        }
        buildProject(BuildOperation.Build, project, delegate(int result) {
            if (!result) {
                Log.i("Build completed successfully. Running program...");
                runProject(project);
            } else {
                handleBuildError(result, project);
            }
        });
    }

    protected void runProject(Project project) {
        import std.file;
        stopExecution();
        if (!project) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_RUN_PROJECT"c), UIString.fromId("ERROR_STARTUP_PROJECT_ABSENT"c));
            return;
        }
        string executableFileName = project.executableFileName;
        if (!executableFileName || !exists(executableFileName) || !isFile(executableFileName)) {
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_RUN_PROJECT"c), UIString.fromId("ERROR_CANNOT_FIND_EXEC"c));
            return;
        }
        auto program = new ProgramExecutionNoDebug;
        setExecutableParameters(program, project, executableFileName);
        program.setProgramExecutionStatusListener(this);
        _execution = program;
        program.run();
    }

    bool setExecutableParameters(ProgramExecution program, Project project, string executableFileName) {
        string[] args;
        string externalConsoleExecutable = null;
        string workingDirectory = project.workingDirectory;
        string tty = _logPanel.terminalDeviceName;
        if (project.runInExternalConsole) {
            version(Windows) {
                if (program.isMagoDebugger)
                    tty = "external-console";
            } else {
                externalConsoleExecutable = _settings.terminalExecutable;
            }
        }
        if (!program.isDebugger)
            _logPanel.logLine("MSG_STARTING"c ~ " " ~ executableFileName);
        else
            _logPanel.logLine("MSG_STARTING_DEBUGGER"c ~ " " ~ executableFileName);
        const auto status =  program.isDebugger ?  UIString.fromId("DEBUGGING"c).value : UIString.fromId("RUNNING"c).value;
        _statusLine.setBackgroundOperationStatus("debug-run", status);
        string[string] env;
        program.setExecutableParams(executableFileName, args, workingDirectory, env);
        if (!tty.empty) {
            Log.d("Terminal window device name: ", tty);
            program.setTerminalTty(tty);
            if (tty != "external-console")
                _logPanel.activateTerminalTab(true);
        } else
            program.setTerminalExecutable(externalConsoleExecutable);
        return true;
    }

    void runWithRdmd(string filename) {
        stopExecution();

        string rdmdExecutable = _settings.rdmdExecutable;

        auto program = new ProgramExecutionNoDebug;
        string sourceFileName = baseName(filename);
        string workingDirectory = dirName(filename);
        string[] args;
        {
            string rdmdAdditionalParams = _settings.rdmdAdditionalParams;
            if (!rdmdAdditionalParams.empty)
                args ~= rdmdAdditionalParams.split();

            auto buildConfig = currentWorkspace ? currentWorkspace.buildConfiguration : BuildConfiguration.Debug;
            switch (buildConfig) {
                default:
                case BuildConfiguration.Debug:
                    args ~= "-debug";
                    break;
                case BuildConfiguration.Release:
                    args ~= "-release";
                    break;
                case BuildConfiguration.Unittest:
                    args ~= "-unittest";
                    break;
            }
            args ~= sourceFileName;
        }
        string externalConsoleExecutable = null;
        version(Windows) {
        } else {
            externalConsoleExecutable = _settings.terminalExecutable;
        }
        _logPanel.logLine("Starting " ~ sourceFileName ~ " with rdmd");
        _statusLine.setBackgroundOperationStatus("run-rdmd", "running..."d);
        program.setExecutableParams(rdmdExecutable, args, workingDirectory, null);
        program.setTerminalExecutable(externalConsoleExecutable);
        program.setProgramExecutionStatusListener(this);
        _execution = program;
        program.run();
    }

    override protected void initialize() {
        _appName = "dlangide";
        //_editorTool = new DEditorTool(this);
        _settings = new IDESettings(buildNormalizedPath(settingsDir, "settings.json"));
        _settings.load();
        _settings.updateDefaults();
        _settings.save();
        super.initialize();
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
        Log.d("onSourceFileSelected ", file.filename, " activate=", activate);
        if (activate)
            return openSourceFile(file.filename, file, activate);
        return false;
    }

    /// returns global IDE settings
    @property IDESettings settings() { return _settings; }

    ///
    bool onCompilerLogIssueClick(dstring filename, int line, int column)
    {
        Log.d("onCompilerLogIssueClick ", filename);

        import std.conv:to;
        openSourceFile(to!string(filename));

        currentEditor().setCaretPos(line, 0);
        currentEditor().setCaretPos(line, column);

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
        //    return false;

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
                editor.modifiedStateChange = &onModifiedStateChange;
                if (file) {
                    editor.breakpointListChanged = this; //onBreakpointListChanged
                    editor.bookmarkListChanged = this; //onBreakpointListChanged
                    editor.setBreakpointList(currentWorkspace.getSourceFileBreakpoints(file));
                    editor.setBookmarkList(currentWorkspace.getSourceFileBookmarks(file));
                }
                applySettings(editor, settings);
                _tabs.selectTab(index, true);
                if( filename.endsWith(".d") || filename.endsWith(".di") )
                    editor.editorTool = new DEditorTool(this);
                else
                    editor.editorTool = new DefaultEditorTool(this);
                _tabs.layout(_tabs.pos);
            } else {
                destroy(editor);
                if (window)
                    window.showMessageBox(UIString.fromId("ERROR_OPEN_FILE"c), UIString.fromId("ERROR_OPENING_FILE"c) ~ " " ~ toUTF32(file.filename));
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
            _tabs.addTab(home, UIString.fromId("HOME"c), null, true);
            _tabs.selectTab(HOME_SCREEN_ID, true);
             auto _settings = new IDESettings(buildNormalizedPath(settingsDir, "settings.json"));
            // Auto open last workspace, if no workspace specified in command line and autoOpen flag set to true
            const auto recentWorkspaces = settings.recentWorkspaces;
            if (!openedWorkspace && recentWorkspaces.length > 0 && _settings.autoOpenLastProject())
            {
                Action a = ACTION_FILE_OPEN_WORKSPACE.clone();
                a.stringParam = recentWorkspaces[0];
                handleAction(a);
            }
        }
    }

    void hideHomeScreen() {
        _tabs.removeTab(HOME_SCREEN_ID);
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
        requestActionsUpdate();
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

    void renameTab(string oldfilename, string newfilename) {
        int index = _tabs.tabIndex(newfilename);
        if (index >= 0) {
            // file is already opened in tab - close it
            _tabs.removeTab(newfilename);
        }
        int oldindex = _tabs.tabIndex(oldfilename);
        if (oldindex >= 0) {
            _tabs.renameTab(oldindex, newfilename, UIString.fromRaw(newfilename.baseName));
        }
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

    /// returns array of all opened source editors
    DSourceEdit[] allOpenedEditors() {
        DSourceEdit[] res;
        for (int i = _tabs.tabCount - 1; i >= 0; i--) {
            DSourceEdit ed = cast(DSourceEdit)_tabs.tabBody(i);
            if (ed) {
                res ~= ed;
            }
        }
        return res;
    }

    /// close editor tabs for which files are removed from filesystem
    void closeRemovedDocuments() {
        import std.file;
        for (int i = _tabs.tabCount - 1; i >= 0; i--) {
            DSourceEdit ed = cast(DSourceEdit)_tabs.tabBody(i);
            if (ed) {
                if (!exists(ed.id) || !isFile(ed.id)) {
                    closeTab(ed.id);
                }
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
        auto header = UIString.fromId("HEADER_CLOSE_FILE"c);
        window.showMessageBox(header ~ " " ~ toUTF32(baseName(tabId)), UIString.fromId("MSG_FILE_CONTENT_CHANGED"c), 
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
                window.showMessageBox(UIString.fromId("HEADER_CLOSE_TAB"c), UIString.fromId("MSG_TAB_CONTENT_CHANGED"c) ~ ": " ~ toUTF32(baseName(tabId)), 
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
        requestActionsUpdate();
    }

    /// create app body widget
    override protected Widget createBody() {
        _dockHost = new DockHost();

        //=============================================================
        // Create body - Tabs

        // editor tabs
        _tabs = new TabWidget("TABS");
        _tabs.hiddenTabsVisibility = Visibility.Gone;
        //_tabs.setStyles(STYLE_DOCK_HOST_BODY, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT);
        _tabs.setStyles(STYLE_DOCK_WINDOW, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT, STYLE_DOCK_HOST_BODY);
        _tabs.tabChanged = &onTabChanged;
        _tabs.tabClose = &onTabClose;

        _dockHost.bodyWidget = _tabs;

        //=============================================================
        // Create workspace docked panel
        _wsPanel = new WorkspacePanel("workspace");
        _wsPanel.sourceFileSelectionListener = &onSourceFileSelected;
        _wsPanel.workspaceActionListener = &handleAction;
        _wsPanel.dockAlignment = DockAlignment.Left;
        _dockHost.addDockedWindow(_wsPanel);
        _wsPanel.visibility = Visibility.Gone;

        _logPanel = new OutputPanel("output");
        _logPanel.compilerLogIssueClickHandler = &onCompilerLogIssueClick;
        _logPanel.appendText(null, "DlangIDE is started\nHINT: Try to open some DUB project\n"d);
        string dubPath = findExecutablePath("dub");
        string rdmdPath = findExecutablePath("rdmd");
        string dmdPath = findExecutablePath("dmd");
        string ldcPath = findExecutablePath("ldc2");
        string gdcPath = findExecutablePath("gdc");
        _logPanel.appendText(null, dubPath ? ("dub path: "d ~ toUTF32(dubPath) ~ "\n"d) : ("dub is not found! cannot build projects without DUB\n"d));
        _logPanel.appendText(null, rdmdPath ? ("rdmd path: "d ~ toUTF32(rdmdPath) ~ "\n"d) : ("rdmd is not found!\n"d));
        _logPanel.appendText(null, dmdPath ? ("dmd path: "d ~ toUTF32(dmdPath) ~ "\n"d) : ("dmd compiler is not found!\n"d));
        _logPanel.appendText(null, ldcPath ? ("ldc path: "d ~ toUTF32(ldcPath) ~ "\n"d) : ("ldc compiler is not found!\n"d));
        _logPanel.appendText(null, gdcPath ? ("gdc path: "d ~ toUTF32(gdcPath) ~ "\n"d) : ("gdc compiler is not found!\n"d));

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
                     ACTION_FILE_SAVE, ACTION_FILE_SAVE_AS, ACTION_FILE_SAVE_ALL, ACTION_FILE_WORKSPACE_CLOSE, ACTION_FILE_EXIT);

        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));
        editItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, 
                     ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_FIND_TEXT, ACTION_EDITOR_TOGGLE_BOOKMARK);
        MenuItem editItemAdvanced = new MenuItem(new Action(221, "MENU_EDIT_ADVANCED"));
        editItemAdvanced.add(ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT, ACTION_EDIT_TOGGLE_BLOCK_COMMENT, ACTION_GO_TO_DEFINITION, ACTION_GET_COMPLETIONS);
        editItem.add(editItemAdvanced);

        editItem.add(ACTION_EDIT_PREFERENCES);

        MenuItem navItem = new MenuItem(new Action(21, "MENU_NAVIGATE"));
        navItem.add(ACTION_GO_TO_DEFINITION, ACTION_GET_COMPLETIONS, ACTION_GET_DOC_COMMENTS, ACTION_GET_PAREN_COMPLETION, ACTION_EDITOR_GOTO_PREVIOUS_BOOKMARK, ACTION_EDITOR_GOTO_NEXT_BOOKMARK);

        MenuItem projectItem = new MenuItem(new Action(21, "MENU_PROJECT"));
        projectItem.add(ACTION_PROJECT_SET_STARTUP, ACTION_PROJECT_REFRESH, ACTION_PROJECT_UPDATE_DEPENDENCIES, ACTION_PROJECT_SETTINGS);

        MenuItem buildItem = new MenuItem(new Action(22, "MENU_BUILD"));
        buildItem.add(ACTION_WORKSPACE_BUILD, ACTION_WORKSPACE_REBUILD, ACTION_WORKSPACE_CLEAN,
                     ACTION_PROJECT_BUILD, ACTION_PROJECT_REBUILD, ACTION_PROJECT_CLEAN,
                     ACTION_RUN_WITH_RDMD);

        MenuItem debugItem = new MenuItem(new Action(23, "MENU_DEBUG"));
        debugItem.add(ACTION_DEBUG_START, ACTION_DEBUG_START_NO_DEBUG, 
                      ACTION_DEBUG_CONTINUE, ACTION_DEBUG_STOP, ACTION_DEBUG_PAUSE,
                      ACTION_DEBUG_RESTART,
                      ACTION_DEBUG_STEP_INTO,
                      ACTION_DEBUG_STEP_OVER,
                      ACTION_DEBUG_STEP_OUT,
                      ACTION_DEBUG_TOGGLE_BREAKPOINT, ACTION_DEBUG_ENABLE_BREAKPOINT, ACTION_DEBUG_DISABLE_BREAKPOINT
                      );


        MenuItem windowItem = new MenuItem(new Action(3, "MENU_WINDOW"c));
        //windowItem.add(new Action(30, "MENU_WINDOW_PREFERENCES"));
        windowItem.add(ACTION_WINDOW_CLOSE_DOCUMENT, ACTION_WINDOW_CLOSE_ALL_DOCUMENTS, ACTION_WINDOW_SHOW_HOME_SCREEN);
        MenuItem helpItem = new MenuItem(new Action(4, "MENU_HELP"c));
        helpItem.add(ACTION_HELP_VIEW_HELP, ACTION_HELP_ABOUT, ACTION_HELP_DONATE);
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
        //mainMenu.backgroundColor = 0xd6dbe9;
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
                ACTION_PROJECT_BUILD, ACTION_PROJECT_REBUILD, ACTION_PROJECT_CLEAN, ACTION_RUN_WITH_RDMD,
                ACTION_DEBUG_START, ACTION_DEBUG_START_NO_DEBUG, ACTION_DEBUG_CONTINUE, ACTION_DEBUG_STOP, ACTION_DEBUG_PAUSE,
                ACTION_DEBUG_RESTART,
                ACTION_DEBUG_STEP_INTO,
                ACTION_DEBUG_STEP_OVER,
                ACTION_DEBUG_STEP_OUT,
                ACTION_WINDOW_CLOSE_DOCUMENT, ACTION_WINDOW_CLOSE_ALL_DOCUMENTS, ACTION_HELP_ABOUT];
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
        
        projectConfigurationCombo = new ToolBarComboBox("projectConfig", [ProjectConfiguration.DEFAULT_NAME.to!dstring]);//Updateable
        projectConfigurationCombo.itemClick = delegate(Widget source, int index) {
            if (currentWorkspace) {
                currentWorkspace.setStartupProjectConfiguration(projectConfigurationCombo.selectedItem.to!string); 
            }
            return true;
        };
        projectConfigurationCombo.action = ACTION_PROJECT_CONFIGURATIONS;
        tb.addControl(projectConfigurationCombo);
        
        ToolBarComboBox cbBuildConfiguration = new ToolBarComboBox("buildConfig", ["Debug"d, "Release"d, "Unittest"d]);
        cbBuildConfiguration.itemClick = delegate(Widget source, int index) {
            if (currentWorkspace && index < 3) {
                currentWorkspace.buildConfiguration = [BuildConfiguration.Debug, BuildConfiguration.Release, BuildConfiguration.Unittest][index];
            }
            return true;
        };
        cbBuildConfiguration.action = ACTION_BUILD_CONFIGURATIONS;
        tb.addControl(cbBuildConfiguration);
        tb.addButtons(ACTION_PROJECT_BUILD, ACTION_SEPARATOR, ACTION_RUN_WITH_RDMD);

        tb = res.getOrAddToolbar("Edit");
        tb.addButtons(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_SEPARATOR,
                      ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT);
        tb = res.getOrAddToolbar("Debug");
        tb.addButtons(ACTION_DEBUG_STOP, ACTION_DEBUG_CONTINUE, ACTION_DEBUG_PAUSE,
                      ACTION_DEBUG_RESTART,
                      ACTION_DEBUG_STEP_INTO,
                      ACTION_DEBUG_STEP_OVER,
                      ACTION_DEBUG_STEP_OUT,
                      );
        return res;
    }

    /// override to handle specific actions state (e.g. change enabled state for supported actions)
    override bool handleActionStateRequest(const Action a) {
        switch (a.id) {
            case IDEActions.EditPreferences:
                return true;
            case IDEActions.FileExit:
            case IDEActions.FileOpen:
            case IDEActions.WindowShowHomeScreen:
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
            case IDEActions.UpdateProjectDependencies:
            case IDEActions.RefreshProject:
            case IDEActions.SetStartupProject:
            case IDEActions.ProjectSettings:
            case IDEActions.RevealProjectInExplorer:
                // enable when project exists
                if (currentWorkspace && currentWorkspace.startupProject && !_currentBackgroundOperation)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.RunWithRdmd:
                // enable when D source file is in current tab
                if (currentEditor && !_currentBackgroundOperation && currentEditor.id.endsWith(".d"))
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.DebugStop:
                a.state = isExecutionActive ? ACTION_STATE_ENABLED : ACTION_STATE_DISABLE;
                return true;
            case IDEActions.DebugStart:
            case IDEActions.DebugStartNoDebug:
                if (!isExecutionActive && currentWorkspace && currentWorkspace.startupProject && !_currentBackgroundOperation)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.DebugContinue:
            case IDEActions.DebugPause:
            case IDEActions.DebugStepInto:
            case IDEActions.DebugStepOver:
            case IDEActions.DebugStepOut:
            case IDEActions.DebugRestart:
                if (_debugHandler)
                    return _debugHandler.handleActionStateRequest(a);
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.FindInFiles:
                a.state = currentWorkspace !is null ? ACTION_STATE_ENABLED : ACTION_STATE_DISABLE;
                return true;
            case IDEActions.CloseWorkspace:
                a.state = (currentWorkspace !is null && !_currentBackgroundOperation) ? ACTION_STATE_ENABLED : ACTION_STATE_DISABLE;
                return true;
            case IDEActions.WindowCloseDocument:
            case IDEActions.WindowCloseAllDocuments:
            case IDEActions.FileSaveAll:
            case IDEActions.FileSaveAs:
                a.state = (currentEditor !is null && !_currentBackgroundOperation) ? ACTION_STATE_ENABLED : ACTION_STATE_DISABLE;
                return true;
            default:
                return super.handleActionStateRequest(a);
        }
    }

    FileDialog createFileDialog(UIString caption, int fileDialogFlags = DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.FileMustExist) {
        FileDialog dlg = new FileDialog(caption, window, null, fileDialogFlags);
        dlg.filetypeIcons[".d"] = "text-d";
        dlg.filetypeIcons["dub.json"] = "project-d";
        dlg.filetypeIcons["dub.sdl"] = "project-d";
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
                case IDEActions.HelpViewHelp:
                    Platform.instance.openURL(HELP_PAGE_URL);
                    return true;
                case IDEActions.HelpDonate:
                    Platform.instance.openURL(HELP_DONATION_URL);
                    return true;
                case IDEActions.HelpAbout:
                    //debug {
                    //    testDCDFailAfterThreadCreation();
                    //}
                    dstring msg = "DLangIDE\n(C) Vadim Lopatin, 2014-2017\nhttp://github.com/buggins/dlangide\n" 
                        ~ "IDE for D programming language written in D\nUses DlangUI library " 
                        ~ DLANGUI_VERSION ~ " for GUI"d;
                    window.showMessageBox(UIString.fromId("ABOUT"c) ~ " " ~ DLANGIDE_VERSION,
                                          UIString.fromRaw(msg));
                    return true;
                case StandardAction.OpenUrl:
                    platform.openURL(a.stringParam);
                    return true;
                case IDEActions.FileSaveAs:
                    DSourceEdit ed = currentEditor;
                    UIString caption;
                    caption = UIString.fromId("HEADER_SAVE_FILE_AS"c);
                    FileDialog dlg = createFileDialog(caption, DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.Save);
                    dlg.addFilter(FileFilterEntry(UIString.fromId("SOURCE_FILES"c), "*.d;*.dd;*.ddoc;*.di;*.dt;*.dh;*.json;*.sdl;*.xml;*.ini"));
                    dlg.addFilter(FileFilterEntry(UIString.fromId("ALL_FILES"c), "*.*"));
                    dlg.path = ed.filename.dirName;
                    dlg.filename = ed.filename;
                    dlg.dialogResult = delegate(Dialog d, const Action result) {
                        if (result.id == ACTION_SAVE.id) {
                            string oldfilename = ed.filename;
                            string filename = result.stringParam;
                            ed.save(filename);
                            if (oldfilename == filename)
                                return;
                            renameTab(oldfilename, filename);
                            ed.id = filename;
                            ed.setSyntaxSupport();
                            if( filename.endsWith(".d") || filename.endsWith(".di") )
                                ed.editorTool = new DEditorTool(this);
                            else
                                ed.editorTool = new DefaultEditorTool(this);
                            //openSourceFile(filename);
                            refreshWorkspace();
                            ProjectSourceFile file = _wsPanel.findSourceFileItem(filename, false);
                            if (file) {
                                ed.projectSourceFile = file;
                            } else
                                ed.projectSourceFile = null;
                            _settings.setRecentPath(dlg.path, "FILE_OPEN_PATH");
                        }
                    };
                    dlg.show();
                    return true;
                case IDEActions.FileOpen:
                    UIString caption;
                    caption = UIString.fromId("HEADER_OPEN_TEXT_FILE"c);
                    FileDialog dlg = createFileDialog(caption);
                    dlg.addFilter(FileFilterEntry(UIString.fromId("SOURCE_FILES"c), "*.d;*.dd;*.ddoc;*.di;*.dt;*.dh;*.json;*.sdl;*.xml;*.ini"));
                    dlg.addFilter(FileFilterEntry(UIString.fromId("ALL_FILES"c), "*.*"));
                    dlg.path = _settings.getRecentPath("FILE_OPEN_PATH");
                    dlg.dialogResult = delegate(Dialog d, const Action result) {
                        if (result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                            openSourceFile(filename);
                            _settings.setRecentPath(dlg.path, "FILE_OPEN_PATH");
                        }
                    };
                    dlg.show();
                    return true;
                case IDEActions.BuildProject:
                case IDEActions.BuildWorkspace:
                    buildProject(BuildOperation.Build, cast(Project)a.objectParam);
                    return true;
                case IDEActions.RebuildProject:
                case IDEActions.RebuildWorkspace:
                    buildProject(BuildOperation.Rebuild, cast(Project)a.objectParam);
                    return true;
                case IDEActions.CleanProject:
                case IDEActions.CleanWorkspace:
                    buildProject(BuildOperation.Clean, cast(Project)a.objectParam);
                    return true;
                case IDEActions.RunWithRdmd:
                    runWithRdmd(currentEditor.id);
                    return true;
                case IDEActions.DebugStartNoDebug:
                    buildAndRunProject(cast(Project)a.objectParam);
                    return true;
                case IDEActions.DebugStart:
                    buildAndDebugProject(cast(Project)a.objectParam);
                    return true;
                case IDEActions.DebugPause:
                case IDEActions.DebugStepInto:
                case IDEActions.DebugStepOver:
                case IDEActions.DebugStepOut:
                case IDEActions.DebugRestart:
                    if (_debugHandler)
                        return _debugHandler.handleAction(a);
                    return true;
                case IDEActions.DebugContinue:
                    if (_debugHandler)
                        return _debugHandler.handleAction(a);
                    else
                        buildAndRunProject(cast(Project)a.objectParam);
                    return true;
                case IDEActions.DebugStop:
                    if (_debugHandler)
                        return _debugHandler.handleAction(a);
                    else
                        stopExecution();
                    return true;
                case IDEActions.UpdateProjectDependencies:
                    buildProject(BuildOperation.Upgrade, cast(Project)a.objectParam);
                    return true;
                case IDEActions.RefreshProject:
                    refreshWorkspace();
                    return true;
                case IDEActions.RevealProjectInExplorer:
                    revealProjectInExplorer(cast(Project)a.objectParam);
                    return true;
                case IDEActions.WindowCloseDocument:
                    onTabClose(_tabs.selectedTabId);
                    return true;
                case IDEActions.WindowCloseAllDocuments:
                    askForUnsavedEdits(delegate() {
                        closeAllDocuments();
                    });
                    return true;
                case IDEActions.WindowShowHomeScreen:
                    showHomeScreen();
                    return true;
                case IDEActions.FileOpenWorkspace:
                    // Already specified workspace
                    if (!a.stringParam.empty) {
                        openFileOrWorkspace(a.stringParam);
                        return true;
                    }
                    // Ask user for workspace to open
                    UIString caption = UIString.fromId("HEADER_OPEN_WORKSPACE_OR_PROJECT"c);
                    FileDialog dlg = createFileDialog(caption);
                    dlg.addFilter(FileFilterEntry(UIString.fromId("WORKSPACE_AND_PROJECT_FILES"c), "*.dlangidews;dub.json;dub.sdl;package.json"));
                    dlg.path = _settings.getRecentPath("FILE_OPEN_WORKSPACE_PATH");
                    dlg.dialogResult = delegate(Dialog d, const Action result) {
                        if (result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                            if (filename.length) {
                                openFileOrWorkspace(filename);
                                _settings.setRecentPath(dlg.path, "FILE_OPEN_WORKSPACE_PATH");
                            }
                        }
                    };
                    dlg.show();
                    return true;
                case IDEActions.GoToDefinition:
                    if (currentEditor) {
                        Log.d("Trying to go to definition.");
                        currentEditor.editorTool.goToDefinition(currentEditor(), currentEditor.caretPos);
                    }
                    return true;
                case IDEActions.GetDocComments:
                    Log.d("Trying to get doc comments.");
                    currentEditor.editorTool.getDocComments(currentEditor, currentEditor.caretPos, delegate(string[] results) {
                        if (results.length)
                            currentEditor.showDocCommentsPopup(results);
                    });
                    return true;
                case IDEActions.GetParenCompletion:
                    Log.d("Trying to get paren completion.");
                    //auto results = currentEditor.editorTool.getParenCompletion(currentEditor, currentEditor.caretPos);
                    return true;
                case IDEActions.GetCompletionSuggestions:
                    Log.d("Getting auto completion suggestions.");
                    currentEditor.editorTool.getCompletions(currentEditor, currentEditor.caretPos, delegate(dstring[] results, string[] icons) {
                        if (currentEditor)
                            currentEditor.showCompletionPopup(results, icons);
                    });
                    return true;
                case IDEActions.EditPreferences:
                    showPreferences();
                    return true;
                case IDEActions.ProjectSettings:
                    showProjectSettings(cast(Project)a.objectParam);
                    return true;
                case IDEActions.SetStartupProject:
                    setStartupProject(cast(Project)a.objectParam);
                    return true;
                case IDEActions.FindInFiles:
                    Log.d("Opening Search In Files panel");
                    if (!currentWorkspace) {
                        Log.d("No workspace is opened");
                        return true;
                    }
                    import dlangide.ui.searchPanel;
                    int searchPanelIndex = _logPanel.getTabs.tabIndex("search");
                    SearchWidget searchPanel = null;
                    if(searchPanelIndex == -1) {
                        searchPanel = new SearchWidget("search", this);
                        _logPanel.getTabs.addTab( searchPanel, "Search"d, null, true);
                    }
                    else {
                        searchPanel = cast(SearchWidget) _logPanel.getTabs.tabBody(searchPanelIndex);
                    }
                    _logPanel.getTabs.selectTab("search");
                    if(searchPanel !is null) { 
                        searchPanel.focus();
                        dstring selectedText;
                        if (currentEditor)
                            selectedText = currentEditor.getSelectedText();
                        searchPanel.setSearchText(selectedText);
                        searchPanel.checkSearchMode();
                    }
                    return true;
                case IDEActions.FileNewWorkspace:
                    createNewProject(true);
                    return true;
                case IDEActions.FileNewProject:
                    createNewProject(false);
                    return true;
                case IDEActions.FileNew:
                    addProjectItem(cast(Object)a.objectParam);
                    return true;
                case IDEActions.ProjectFolderRemoveItem:
                    removeProjectItem(a.objectParam);
                    return true;
                case IDEActions.ProjectFolderRefresh:
                    refreshProjectItem(a.objectParam);
                    return true;
                case IDEActions.CloseWorkspace:
                    closeWorkspace();
                    return true;
                default:
                    return super.handleAction(a);
            }
        }
        return false;
    }

    @property ProjectSourceFile currentEditorSourceFile() {
        TabItem tab = _tabs.selectedTab;
        if (tab) {
            return cast(ProjectSourceFile)tab.objectParam;
        }
        return null;
    }

    void closeWorkspace() {
        if (currentWorkspace) {
            saveListOfOpenedFiles();
            currentWorkspace.save();
        }
        askForUnsavedEdits(delegate() {
            setWorkspace(null);
            showHomeScreen();
        });
    }

    void onBreakpointListChanged(ProjectSourceFile sourcefile, Breakpoint[] breakpoints) {
        if (!currentWorkspace)
            return;
        if (sourcefile) {
            currentWorkspace.setSourceFileBreakpoints(sourcefile, breakpoints);
        }
        if (_debugHandler)
            _debugHandler.onBreakpointListUpdated(currentWorkspace.getBreakpoints());
    }

    void onBookmarkListChanged(ProjectSourceFile sourcefile, EditorBookmark[] bookmarks) {
        if (!currentWorkspace)
            return;
        if (sourcefile)
            currentWorkspace.setSourceFileBookmarks(sourcefile, bookmarks);
    }

    void refreshProjectItem(const Object obj) {
        if (currentWorkspace is null)
            return;
        Project project;
        ProjectFolder folder;
        if (cast(Workspace)obj) {
            Workspace ws = cast(Workspace)obj;
            ws.refresh();
            refreshWorkspace();
        } else if (cast(Project)obj) {
            project = cast(Project)obj;
        } else if (cast(ProjectFolder)obj) {
            folder = cast(ProjectFolder)obj;
            project = folder.project;
        } else if (cast(ProjectSourceFile)obj) {
            ProjectSourceFile srcfile = cast(ProjectSourceFile)obj;
            folder = cast(ProjectFolder)srcfile.parent;
            project = srcfile.project;
        } else {
            ProjectSourceFile srcfile = currentEditorSourceFile;
            if (srcfile) {
                folder = cast(ProjectFolder)srcfile.parent;
                project = srcfile.project;
            }
        }
        if (project) {
            project.refresh();
            refreshWorkspace();
        }
    }

    void removeProjectItem(const Object obj) {
        if (currentWorkspace is null)
            return;
        ProjectSourceFile srcfile = cast(ProjectSourceFile)obj;
        if (!srcfile)
            return;
        Project project = srcfile.project;
        if (!project)
            return;
        window.showMessageBox(UIString.fromId("HEADER_REMOVE_FILE"c), 
                UIString.fromId("QUESTION_REMOVE_FILE"c) ~ " " ~ srcfile.name ~ "?", 
                [ACTION_YES, ACTION_NO], 
                1, delegate(const Action result) {
                    if (result == StandardAction.Yes) {
                        // save and close
                        try {
                            import std.file : remove;
                            closeTab(srcfile.filename);
                            remove(srcfile.filename);
                            project.refresh();
                            refreshWorkspace();
                        } catch (Exception e) {
                            Log.e("Error while removing file");
                        }
                    }
                    // else ignore
                    return true;
                });

    }

    /// add new file to project
    void addProjectItem(Object obj) {
        if (currentWorkspace is null)
            return;
        if (obj is null && _wsPanel !is null && !currentEditorSourceFile) {
            obj = _wsPanel.selectedProjectItem;
            if (!obj)
                obj = currentWorkspace.startupProject;
        }
        Project project;
        ProjectFolder folder;
        if (cast(Project)obj) {
            project = cast(Project)obj;
            folder = project.firstSourceFolder;
        } else if (cast(ProjectFolder)obj) {
            folder = cast(ProjectFolder)obj;
            project = folder.project;
        } else if (cast(ProjectSourceFile)obj) {
            ProjectSourceFile srcfile = cast(ProjectSourceFile)obj;
            folder = cast(ProjectFolder)srcfile.parent;
            project = srcfile.project;
        } else {
            ProjectSourceFile srcfile = currentEditorSourceFile;
            if (srcfile) {
                folder = cast(ProjectFolder)srcfile.parent;
                project = srcfile.project;
            }
        }
        if (project && folder && project.workspace is currentWorkspace) {
            NewFileDlg dlg = new NewFileDlg(this, project, folder);
            dlg.dialogResult = delegate(Dialog dlg, const Action result) {
                if (result.id == ACTION_FILE_NEW_SOURCE_FILE.id) {
                    FileCreationResult res = cast(FileCreationResult)result.objectParam;
                    if (res) {
                        //res.project.reload();
                        res.project.refresh();
                        refreshWorkspace();
                        if (isSupportedSourceTextFileFormat(res.filename)) {
                            openSourceFile(res.filename, null, true);
                        }
                    }
                }
            };
            dlg.show();
        }
    }

    void createNewProject(bool newWorkspace) {
        if (currentWorkspace is null)
            newWorkspace = true;
        string location = _settings.getRecentPath("FILE_OPEN_WORKSPACE_PATH");
        if (newWorkspace && location)
            location = location.dirName;
        NewProjectDlg dlg = new NewProjectDlg(this, newWorkspace, currentWorkspace, location);
        dlg.dialogResult = delegate(Dialog dlg, const Action result) {
            if (result.id == ACTION_FILE_NEW_PROJECT.id || result.id == ACTION_FILE_NEW_WORKSPACE.id) {
                //Log.d("settings after edit:\n", s.toJSON(true));
                ProjectCreationResult res = cast(ProjectCreationResult)result.objectParam;
                if (res) {
                    // open workspace/project
                    if (currentWorkspace is null || res.workspace !is currentWorkspace) {
                        // open new workspace
                        setWorkspace(res.workspace);
                        refreshWorkspace();
                        hideHomeScreen();
                    } else {
                        // project added to current workspace
                        loadProject(res.project);
                        refreshWorkspace();
                        hideHomeScreen();
                    }
                }
            }
        };
        dlg.show();
    }

    void showPreferences() {
        //Log.d("settings before copy:\n", _settings.setting.toJSON(true));
        Setting s = _settings.copySettings();
        //Log.d("settings after copy:\n", s.toJSON(true));
        SettingsDialog dlg = new SettingsDialog(UIString.fromId("HEADER_SETTINGS"c), window, s, createSettingsPages());
        dlg.dialogResult = delegate(Dialog dlg, const Action result) {
            if (result.id == ACTION_APPLY.id) {
                //Log.d("settings after edit:\n", s.toJSON(true));
                _settings.applySettings(s);
                applySettings(_settings);
                _settings.save();
            }
        };
        dlg.show();
    }

    void setStartupProject(Project project) {
        if (!currentWorkspace)
            return;
        if (!project)
            return;
        currentWorkspace.startupProject = project;
        warmUpImportPaths(project);
        if (_wsPanel)
            _wsPanel.updateDefault();
    }

    void showProjectSettings(Project project) {
        if (!currentWorkspace)
            return;
        if (!project)
            project = currentWorkspace.startupProject;
        if (!project)
            return;
        Setting s = project.settings.copySettings();
        SettingsDialog dlg = new SettingsDialog(UIString.fromRaw(project.name ~ " - "d ~ UIString.fromId("HEADER_PROJECT_SETTINGS"c)), window, s, createProjectSettingsPages());
        dlg.dialogResult = delegate(Dialog dlg, const Action result) {
            if (result.id == ACTION_APPLY.id) {
                //Log.d("settings after edit:\n", s.toJSON(true));
                project.settings.applySettings(s);
                project.settings.save();
            }
        };
        dlg.show();
    }

    // Applying settings to tabs/sources and it's opening
    void applySettings(IDESettings settings) {
        for (int i = _tabs.tabCount - 1; i >= 0; i--) {
            DSourceEdit ed = cast(DSourceEdit)_tabs.tabBody(i);
            if (ed) {
                applySettings(ed, settings);
            }
        }
        FontManager.fontGamma = settings.fontGamma;
        FontManager.hintingMode = settings.hintingMode;
        FontManager.minAnitialiasedFontSize = settings.minAntialiasedFontSize;
        Platform.instance.uiLanguage = settings.uiLanguage;
        Platform.instance.uiTheme = settings.uiTheme;
        bool needUpdateTheme = false;
        string oldFontFace = currentTheme.fontFace;
        string newFontFace = settings.uiFontFace;
        if (newFontFace == "Default")
            newFontFace = "Helvetica Neue,Verdana,Arial,DejaVu Sans,Liberation Sans,Helvetica,Roboto,Droid Sans";
        int oldFontSize = currentTheme.fontSize;
        if (oldFontFace != newFontFace) {
            currentTheme.fontFace = newFontFace;
            needUpdateTheme = true;
        }
        if (oldFontSize != settings.uiFontSize) {
            currentTheme.fontSize = settings.uiFontSize;
            needUpdateTheme = true;
        }
        if (needUpdateTheme) {
            Log.d("updating theme after UI font change");
            Platform.instance.onThemeChanged();
        }
        requestLayout();
    }

    void applySettings(DSourceEdit editor, IDESettings settings) {
        editor.settings(settings).applySettings();
    }

    private bool loadProject(Project project) {
        if (!project.load()) {
            _logPanel.logLine("Cannot read project " ~ project.filename);
            window.showMessageBox(UIString.fromId("ERROR_OPEN_PROJECT"c).value, UIString.fromId("ERROR_OPENING_PROJECT"c).value ~ toUTF32(project.filename));
            return false;
        }
        const auto msg = UIString.fromId("MSG_OPENED_PROJECT"c);
        _logPanel.logLine(toUTF32("Project file " ~ project.filename ~  " is opened ok"));
        
        warmUpImportPaths(project);
        return true;
    }

    public void warmUpImportPaths(Project project) {
        dcdInterface.warmUp(project.importPaths);
    }

    void restoreListOfOpenedFiles() {
        // All was opened, attempt to restore files
        WorkspaceFile[] files = currentWorkspace.files();
        for (int i; i < files.length; i++) 
            with (files[i])
            {
                // Opening file
                if (openSourceFile(filename))
                {
                    auto index = _tabs.tabIndex(filename);
                    // file is opened in tab
                    auto source = cast(DSourceEdit)_tabs.tabBody(filename);
                    // Caret position
                    source.setCaretPos(column, row, true, true);
                }
            }
    }

    void saveListOfOpenedFiles() {
        WorkspaceFile[] files;
        for (auto i = 0; i < _tabs.tabCount(); i++)
        {
            auto edit = cast(DSourceEdit)_tabs.tabBody(i);
            if (edit !is null) {
                auto file = new WorkspaceFile();
                file.filename = edit.filename();
                file.row = edit.caretPos.pos;
                file.column = edit.caretPos.line;
                files ~= file;
            }
        }
        currentWorkspace.files(files);
        // saving workspace
        currentWorkspace.save();
    }

    void openFileOrWorkspace(string filename) {
        // Open DlangIDE workspace file
        if (filename.isWorkspaceFile) {
            Workspace ws = new Workspace(this);
            if (ws.load(filename)) {
                askForUnsavedEdits(delegate() {
                    setWorkspace(ws);
                    hideHomeScreen();
                    // Write workspace to recent workspaces list
                    _settings.updateRecentWorkspace(filename);
                    restoreListOfOpenedFiles();
                });
            } else {
                window.showMessageBox(UIString.fromId("ERROR_OPEN_WORKSPACE"c).value, UIString.fromId("ERROR_OPENING_WORKSPACE"c).value);
                return;
            }
        } else if (filename.isProjectFile) { // Open non-DlangIDE project file or DlangIDE project
            _logPanel.clear();
            const auto msg = UIString.fromId("MSG_TRY_OPEN_PROJECT"c).value;
            _logPanel.logLine(msg ~ toUTF32(" " ~ filename));
            Project project = new Project(currentWorkspace, filename);
            if (!loadProject(project)) {
                //window.showMessageBox(UIString.fromId("MSG_OPEN_PROJECT"c), UIString.fromId("ERROR_INVALID_WS_OR_PROJECT_FILE"c));
                //_logPanel.logLine("File is not recognized as DlangIDE project or workspace file");
                return;
            }
            string defWsFile = project.defWorkspaceFile;
            if (currentWorkspace) {
                Project existing = currentWorkspace.findProject(project.filename);
                if (existing) {
                    _logPanel.logLine("Project is already in workspace"d);
                    window.showMessageBox(UIString.fromId("MSG_OPEN_PROJECT"c), UIString.fromId("MSG_PROJECT_ALREADY_OPENED"c));
                    return;
                }
                window.showMessageBox(UIString.fromId("MSG_OPEN_PROJECT"c), UIString.fromId("QUESTION_NEW_WORKSPACE"c),

                                      [ACTION_ADD_TO_CURRENT_WORKSPACE, ACTION_CREATE_NEW_WORKSPACE, ACTION_CANCEL], 0, delegate(const Action result) {
                                          if (result.id == IDEActions.CreateNewWorkspace) {
                                              // new ws
                                              createNewWorkspaceForExistingProject(project);
                                              hideHomeScreen();
                                          } else if (result.id == IDEActions.AddToCurrentWorkspace) {
                                              // add to current
                                              currentWorkspace.addProject(project);
                                              loadProject(project);
                                              currentWorkspace.save();
                                              refreshWorkspace();
                                              hideHomeScreen();
                                          }
                                          return true;
                                      });
            } else {
                // new workspace file
                createNewWorkspaceForExistingProject(project);
            }
        } else {
            _logPanel.logLine("File is not recognized as DlangIDE project or workspace file");
            window.showMessageBox(UIString.fromId("ERROR_INVALID_WORKSPACE_FILE"c), UIString.fromId("ERROR_INVALID_WS_OR_PROJECT_FILE"c));
        }
    }

    void refreshWorkspace() {
        _logPanel.logLine("Refreshing workspace");
        _wsPanel.reloadItems();
        closeRemovedDocuments();
    }

    void createNewWorkspaceForExistingProject(Project project) {
        string defWsFile = project.defWorkspaceFile;
        _logPanel.logLine("Creating new workspace " ~ defWsFile);
        // new ws
        Workspace ws = new Workspace(this);
        ws.name = project.name;
        ws.description = project.description;
        Log.d("workspace name: ", project.name);
        Log.d("workspace description: ", project.description);
        ws.addProject(project);
        // Load project data
        loadProject(project);
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
        // Open main file for project
        if (ws && ws.startupProject && ws.startupProject.mainSourceFile 
            && (currentWorkspace.files == null || currentWorkspace.files.length == 0)) {
            openSourceFile(ws.startupProject.mainSourceFile.filename);
            _tabs.setFocus();
        }
        if (ws) {
            _wsPanel.visibility = Visibility.Visible;
            _settings.updateRecentWorkspace(ws.filename);
            _settings.setRecentPath(ws.dir, "FILE_OPEN_WORKSPACE_PATH");
            if (ws.startupProject) {
                warmUpImportPaths(ws.startupProject);
            }
        } else {
            _wsPanel.visibility = Visibility.Gone;
        }

    }

    void refreshProject(Project project) {
        if (currentWorkspace && project.loadSelections()) {
            currentWorkspace.cleanupUnusedDependencies();
            refreshWorkspace();
        }
    }

    void revealProjectInExplorer(Project project) {
        Platform.instance.showInFileManager(project.items.filename);
    }

    void buildProject(BuildOperation buildOp, Project project, BuildResultListener listener = null) {
        if (!currentWorkspace) {
            _logPanel.logLine("No workspace is opened");
            return;
        }
        if (!project)
            project = currentWorkspace.startupProject;
        if (!project) {
            _logPanel.logLine("No project is opened");
            return;
        }
        _logPanel.activateLogTab();
        if (!listener) {
            if (buildOp == BuildOperation.Upgrade || buildOp == BuildOperation.Build || buildOp == BuildOperation.Rebuild) {
                listener = delegate(int result) {
                    if (!result) {
                        // success: update workspace
                        refreshProject(project);
                    } else {
                        handleBuildError(result, project);
                    }
                };
            }
        }
        ProjectSettings projectSettings = project.settings;
        string toolchain = projectSettings.getToolchain(_settings);
        string arch = projectSettings.getArch(_settings);
        string dubExecutable = _settings.dubExecutable;
        string dubAdditionalParams = projectSettings.getDubAdditionalParams(_settings);
        Builder op = new Builder(this, project, _logPanel, currentWorkspace.projectConfiguration, currentWorkspace.buildConfiguration, buildOp, 
                                 dubExecutable, dubAdditionalParams,
                                 toolchain,
                                 arch,
                                 listener);
        setBackgroundOperation(op);
    }
    
    /// updates list of available configurations
    void setProjectConfigurations(dstring[] items) {
        projectConfigurationCombo.items = items;
    }
    
    /// handle files dropped to application window
    void onFilesDropped(string[] filenames) {
        //Log.d("onFilesDropped(", filenames, ")");
        bool first = true;
        for (int i = 0; i < filenames.length; i++) {
            openSourceFile(filenames[i], null, first);
            first = false;
        }
    }

    void restoreUIStateOnStartup() {
        window.restoreWindowState(_settings.uiState);
    }

    /// return false to prevent closing
    bool onCanClose() {
        askForUnsavedEdits(delegate() {
            if (currentWorkspace) {
                // Remember opened files
                saveListOfOpenedFiles();
            }
            window.close();
        });
        return false;
    }
    /// called when main window is closing
    void onWindowClose() {
        window.saveWindowState(_settings.uiState);
        _settings.save();
        Log.i("onWindowClose()");
        stopExecution();
    }
}

