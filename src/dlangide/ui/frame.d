module dlangide.ui.frame;

import dlangui.widgets.menu;
import dlangui.widgets.tabs;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.controls;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import dlangide.ui.commands;

import std.conv;

enum : int {
    ACTION_FILE_OPEN = 5500,
    ACTION_FILE_SAVE,
    ACTION_FILE_CLOSE,
    ACTION_FILE_EXIT,
    ACTION_HELP_ABOUT,
}


class IDEFrame : VerticalLayout, MenuItemClickHandler {

    MainMenu mainMenu;
    MenuItem mainMenuItems;

    this(Window window) {
        super("IDEFrame");


        createMenu();
        createTabs();

        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        //window.mainWidget = this;
    }

    void createTabs() {
        // editor tabs
        TabWidget tabs = new TabWidget("TABS");
        tabs.layoutWidth = FILL_PARENT;
        tabs.layoutHeight = FILL_PARENT;


		// create Editors test tab
		VerticalLayout editors = new VerticalLayout("editors");
        editors.layoutWidth = FILL_PARENT;
        editors.layoutHeight = FILL_PARENT;
        EditBox editBox = new EditBox("editbox1", "Some text\nSecond line\nYet another line\n\n\tforeach(s;lines);\n\t\twriteln(s);\n"d);
        editBox.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        editBox.minFontSize(12).maxFontSize(75); // allow font zoom with Ctrl + MouseWheel
		editors.addChild(editBox);
		//editBox.popupMenu = editPopupItem;
        tabs.addTab(editors, "Sample"d);

        addChild(tabs);

		tabs.selectTab("editors");

    }

    void createMenu() {
        mainMenuItems = new MenuItem();
        MenuItem fileItem = new MenuItem(new Action(1, "MENU_FILE"));
        fileItem.add(new Action(ACTION_FILE_OPEN, "MENU_FILE_OPEN"c, "document-open", KeyCode.KEY_O, KeyFlag.Control));
		fileItem.add(new Action(ACTION_FILE_SAVE, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control));
		fileItem.add(new Action(ACTION_FILE_EXIT, "MENU_FILE_EXIT"c, "document-close"c, KeyCode.KEY_X, KeyFlag.Alt));
        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));
		editItem.add(new Action(EditorActions.Copy, "MENU_EDIT_COPY"c, "edit-copy", KeyCode.KEY_C, KeyFlag.Control));
		editItem.add(new Action(EditorActions.Paste, "MENU_EDIT_PASTE"c, "edit-paste", KeyCode.KEY_V, KeyFlag.Control));
		editItem.add(new Action(EditorActions.Cut, "MENU_EDIT_CUT"c, "edit-cut", KeyCode.KEY_X, KeyFlag.Control));
		editItem.add(new Action(EditorActions.Undo, "MENU_EDIT_UNDO"c, "edit-undo", KeyCode.KEY_Z, KeyFlag.Control));
		editItem.add(new Action(EditorActions.Redo, "MENU_EDIT_REDO"c, "edit-redo", KeyCode.KEY_Y, KeyFlag.Control));
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
        mainMenu = new MainMenu(mainMenuItems);
        addChild(mainMenu);

		mainMenu.onMenuItemClickListener = this;

    }
	
    override bool onMenuItemClick(MenuItem item) {
        Log.d("mainMenu.onMenuItemListener", item.label);
        const Action a = item.action;
        if (a) {
            switch (a.id) {
                case ACTION_FILE_EXIT:
                    return true;
                case ACTION_HELP_ABOUT:
                    Window wnd = Platform.instance.createWindow("About...", window, WindowFlag.Modal);
                    wnd.mainWidget = createAboutWidget();
                    wnd.show();
                    return true;
                case ACTION_FILE_OPEN:
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
