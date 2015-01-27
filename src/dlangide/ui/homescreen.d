module dlangide.ui.homescreen;

import dlangui.widgets.layouts;
import dlangui.widgets.widget;
import dlangui.widgets.scroll;
import dlangui.widgets.controls;
import dlangide.ui.frame;
import dlangide.ui.commands;

class HomeScreen : ScrollWidget {
    protected IDEFrame _frame;
    protected HorizontalLayout _content;
    protected VerticalLayout _startItems;
    protected VerticalLayout _recentItems;
    this(string ID, IDEFrame frame) {
        super(ID);
        backgroundColor = 0xFFFFFF;
        _frame = frame;
        _content = new HorizontalLayout("HOME_SCREEN_BODY");
        _content.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        VerticalLayout _column1 = new VerticalLayout();
        _column1.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(20, 20, 20, 20));
        VerticalLayout _column2 = new VerticalLayout();
        _column2.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(20, 20, 20, 20));
        _content.addChild(_column1);
        _content.addChild(_column2);
        _column1.addChild((new TextWidget(null, "Dlang IDE"d)).fontSize(32).textColor(0x000080));
        _column1.addChild((new TextWidget(null, "D language IDE written in D"d)).fontSize(20));
        _column1.addChild((new TextWidget(null, "(c) Vadim Lopatin 2015"d)).fontSize(22).textColor(0x000080));
        _column1.addChild(new VSpacer());
        _column1.addChild((new TextWidget(null, "Start with:"d)).fontSize(20).textColor(0x000040));
        _startItems = new VerticalLayout();
        _recentItems = new VerticalLayout();
        _startItems.addChild(new ImageTextButton(ACTION_FILE_OPEN_WORKSPACE));
        _startItems.addChild(new ImageTextButton(ACTION_FILE_NEW_WORKSPACE));
        _startItems.addChild(new ImageTextButton(ACTION_FILE_NEW_PROJECT));
        _column1.addChild(_startItems);
        _column1.addChild(new VSpacer());
        _column1.addChild((new TextWidget(null, "Recent:"d)).fontSize(20).textColor(0x000040));
        _recentItems.addChild((new TextWidget(null, "No recent items"d)));
        _column1.addChild(_recentItems);
        _column1.addChild(new VSpacer());
        _column2.addChild((new TextWidget(null, "Useful Links:"d)).fontSize(20).textColor(0x000040));
        _column2.addChild(new UrlImageTextButton(null, "D Programming Language"d, "http://dlang.org/"));
        _column2.addChild(new UrlImageTextButton(null, "DUB repository"d, "http://code.dlang.org/"));
        _column2.addChild(new UrlImageTextButton(null, "DLangUI on GitHub"d, "https://github.com/buggins/dlangui"));
        _column2.addChild(new UrlImageTextButton(null, "DLangIDE on GitHub"d, "https://github.com/buggins/dlangide"));
        _column2.addChild(new VSpacer());
        contentWidget = _content;
    }
}
