module dlangide.ui.outputpanel;

import dlangui.all;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

class OutputPanel : DockWindow {
    protected LogWidget _logWidget;

    this(string id) {
        super(id);
        _caption.text = "Output"d;
        dockAlignment = DockAlignment.Bottom;
    }

    override protected Widget createBodyWidget() {
        _logWidget = new LogWidget("logwidget");
        _logWidget.readOnly = true;
        _logWidget.layoutHeight(FILL_PARENT).layoutHeight(FILL_PARENT);
        return _logWidget;
    }

    void addLogLines(string category, dstring[] msg...) {
        _logWidget.appendLines(msg);
    }
}
