module dlangide.ui.outputpanel;

import dlangui.all;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.utf;
import std.regex;

///
interface CompilerLogIssueClickHandler {
	bool onCompilerLogIssueClick(dstring filename, int line, int column);
}

///
class CompilerLogWidget : LogWidget {

	Signal!CompilerLogIssueClickHandler compilerLogIssueClickHandler;

	auto ctr = ctRegex!(r"(.+)\((\d+)\): (Error|Warning): (.+)"d);

	/// forward to super c'tor
	this(string ID) {
		super(ID);
	}

	///
	override bool onMouseEvent(MouseEvent event) {

		if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
			super.onMouseEvent(event);

			auto logLine = this.content.line(this._caretPos.line);

			//src\tetris.d(49): Error: found 'return' when expecting ';' following statement

			auto match = matchFirst(logLine, ctr);

			if(!match.empty)
			{
				if (compilerLogIssueClickHandler.assigned) {
					import std.conv:to;
					compilerLogIssueClickHandler(match[1], to!int(match[2]), 0);
				}
			}

			return true;
		}

		return super.onMouseEvent(event);
	}
}

///
class OutputPanel : DockWindow {

	Signal!CompilerLogIssueClickHandler compilerLogIssueClickHandler;

	protected CompilerLogWidget _logWidget;

    this(string id) {
        super(id);
        _caption.text = "Output"d;
        dockAlignment = DockAlignment.Bottom;
    }

    override protected Widget createBodyWidget() {
		_logWidget = new CompilerLogWidget("logwidget");
        _logWidget.readOnly = true;
        _logWidget.layoutHeight(FILL_PARENT).layoutHeight(FILL_PARENT);
		_logWidget.compilerLogIssueClickHandler = &onIssueClick;
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

	private bool onIssueClick(dstring fn, int line, int column)
	{
		if (compilerLogIssueClickHandler.assigned) {
			compilerLogIssueClickHandler(fn, line, column);
		}

		return true;
	}
}
