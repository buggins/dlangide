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
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import dlangui.core.stdaction;

import dlangide.ui.commands;
import dlangide.ui.wspanel;
import dlangide.ui.outputpanel;
import dlangide.ui.dsourceedit;
import dlangide.ui.homescreen;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.conv;
import std.utf;
import std.algorithm;
import std.path;

bool isSupportedSourceTextFileFormat(string filename) {
    return (filename.endsWith(".d") || filename.endsWith(".txt") || filename.endsWith(".cpp") || filename.endsWith(".h") || filename.endsWith(".c")
        || filename.endsWith(".json") || filename.endsWith(".dd") || filename.endsWith(".ddoc") || filename.endsWith(".xml") || filename.endsWith(".html")
        || filename.endsWith(".html") || filename.endsWith(".css") || filename.endsWith(".log") || filename.endsWith(".hpp"));
}

/// DIDE app frame
class IDEFrame : AppFrame {

    MenuItem mainMenuItems;
    WorkspacePanel _wsPanel;
    OutputPanel _logPanel;
    DockHost _dockHost;
    TabWidget _tabs;

    dstring frameWindowCaptionSuffix = "DLangIDE"d;

    this(Window window) {
        super();
        window.mainWidget = this;
    }

    override protected void init() {
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
        if (!file)
            file = _wsPanel.findSourceFileItem(filename);
        Log.d("openSourceFile ", filename);
        int index = _tabs.tabIndex(filename);
        if (index >= 0) {
            // file is already opened in tab
            _tabs.selectTab(index, true);
        } else {
            // open new file
            DSourceEdit editor = new DSourceEdit(filename);
            if (file ? editor.load(file) : editor.load(filename)) {
                _tabs.addTab(editor, toUTF32(baseName(filename)));
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
            _tabs.addTab(home, "Home"d);
            _tabs.selectTab(HOME_SCREEN_ID, true);
        }
    }

    void onTabChanged(string newActiveTabId, string previousTabId) {
        int index = _tabs.tabIndex(newActiveTabId);
        if (index >= 0) {
            TabItem tab = _tabs.tab(index);
            ProjectSourceFile file = cast(ProjectSourceFile)tab.objectParam;
            if (file) {
                // tab is source file editor
                _wsPanel.selectItem(file);
                focusEditor(file.filename);
            }
            window.windowCaption(tab.text.value ~ " - "d ~ frameWindowCaptionSuffix);
        }
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
        _tabs.setStyles(STYLE_DOCK_HOST_BODY, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT);
        _tabs.onTabChangedListener = &onTabChanged;
        _tabs.onTabCloseListener = &onTabClose;

        _dockHost.bodyWidget = _tabs;

        //=============================================================
        // Create workspace docked panel
        _wsPanel = new WorkspacePanel("workspace");
        _wsPanel.sourceFileSelectionListener = &onSourceFileSelected;
        _dockHost.addDockedWindow(_wsPanel);

        _logPanel = new OutputPanel("output");
        _logPanel.addLogLines(null, "Line 1"d);
        _logPanel.addLogLines(null, "Line 2"d);
        _logPanel.addLogLines(null, "Line 3"d, "Line 4"d);

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

		editItem.add(new Action(20, "MENU_EDIT_PREFERENCES"));

        MenuItem projectItem = new MenuItem(new Action(21, "MENU_PROJECT"));
        projectItem.add(ACTION_PROJECT_SET_STARTUP, ACTION_PROJECT_SETTINGS);

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
        mainMenuItems.add(buildItem);
        mainMenuItems.add(debugItem);
		//mainMenuItems.add(viewItem);
		mainMenuItems.add(windowItem);
        mainMenuItems.add(helpItem);

        MainMenu mainMenu = new MainMenu(mainMenuItems);
        mainMenu.backgroundColor = 0xd6dbe9;
        return mainMenu;
    }
	
    /// create app toolbars
    override protected ToolBarHost createToolbars() {
        ToolBarHost res = new ToolBarHost();
        ToolBar tb;
        tb = res.getOrAddToolbar("Standard");
        tb.addButtons(ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_SEPARATOR);

        tb.addButtons(ACTION_DEBUG_START);
        ToolBarComboBox cbBuildConfiguration = new ToolBarComboBox("buildConfig", ["Debug"d, "Release"d, "Unittest"d]);
        tb.addControl(cbBuildConfiguration);

        tb = res.getOrAddToolbar("Edit");
        tb.addButtons(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_SEPARATOR,
                      ACTION_EDIT_UNDO, ACTION_EDIT_REDO);
        return res;
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case IDEActions.FileExit:
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
                    FileDialog dlg = new FileDialog(caption, window, null);
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
                case IDEActions.WindowCloseAllDocuments:
                    askForUnsavedEdits(delegate() {
                        closeAllDocuments();
                    });
                    return true;
                case IDEActions.FileOpenWorkspace:
                    UIString caption;
                    caption = "Open Workspace or Project"d;
                    FileDialog dlg = new FileDialog(caption, window, null);
                    dlg.addFilter(FileFilterEntry(UIString("Workspace and project files"d), "*.dlangidews;dub.json"));
                    dlg.onDialogResult = delegate(Dialog dlg, const Action result) {
						if (result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                        }
                    };
                    dlg.show();
                    return true;
                default:
                    return super.handleAction(a);
            }
        }
		return false;
	}

    bool loadWorkspace(string path) {
        // testing workspace loader
        Workspace ws = new Workspace();
        ws.load(path);
        currentWorkspace = ws;
        _wsPanel.workspace = ws;
        return true;
    }
}

Widget createAboutWidget() 
{
	LinearLayout res = new VerticalLayout();
	res.padding(Rect(10,10,10,10));
	res.addChild(new TextWidget(null, "DLangIDE"d));
	res.addChild(new TextWidget(null, "(C) Vadim Lopatin, 2014"d));
	res.addChild(new TextWidget(null, "http://github.com/buggins/dlangide"d));
	res.addChild(new TextWidget(null, "So far, it's just a test for DLangUI library."d));
	res.addChild(new TextWidget(null, "Later I hope to make working IDE :)"d));
	Button closeButton = new Button("close", "Close"d);
	closeButton.onClickListener = delegate(Widget src) {
		Log.i("Closing window");
		res.window.close();
		return true;
	};
	res.addChild(closeButton);
	return res;
}
