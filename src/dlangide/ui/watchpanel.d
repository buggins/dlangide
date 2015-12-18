module dlangide.ui.watchpanel;

import dlangui;

import std.string : format;
import ddebug.common.debugger;

class VariablesWindow : StringGridWidget {
    this(string ID = null) {
        super(ID);
        resize(3, 20);
        showColHeaders = true;
        showRowHeaders = false;
        layoutHeight = FILL_PARENT;
        layoutWidth = FILL_PARENT;
        setColTitle(0, "Variable"d);
        setColTitle(1, "Value"d);
        setColTitle(2, "Type"d);
        setCellText(0, 0, "a"d);
        setCellText(1, 0, "1"d);
        setCellText(2, 0, "int"d);
        setCellText(0, 1, "b"d);
        setCellText(1, 1, "42"d);
        setCellText(2, 1, "ulong"d);
    }
}

class WatchPanel : DockWindow {

    this(string id) {
        _showCloseButton = false;
        dockAlignment = DockAlignment.Bottom;
        super(id);
    }

    protected TabWidget _tabs;
    protected VariablesWindow _locals;
    protected VariablesWindow _autos;

    override protected Widget createBodyWidget() {
        _tabs = new TabWidget("WatchPanelTabs", Align.Bottom);
        _tabs.setStyles(null, STYLE_TAB_DOWN_DARK, STYLE_TAB_DOWN_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT);
        _tabs.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _tabs.tabHost.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        _locals = new VariablesWindow("watchLocals");
        _autos = new VariablesWindow("watchAutos");
        _tabs.addTab(_locals, "Locals"d);
        _tabs.addTab(_autos, "Autos"d);
		_tabs.selectTab("watchAutos");

        return _tabs;
    }

	override protected void init() {
		//styleId = STYLE_DOCK_WINDOW;
        styleId = null;
        //_caption.text = "Watch"d;
        _bodyWidget = createBodyWidget();
		//_bodyWidget.styleId = STYLE_DOCK_WINDOW_BODY;
		addChild(_bodyWidget);
	}

    protected void onPopupMenuItem(MenuItem item) {
        if (item.action)
            handleAction(item.action);
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        return super.handleAction(a);
    }

    DebugThreadList _debugInfo;
    DebugThread _selectedThread;
    DebugFrame _frame;
    ulong _currentThreadId;
    int _currentThreadIndex;
    int _currentFrame;
    void updateDebugInfo(DebugThreadList data, ulong currentThreadId, int currentFrame) {
        _debugInfo = data;
        if (currentThreadId == 0)
            currentThreadId = data.currentThreadId;
        _currentThreadId = currentThreadId;
        _currentThreadIndex = -1;
        _currentFrame = 0;
        _selectedThread = null;
        _frame = null;

        if (_debugInfo) {
            for (int i = 0; i < _debugInfo.length; i++) {
                if (_debugInfo[i].id == _currentThreadId) {
                    _currentThreadIndex = i;
                    _selectedThread = _debugInfo[i];
                    if (currentFrame <= _selectedThread.length) {
                        _currentFrame = currentFrame;
                        _frame = _selectedThread[_currentFrame];
                    }
                }
            }
        } else {
        }
    }
}

