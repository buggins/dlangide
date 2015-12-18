module dlangide.ui.stackpanel;

import dlangui;

import std.string : format;
import ddebug.common.debugger;

class StackPanel : DockWindow {

    this(string id) {
        super(id);
        _caption.text = "Stack"d;
    }

    override protected Widget createBodyWidget() {
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        VerticalLayout root = new VerticalLayout();
        root.layoutWidth = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        _comboBox = new ComboBox("threadComboBox", ["Thread1"d]);
        _comboBox.layoutWidth = FILL_PARENT;
        _comboBox.selectedItemIndex = 0;
        _grid = new StringGridWidget("stackGrid");
        _grid.resize(2, 20);
        _grid.showColHeaders = true;
        _grid.showRowHeaders = false;
        _grid.layoutHeight = FILL_PARENT;
        _grid.layoutWidth = FILL_PARENT;
        _grid.setColTitle(0, "Function"d);
        _grid.setColTitle(1, "Address"d);
        _grid.setCellText(0, 0, "main()"d);
        _grid.layoutWidth = FILL_PARENT;
        _grid.layoutHeight = FILL_PARENT;
        root.addChild(_comboBox);
        root.addChild(_grid);
        return root;
    }

    StringGridWidget _grid;
    ComboBox _comboBox;
    DebugThreadList _debugInfo;
    DebugThread _selectedThread;
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
        if (_debugInfo) {
            _comboBox.enabled = true;
            dstring[] threadNames;
            for (int i = 0; i < _debugInfo.length; i++) {
                threadNames ~= _debugInfo[i].name.toUTF32;
                if (_debugInfo[i].id == _currentThreadId) {
                    _currentThreadIndex = i;
                    _selectedThread = _debugInfo[i];
                    if (currentFrame <= _selectedThread.length)
                        _currentFrame = currentFrame;
                }
            }
            _comboBox.items = threadNames;
            if (_currentThreadIndex >= 0 && _selectedThread.length > 0) {
                _comboBox.selectedItemIndex = _currentThreadIndex;
                _grid.resize(2, _selectedThread.length);
                for (int i = 0; i < _selectedThread.length; i++) {
                    _grid.setCellText(0, i, _selectedThread[i].func.toUTF32);
                    _grid.setCellText(1, i, ""d);
                }
            } else {
                _grid.resize(2, 1);
                _grid.setCellText(0, 0, "No info"d);
                _grid.setCellText(1, 0, ""d);
            }
        } else {
            _comboBox.enabled = false;
        }
    }

    protected void onPopupMenuItem(MenuItem item) {
        if (item.action)
            handleAction(item.action);
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        return super.handleAction(a);
    }
}

