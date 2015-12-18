module dlangide.ui.watchpanel;

import dlangui;

import std.string : format;
import ddebug.common.debugger;

class VariablesWindow : StringGridWidget {
    DebugFrame _frame;
    this(string ID = null) {
        super(ID);
        resize(3, 0);
        showColHeaders = true;
        showRowHeaders = false;
        layoutHeight = FILL_PARENT;
        layoutWidth = FILL_PARENT;
        setColTitle(0, "Variable"d);
        setColTitle(1, "Value"d);
        setColTitle(2, "Type"d);
        autoFit();
    }
    void setFrame(DebugFrame frame) {
        _frame = frame;
        if (frame && frame.locals) {
            resize(3, frame.locals.length);
            for (int i = 0; i < frame.locals.length; i++) {
                DebugVariable var = frame.locals[i];
                setCellText(0, i, var.name.toUTF32);
                setCellText(1, i, var.value.toUTF32);
                setCellText(2, i, var.type.toUTF32);
            }
            autoFit();
        } else {
            resize(3, 0);
            autoFit();
        }
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
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
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
        }
        _locals.setFrame(_frame);
        _autos.setFrame(_frame);
    }
}

