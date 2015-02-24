module dlangide.ui.outputpanel;

import dlangui;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.utf;
import std.regex;
import std.algorithm : startsWith;

/// event listener to navigate by error/warning position
interface CompilerLogIssueClickHandler {
	bool onCompilerLogIssueClick(dstring filename, int line, int column);
}

/// Log widget with parsing of compiler output
class CompilerLogWidget : LogWidget {

	Signal!CompilerLogIssueClickHandler compilerLogIssueClickHandler;

	auto ctr = ctRegex!(r"(.+)\((\d+)\): (Error|Warning|Deprecation): (.+)"d);

	/// forward to super c'tor
	this(string ID) {
		super(ID);
	}

    /** 
    Custom text color and style highlight (using text highlight) support.

    Return null if no syntax highlight required for line.
    */
    override protected CustomCharProps[] handleCustomLineHighlight(int line, dstring txt, ref CustomCharProps[] buf) {
        auto match = matchFirst(txt, ctr);
        uint defColor = textColor;
        const uint filenameColor = 0x0000C0;
        const uint errorColor = 0xFF0000;
        const uint warningColor = 0x606000;
        const uint deprecationColor = 0x802040;
        uint flags = 0;
        if(!match.empty) {
            if (buf.length < txt.length)
                buf.length = txt.length;
            CustomCharProps[] colors = buf[0..txt.length];
            uint cl = filenameColor;
            flags = TextFlag.Underline;
            for (int i = 0; i < txt.length; i++) {
                dstring rest = txt[i..$];
                if (rest.startsWith(" Error"d)) {
                    cl = errorColor;
                    flags = 0;
                } else if (rest.startsWith(" Warning"d)) {
                    cl = warningColor;
                    flags = 0;
                } else if (rest.startsWith(" Deprecation"d)) {
                    cl = deprecationColor;
                    flags = 0;
                }
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        } else if (txt.startsWith("Building ")) {
            CustomCharProps[] colors = new CustomCharProps[txt.length];
            uint cl = defColor;
            for (int i = 0; i < txt.length; i++) {
                dstring rest = txt[i..$];
                if (i == 9) {
                    cl = filenameColor;
                    flags = TextFlag.Underline;
                } else if (rest.startsWith(" configuration"d)) {
                    cl = defColor;
                    flags = 0;
                }
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        }
        return null;
    }

	///
	override bool onMouseEvent(MouseEvent event) {

		if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
			super.onMouseEvent(event);

			auto logLine = this.content.line(this._caretPos.line);

			//src\tetris.d(49): Error: found 'return' when expecting ';' following statement

			auto match = matchFirst(logLine, ctr);

			if(!match.empty) {
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
