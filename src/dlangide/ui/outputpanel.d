module dlangide.ui.outputpanel;

import dlangui;
import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.ui.frame;
import dlangide.ui.terminal;

import std.utf;
import std.regex;
import std.algorithm : startsWith;
import std.string;

//static if (BACKEND_CONSOLE) {
//    enum ENABLE_INTERNAL_TERMINAL = true;
//} else {
    version (Windows) {
        enum ENABLE_INTERNAL_TERMINAL = false;
    } else {
        enum ENABLE_INTERNAL_TERMINAL = true;
    }
//}

enum ENABLE_INTERNAL_TERMINAL_TEST = false;

/// event listener to navigate by error/warning position
interface CompilerLogIssueClickHandler {
    bool onCompilerLogIssueClick(dstring filename, int line, int column);
}

class ErrorPosition {
    dstring filename;
    int line;
    int pos;
    this(dstring fn, int l, int p) {
        filename = fn;
        line = l;
        pos = p;
    }
}

/// Log widget with parsing of compiler output
class CompilerLogWidget : LogWidget {

    Signal!CompilerLogIssueClickHandler compilerLogIssueClickHandler;

    //auto ctr = ctRegex!(r"(.+)\((\d+)\): (Error|Warning|Deprecation): (.+)"d);
    auto ctr = ctRegex!(r"(.+)\((\d+)(?:,(\d+))?\): (Error|Warning|Deprecation): (.+)"d);

    /// forward to super c'tor
    this(string ID) {
        super(ID);
        //auto match2 = matchFirst("file.d(123,234): Error: bla bla"d, ctr2);
        //if (!match2.empty) {
        //    Log.d("found");
        //}
    }

    protected uint _filenameColor = 0x0000C0;
    protected uint _errorColor = 0xFF0000;
    protected uint _warningColor = 0x606000;
    protected uint _deprecationColor = 0x802040;

    /// handle theme change: e.g. reload some themed resources
    override void onThemeChanged() {
        super.onThemeChanged();
        _filenameColor = style.customColor("build_log_filename_color", 0x0000C0);
        _errorColor = style.customColor("build_log_error_color", 0xFF0000);
        _warningColor = style.customColor("build_log_warning_color", 0x606000);
        _deprecationColor = style.customColor("build_log_deprecation_color", 0x802040);
    }

    /** 
    Custom text color and style highlight (using text highlight) support.

    Return null if no syntax highlight required for line.
    */
    override protected CustomCharProps[] handleCustomLineHighlight(int line, dstring txt, ref CustomCharProps[] buf) {
        auto match = matchFirst(txt, ctr);
        uint defColor = textColor;
        uint flags = 0;
        if(!match.empty) {
            if (buf.length < txt.length)
                buf.length = txt.length;
            CustomCharProps[] colors = buf[0..txt.length];
            uint cl = _filenameColor;
            flags = TextFlag.Underline;
            for (int i = 0; i < txt.length; i++) {
                dstring rest = txt[i..$];
                if (rest.startsWith(" Error"d)) {
                    cl = _errorColor;
                    flags = 0;
                } else if (rest.startsWith(" Warning"d)) {
                    cl = _warningColor;
                    flags = 0;
                } else if (rest.startsWith(" Deprecation"d)) {
                    cl = _deprecationColor;
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
                    cl = _filenameColor;
                    flags = TextFlag.Underline;
                } else if (rest.startsWith(" configuration"d)) {
                    cl = defColor;
                    flags = 0;
                }
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        } else if ((txt.startsWith("Performing ") && txt.indexOf(" build using ") > 0)
                   || txt.startsWith("Upgrading project in ")
                   ) {
            CustomCharProps[] colors = new CustomCharProps[txt.length];
            uint cl = defColor;
            flags |= TextFlag.Underline;
            for (int i = 0; i < txt.length; i++) {
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        } else if (txt.indexOf(": building configuration ") > 0) {
            CustomCharProps[] colors = new CustomCharProps[txt.length];
            uint cl = _filenameColor;
            flags |= TextFlag.Underline;
            for (int i = 0; i < txt.length; i++) {
                dstring rest = txt[i..$];
                if (rest.startsWith(": building configuration "d)) {
                    //cl = defColor;
                    flags &= ~TextFlag.Underline;
                }
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        }
        return null;
    }

    ErrorPosition errorFromLine(int line) {
        if (line >= this.content.length || line < 0)
            return null; // invalid line number
        auto logLine = this.content.line(line);

        //src\tetris.d(49): Error: found 'return' when expecting ';' following statement

        auto match = matchFirst(logLine, ctr);

        if(!match.empty) {
            dstring filename = match[1];
            import std.conv:to;
            int row = to!int(match[2]) - 1;
            if (row < 0)
                row = 0;
            int col = 0;
            if (match[3] && match[3] != "") {
                col = to!int(match[3]) - 1;
                if (col < 0)
                    col = 0;
            }
            return new ErrorPosition(filename, row, col);
        }
        return null;
    }

    /// returns first error line info from log
    ErrorPosition firstError() {
        for (int i = 0; i < _content.length; i++) {
            ErrorPosition err = errorFromLine(i);
            if (err)
                return err;
        }
        return null;
    }

    ///
    override bool onMouseEvent(MouseEvent event) {

        if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
            super.onMouseEvent(event);

            auto errorPos = errorFromLine(_caretPos.line);
            if (errorPos) {
                if (compilerLogIssueClickHandler.assigned) {
                    compilerLogIssueClickHandler(errorPos.filename, errorPos.line, errorPos.pos);
                }
            }

            auto logLine = this.content.line(this._caretPos.line);

            //src\tetris.d(49): Error: found 'return' when expecting ';' following statement

            auto match = matchFirst(logLine, ctr);

            if(!match.empty) {
                if (compilerLogIssueClickHandler.assigned) {
                    import std.conv:to;
                    int row = to!int(match[2]) - 1;
                    if (row < 0)
                        row = 0;
                    int col = 0;
                    if (match[3]) {
                        col = to!int(match[3]) - 1;
                        if (col < 0)
                            col = 0;
                    }

                    compilerLogIssueClickHandler(match[1], row, col);
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
    protected TerminalWidget _terminalWidget;

    TabWidget _tabs;

    @property TabWidget getTabs() { return _tabs;}

    void activateLogTab() {
        _tabs.selectTab("logwidget");
    }

    void activateTerminalTab(bool clear = false) {
        static if (ENABLE_INTERNAL_TERMINAL) {
            _tabs.selectTab("TERMINAL");
            if (clear)
                _terminalWidget.resetTerminal();
        }
    }

    this(string id) {
        _showCloseButton = false;
        dockAlignment = DockAlignment.Bottom;
        super(id);
    }

    /// terminal device for Console tab
    @property string terminalDeviceName() {
        static if (ENABLE_INTERNAL_TERMINAL) {
            if (_terminalWidget)
                return _terminalWidget.deviceName;
        }
        return null;
    }

    ErrorPosition firstError() {
        if (_logWidget)
            return _logWidget.firstError();
        return null;
    }

    override protected Widget createBodyWidget() {
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _tabs = new TabWidget("OutputPanelTabs", Align.Bottom);
        //_tabs.setStyles(STYLE_DOCK_HOST_BODY, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT);
        _tabs.setStyles(STYLE_DOCK_WINDOW, STYLE_TAB_DOWN_DARK, STYLE_TAB_DOWN_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT, STYLE_DOCK_HOST_BODY);
        _tabs.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _tabs.tabHost.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        _logWidget = new CompilerLogWidget("logwidget");
        _logWidget.readOnly = true;
        _logWidget.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _logWidget.compilerLogIssueClickHandler = &onIssueClick;
        _logWidget.styleId = "EDIT_BOX_NO_FRAME";

        //_tabs.tabHost.styleId = STYLE_DOCK_WINDOW_BODY;
        _tabs.addTab(_logWidget, "Compiler Log"d);
        _tabs.selectTab("logwidget");

        static if (ENABLE_INTERNAL_TERMINAL) {
            _terminalWidget = new TerminalWidget("TERMINAL");
            _terminalWidget.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
            _tabs.addTab(_terminalWidget, "Output"d);
            _terminalWidget.write("Hello\nSecond line\nTest\n"d);
        }
        static if (ENABLE_INTERNAL_TERMINAL_TEST) {
            _terminalWidget.write("Hello\nSecond line\nTest\n"d);
            _terminalWidget.write("SomeString 123456789\rAwesomeString\n"d); // test \r
            // testing tabs
            _terminalWidget.write("id\tname\tdescription\n"d);
            _terminalWidget.write("1\tFoo\tFoo line\n"d);
            _terminalWidget.write("2\tBar\tBar line\n"d);
            _terminalWidget.write("3\tFoobar\tFoo bar line\n"d);
            _terminalWidget.write("\n\n\n"d);
            // testing line wrapping
            _terminalWidget.write("Testing very long line. Юникод. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n"c);
            // testing cursor position changes
            _terminalWidget.write("\x1b[4;4HCURSOR(4,4)\x1b[HHOME\x1b[B*A\x1b[B*B\x1b[5C\x1b[D***\x1b[A*UP\x1b[3B*DOWN"d);
            //_terminalWidget.write("\x1b[Jerased down"d);
            //_terminalWidget.write("\x1b[1Jerased up"d);
            //_terminalWidget.write("\x1b[2Jerased screen"d);
            //_terminalWidget.write("\x1b[Kerased eol"d);
            //_terminalWidget.write("\x1b[1Kerased bol"d);
            //_terminalWidget.write("\x1b[2Kerased line"d);
            //_terminalWidget.write("Юникод Unicode"d);
            _terminalWidget.write("\x1b[34;45m blue on magenta "d);
            _terminalWidget.write("\x1b[31;46m red on cyan "d);
            //_terminalWidget.write("\x1b[2Jerased screen"d);
            //TerminalDevice term = new TerminalDevice();
            //if (!term.create()) {
            //    Log.e("Cannot create terminal device");
            //}
            _terminalWidget.write("\n\n\n\nDevice: "d ~ toUTF32(_terminalWidget.deviceName));
            _terminalWidget.write("\x1b[0m\nnormal text\n"d);
        }
        return _tabs;
    }

    override protected void initialize() {
        
        //styleId = STYLE_DOCK_WINDOW;
        styleId = null;
        _bodyWidget = createBodyWidget();
        //_bodyWidget.styleId = STYLE_DOCK_WINDOW_BODY;
        addChild(_bodyWidget);
    }

    //TODO: Refactor OutputPanel to expose CompilerLogWidget

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
