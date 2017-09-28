module dlangide.ui.homescreen;

import dlangui.widgets.layouts;
import dlangui.widgets.widget;
import dlangui.widgets.scroll;
import dlangui.widgets.controls;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangui.core.i18n;

import std.path;
import std.utf : toUTF32;

immutable string HELP_PAGE_URL = "https://github.com/buggins/dlangide/wiki";
immutable string HELP_DONATION_URL = "https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=H2ADZV8S6TDHQ";


class HomeScreen : ScrollWidget {
    protected IDEFrame _frame;
    protected HorizontalLayout _content;
    protected VerticalLayout _startItems;
    protected VerticalLayout _recentItems;
    this(string ID, IDEFrame frame) {
        super(ID);
        import dlangide.ui.frame;
        //styleId = STYLE_EDIT_BOX;
        _frame = frame;
        _content = new HorizontalLayout("HOME_SCREEN_BODY");
        _content.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        VerticalLayout _column1 = new VerticalLayout();
        int pad = BACKEND_GUI ? 20 : 1;
        _column1.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(pad, pad, pad, pad));
        VerticalLayout _column2 = new VerticalLayout();
        _column2.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(pad, pad, pad, pad));
        _content.addChild(_column1);
        _content.addChild(_column2);
        _column1.addChild((new TextWidget(null, "Dlang IDE "d ~ DLANGIDE_VERSION)).styleId("HOME_SCREEN_TITLE"));
        _column1.addChild((new TextWidget(null, UIString.fromId("DESCRIPTION"c))).styleId("HOME_SCREEN_TITLE2"));
        _column1.addChild((new TextWidget(null, UIString.fromId("COPYRIGHT"c))).styleId("HOME_SCREEN_TITLE2"));
        _column1.addChild(new VSpacer());
        _column1.addChild((new TextWidget(null, UIString.fromId("START_WITH"c))).styleId("HOME_SCREEN_TITLE"));
        _startItems = new VerticalLayout();
        _recentItems = new VerticalLayout();
        _startItems.addChild(new ImageTextButton(ACTION_FILE_OPEN_WORKSPACE));
        _startItems.addChild(new ImageTextButton(ACTION_FILE_NEW_WORKSPACE));
        _startItems.addChild(new ImageTextButton(ACTION_FILE_NEW_PROJECT));
        _column1.addChild(_startItems);
        _column1.addChild(new VSpacer());
        
        // Recent workspaces 
        _column1.addChild((new TextWidget(null, UIString.fromId("RECENT"c))).styleId("HOME_SCREEN_TITLE"));
        string[] recentWorkspaces = _frame.settings.recentWorkspaces;
        if (recentWorkspaces.length) {
            foreach(fn; recentWorkspaces) {
                Action a = ACTION_FILE_OPEN_WORKSPACE.clone();
                a.label = UIString.fromRaw(toUTF32(stripExtension(baseName(fn))));
                a.stringParam = fn;
                _column1.addChild(new LinkButton(a));
            }
        } else {
            _recentItems.addChild((new TextWidget(null, UIString.fromId("NO_RECENT"c))));
        }
        _column1.addChild(_recentItems);
        
        // Useful links
        _column1.addChild(new VSpacer());
        _column2.addChild((new TextWidget(null, UIString.fromId("USEFUL_LINKS"c))).styleId("HOME_SCREEN_TITLE"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("D_LANG"c).value, "http://dlang.org/"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_DOWNLOADS"c).value, "https://dlang.org/download.html"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DUB_REP"c).value, "http://code.dlang.org/"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_UI"c).value, "https://github.com/buggins/dlangui"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_IDE"c).value, "https://github.com/buggins/dlangide"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_IDE_HELP"c).value, HELP_PAGE_URL));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_TOUR"c).value, "https://tour.dlang.org/"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_VIBED"c).value, "http://vibed.org/"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_FORUM"c).value, "http://forum.dlang.org/"));
        _column1.addChild(new VSpacer());
        _column2.addChild((new TextWidget(null, UIString.fromId("DLANG_IDE_DONATE"c))).styleId("HOME_SCREEN_TITLE"));
        _column2.addChild(new UrlImageTextButton(null, UIString.fromId("DLANG_IDE_DONATE_PAYPAL"c).value, HELP_DONATION_URL));

        _column2.addChild(new VSpacer());
        contentWidget = _content;
    }
}
