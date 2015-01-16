module dlangide.ui.frame;

import dlangui.widgets.menu;
import dlangui.widgets.tabs;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.controls;
import dlangui.widgets.appframe;
import dlangui.widgets.docks;
import dlangui.widgets.toolbars;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import dlangide.ui.commands;
import dlangide.ui.wspanel;
import dlangide.workspace.workspace;

import std.conv;



class IDEFrame : AppFrame {

    MenuItem mainMenuItems;
    WorkspacePanel _wsPanel;
    DockHost _dockHost;

    this(Window window) {
        super();
        window.mainWidget = this;
    }

    override protected void init() {
        super.init();
    }


    /// create app body widget
    override protected Widget createBody() {
        _dockHost = new DockHost();

        //=============================================================
        // Create body - Tabs

        // editor tabs
        TabWidget tabs = new TabWidget("TABS");
        tabs.setStyles("TAB_UP_DARK", "TAB_UP_BUTTON_DARK", "TAB_UP_BUTTON_DARK_TEXT");
        tabs.styleId = STYLE_DOCK_HOST_BODY;
        
		// create Editors test tab
		//VerticalLayout editors = new VerticalLayout("editors");
        //editors.layoutWidth = FILL_PARENT;
        //editors.layoutHeight = FILL_PARENT;
        EditBox editBox = new EditBox("editbox1", "Some text\nSecond line\nYet another line\n\n\tforeach(s;lines);\n\t\twriteln(s);\n"d);
        editBox.enabled = true;
        editBox.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        editBox.minFontSize(12).maxFontSize(75); // allow font zoom with Ctrl + MouseWheel
        editBox.fontFamily = FontFamily.MonoSpace;
        editBox.focusable = true;
		//editors.addChild(editBox);
		//editBox.popupMenu = editPopupItem;
        tabs.addTab(editBox, "Sample"d);
        //tabs.addTab(editors, "Sample"d);
		tabs.selectTab("editbox1");


        _dockHost.bodyWidget = tabs;

        //=============================================================
        // Create workspace docked panel
        _wsPanel = new WorkspacePanel("workspace");
        _dockHost.addDockedWindow(_wsPanel);

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
		MenuItem aboutItem = new MenuItem(new Action(ACTION_HELP_ABOUT, "MENU_HELP_ABOUT"));
        helpItem.add(aboutItem);
		aboutItem.onMenuItemClick = delegate(MenuItem item) {
			Window wnd = Platform.instance.createWindow("About...", window, WindowFlag.Modal);
			wnd.mainWidget = createAboutWidget();
			wnd.show();
			return true;
		};
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
        tb.addButtons(ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_SEPARATOR, 
                      ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT);
        return res;
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case IDEActions.FileExit:
                    return true;
                case ACTION_HELP_ABOUT:
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
