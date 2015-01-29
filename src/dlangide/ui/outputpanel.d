module dlangide.ui.outputpanel;

import dlangui.all;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.utf;

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

    void appendText(string category, dstring msg) {
        _logWidget.appendText(msg);
    }

    void logLine(string category, dstring msg) {
        appendText(category, msg ~ "\n");
    }

    void logLine(dstring msg) {
        logLine(null, msg);
    }

    void logLine(string category, string msg) {
        appendText(category, toUTF32(msg ~ "\n"));
    }

    void logLine(string msg) {
        logLine(null, msg);
    }

	void clear(string category = null) {
		_logWidget.text = ""d;
	}
}
