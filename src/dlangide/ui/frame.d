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
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import dlangide.ui.commands;
import dlangide.ui.wspanel;
import dlangide.ui.outputpanel;
import dlangide.ui.dsourceedit;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.conv;
import std.utf;
import std.algorithm;

/// DIDE app frame
class IDEFrame : AppFrame {

    MenuItem mainMenuItems;
    WorkspacePanel _wsPanel;
    OutputPanel _logPanel;
    DockHost _dockHost;
    TabWidget _tabs;

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
        int index = _tabs.tabIndex(file.filename);
        if (index >= 0) {
            // file is already opened in tab
            _tabs.selectTab(index, true);
        } else {
            // open new file
            DSourceEdit editor = new DSourceEdit(file.filename);
            if (editor.load(file)) {
                _tabs.addTab(editor, toUTF32(file.name));
                index = _tabs.tabIndex(file.filename);
                TabItem tab = _tabs.tab(file.filename);
                tab.objectParam = file;
                _tabs.selectTab(index, true);
            } else {
                destroy(editor);
                if (window)
                    window.showMessageBox(UIString("File open error"d), UIString("Failed to open file "d ~ toUTF32(file.filename)));
                return false;
            }
        }
        if (activate) {
            focusEditor(file.filename);
        }
        requestLayout();
        return true;
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
        fileItem.add(ACTION_FILE_NEW, ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_FILE_EXIT);

        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));
		editItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO);

		editItem.add(new Action(20, "MENU_EDIT_PREFERENCES"));
		MenuItem windowItem = new MenuItem(new Action(3, "MENU_WINDOW"c));
        windowItem.add(new Action(30, "MENU_WINDOW_PREFERENCES"));
        MenuItem helpItem = new MenuItem(new Action(4, "MENU_HELP"c));
        helpItem.add(new Action(40, "MENU_HELP_VIEW_HELP"));
        helpItem.add(ACTION_HELP_ABOUT);
        mainMenuItems.add(fileItem);
        mainMenuItems.add(editItem);
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
        tb.addButtons(ACTION_FILE_OPEN, ACTION_FILE_SAVE);
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
                case IDEActions.FileOpen:
                    UIString caption;
                    caption = "Open Text File"d;
                    FileDialog dlg = new FileDialog(caption, window, null);
                    dlg.onDialogResult = delegate(Dialog dlg, const Action result) {
                        //
                    };
                    dlg.show();
                    return true;
                default:
                    if (window.focusedWidget)
                        return window.focusedWidget.handleAction(a);
                    else
                        return handleAction(a);
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
