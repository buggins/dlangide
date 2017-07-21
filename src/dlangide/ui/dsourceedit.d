module dlangide.ui.dsourceedit;

import dlangui.core.logger;
import dlangui.core.signals;
import dlangui.graphics.drawbuf;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;
import dlangui.widgets.menu;
import dlangui.widgets.popup;
import dlangui.widgets.controls;
import dlangui.widgets.scroll;
import dlangui.dml.dmlhighlight;

import ddc.lexer.textsource;
import ddc.lexer.exceptions;
import ddc.lexer.tokenizer;

import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.ui.commands;
import dlangide.ui.settings;
import dlangide.tools.d.dsyntax;
import dlangide.tools.editorTool;
import ddebug.common.debugger;

import std.algorithm;
import std.utf : toUTF32;
import std.utf : toUTF8;

interface BreakpointListChangeListener {
    void onBreakpointListChanged(ProjectSourceFile sourceFile, Breakpoint[] breakpoints);
}

interface BookmarkListChangeListener {
    void onBookmarkListChanged(ProjectSourceFile sourceFile, EditorBookmark[] bookmarks);
}

/// DIDE source file editor
class DSourceEdit : SourceEdit, EditableContentMarksChangeListener {
    this(string ID) {
        super(ID);
        static if (BACKEND_GUI) {
            styleId = null;
            backgroundColor = style.customColor("edit_background");
        }
        onThemeChanged();
        //setTokenHightlightColor(TokenCategory.Identifier, 0x206000);  // no colors
        MenuItem editPopupItem = new MenuItem(null);
        editPopupItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_EDIT_UNDO, 
                          ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT,
                          ACTION_GET_COMPLETIONS, ACTION_GO_TO_DEFINITION, ACTION_DEBUG_TOGGLE_BREAKPOINT);
        popupMenu = editPopupItem;
        showIcons = true;
        //showFolding = true;
        showWhiteSpaceMarks = true;
        showTabPositionMarks = true;
        content.marksChanged = this;
    }

    this() {
        this("SRCEDIT");
    }

    ~this() {
        if (_editorTool) {
            destroy(_editorTool);
            _editorTool = null;
        }
    }

    Signal!BreakpointListChangeListener breakpointListChanged;
    Signal!BookmarkListChangeListener bookmarkListChanged;

    /// handle theme change: e.g. reload some themed resources
    override void onThemeChanged() {
        static if (BACKEND_GUI) backgroundColor = style.customColor("edit_background");
        setTokenHightlightColor(TokenCategory.Comment, style.customColor("syntax_highlight_comment")); // green
        setTokenHightlightColor(TokenCategory.Keyword, style.customColor("syntax_highlight_keyword")); // blue
        setTokenHightlightColor(TokenCategory.Integer, style.customColor("syntax_highlight_integer", 0x000000));
        setTokenHightlightColor(TokenCategory.Float, style.customColor("syntax_highlight_float", 0x000000));
        setTokenHightlightColor(TokenCategory.String, style.customColor("syntax_highlight_string"));  // brown
        setTokenHightlightColor(TokenCategory.Identifier, style.customColor("syntax_highlight_ident"));
        setTokenHightlightColor(TokenCategory.Character, style.customColor("syntax_highlight_character"));  // brown
        setTokenHightlightColor(TokenCategory.Error, style.customColor("syntax_highlight_error"));  // red
        setTokenHightlightColor(TokenCategory.Comment_Documentation, style.customColor("syntax_highlight_comment_documentation"));

        super.onThemeChanged();
    }

    protected IDESettings _settings;
    @property DSourceEdit settings(IDESettings s) {
        _settings = s;
        return this;
    }
    @property IDESettings settings() {
        return _settings;
    }
    void applySettings() {
        if (!_settings)
            return;
        tabSize = _settings.tabSize;
        useSpacesForTabs = _settings.useSpacesForTabs;
        smartIndents = _settings.smartIndents;
        smartIndentsAfterPaste = _settings.smartIndentsAfterPaste;
        showWhiteSpaceMarks = _settings.showWhiteSpaceMarks;
        showTabPositionMarks = _settings.showTabPositionMarks;
        string face = _settings.editorFontFace;
        if (face == "Default")
            face = null;
        else if (face)
            face ~= ",";
        face ~= DEFAULT_SOURCE_EDIT_FONT_FACES;
        fontFace = face;
    }

    protected EditorTool _editorTool;
    @property EditorTool editorTool() { return _editorTool; }
    @property EditorTool editorTool(EditorTool tool) { 
        if (_editorTool && _editorTool !is tool) {
            destroy(_editorTool);
            _editorTool = null;
        }
        return _editorTool = tool; 
    };

    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile projectSourceFile() { return _projectSourceFile; }
    /// load by filename
    override bool load(string fn) {
        _projectSourceFile = null;
        bool res = super.load(fn);
        setSyntaxSupport();
        return res;
    }

    @property bool isDSourceFile() {
        return filename.endsWith(".d") || filename.endsWith(".dd") || filename.endsWith(".dd") ||
               filename.endsWith(".di") || filename.endsWith(".dh") || filename.endsWith(".ddoc");
    }

    @property bool isJsonFile() {
        return filename.endsWith(".json") || filename.endsWith(".JSON");
    }

    @property bool isDMLFile() {
        return filename.endsWith(".dml") || filename.endsWith(".DML");
    }

    @property bool isXMLFile() {
        return filename.endsWith(".xml") || filename.endsWith(".XML");
    }

    override protected MenuItem getLeftPaneIconsPopupMenu(int line) {
        MenuItem menu = super.getLeftPaneIconsPopupMenu(line);
        if (isDSourceFile) {
            Action action = ACTION_DEBUG_TOGGLE_BREAKPOINT.clone();
            action.longParam = line;
            action.objectParam = this;
            menu.add(action);
            action = ACTION_DEBUG_ENABLE_BREAKPOINT.clone();
            action.longParam = line;
            action.objectParam = this;
            menu.add(action);
            action = ACTION_DEBUG_DISABLE_BREAKPOINT.clone();
            action.longParam = line;
            action.objectParam = this;
            menu.add(action);
        }
        return menu;
    }

    uint _executionLineHighlightColor = BACKEND_GUI ? 0x808080FF : 0x000080;
    int _executionLine = -1;
    @property int executionLine() { return _executionLine; }
    @property void executionLine(int line) {
        if (line == _executionLine)
            return;
        _executionLine = line;
        if (_executionLine >= 0) {
            setCaretPos(_executionLine, 0, true);
        }
        invalidate();
    }
    /// override to custom highlight of line background
    override protected void drawLineBackground(DrawBuf buf, int lineIndex, Rect lineRect, Rect visibleRect) {
        if (lineIndex == _executionLine) {
            buf.fillRect(visibleRect, _executionLineHighlightColor);
        }
        super.drawLineBackground(buf, lineIndex, lineRect, visibleRect);
    }

    void setSyntaxSupport() {
        if (isDSourceFile) {
            content.syntaxSupport = new SimpleDSyntaxSupport(filename);
        } else if (isJsonFile) {
            content.syntaxSupport = new DMLSyntaxSupport(filename);
        } else if (isDMLFile) {
            content.syntaxSupport = new DMLSyntaxSupport(filename);
        } else {
            content.syntaxSupport = null;
        }
    }

    /// returns project import paths - if file from project is opened in current editor
    string[] importPaths() {
        if (_projectSourceFile)
            return _projectSourceFile.project.importPaths;
        return null;
    }

    /// load by project item
    bool load(ProjectSourceFile f) {
        if (!load(f.filename)) {
            _projectSourceFile = null;
            return false;
        }
        _projectSourceFile = f;
        setSyntaxSupport();
        return true;
    }

    /// save to the same file
    bool save() {
        return _content.save();
    }

    void insertCompletion(dstring completionText) {
        TextRange range;
        TextPosition p = caretPos;
        range.start = range.end = p;
        dstring lineText = content.line(p.line);
        dchar prevChar = p.pos > 0 ? lineText[p.pos - 1] : 0;
        dchar nextChar = p.pos < lineText.length ? lineText[p.pos] : 0;
        if (isIdentMiddleChar(prevChar)) {
            while(range.start.pos > 0 && isIdentMiddleChar(lineText[range.start.pos - 1]))
                range.start.pos--;
            if (isIdentMiddleChar(nextChar)) {
                while(range.end.pos < lineText.length && isIdentMiddleChar(lineText[range.end.pos]))
                    range.end.pos++;
            }
        }
        EditOperation edit = new EditOperation(EditAction.Replace, range, completionText);
        _content.performOperation(edit, this);
        setFocus();
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        import ddc.lexer.tokenizer;
        if (a) {
            switch (a.id) {
                case IDEActions.FileSave:
                    save();
                    return true;
                case IDEActions.InsertCompletion:
                    insertCompletion(a.label);
                    return true;
                case IDEActions.DebugToggleBreakpoint:
                case IDEActions.DebugEnableBreakpoint:
                case IDEActions.DebugDisableBreakpoint:
                    handleBreakpointAction(a);
                    return true;
                case EditorActions.ToggleBookmark:
                    super.handleAction(a);
                    notifyBookmarkListChanged();
                    return true;
                default:
                    break;
            }
        }
        return super.handleAction(a);
    }

    /// Handle Ctrl + Left mouse click on text
    override protected void onControlClick() {
        window.dispatchAction(ACTION_GO_TO_DEFINITION);
    }


    /// left button click on icons panel: toggle breakpoint
    override protected bool handleLeftPaneIconsMouseClick(MouseEvent event, Rect rc, int line) {
        if (event.button == MouseButton.Left) {
            LineIcon icon = content.lineIcons.findByLineAndType(line, LineIconType.breakpoint);
            if (icon)
                removeBreakpoint(line, icon);
            else
                addBreakpoint(line);
            return true;
        }
        return super.handleLeftPaneIconsMouseClick(event, rc, line);
    }

    protected void addBreakpoint(int line) {
        import std.path;
        Breakpoint bp = new Breakpoint();
        bp.file = baseName(filename);
        bp.line = line + 1;
        bp.fullFilePath = filename;
        if (projectSourceFile) {
            bp.projectName = toUTF8(projectSourceFile.project.name);
            bp.projectFilePath = projectSourceFile.project.absoluteToRelativePath(filename);
        }
        LineIcon icon = new LineIcon(LineIconType.breakpoint, line, bp);
        content.lineIcons.add(icon);
        notifyBreakpointListChanged();
    }

    protected void removeBreakpoint(int line, LineIcon icon) {
        content.lineIcons.remove(icon);
        notifyBreakpointListChanged();
    }

    void setBreakpointList(Breakpoint[] breakpoints) {
        // remove all existing breakpoints
        content.lineIcons.removeByType(LineIconType.breakpoint);
        // add new breakpoints
        foreach(bp; breakpoints) {
            LineIcon icon = new LineIcon(LineIconType.breakpoint, bp.line - 1, bp);
            content.lineIcons.add(icon);
        }
    }

    Breakpoint[] getBreakpointList() {
        LineIcon[] icons = content.lineIcons.findByType(LineIconType.breakpoint);
        Breakpoint[] breakpoints;
        foreach(icon; icons) {
            Breakpoint bp = cast(Breakpoint)icon.objectParam;
            if (bp)
                breakpoints ~= bp;
        }
        return breakpoints;
    }

    void setBookmarkList(EditorBookmark[] bookmarks) {
        // remove all existing breakpoints
        content.lineIcons.removeByType(LineIconType.bookmark);
        // add new breakpoints
        foreach(bp; bookmarks) {
            LineIcon icon = new LineIcon(LineIconType.bookmark, bp.line - 1);
            content.lineIcons.add(icon);
        }
    }

    EditorBookmark[] getBookmarkList() {
        import std.path;
        LineIcon[] icons = content.lineIcons.findByType(LineIconType.bookmark);
        EditorBookmark[] bookmarks;
        if (projectSourceFile) {
            foreach(icon; icons) {
                EditorBookmark bp = new EditorBookmark();
                bp.line = icon.line + 1;
                bp.file = baseName(filename);
                bp.projectName = projectSourceFile.project.name8;
                bp.fullFilePath = filename;
                bp.projectFilePath = projectSourceFile.project.absoluteToRelativePath(filename);
                bookmarks ~= bp;
            }
        }
        return bookmarks;
    }

    protected void onMarksChange(EditableContent content, LineIcon[] movedMarks, LineIcon[] removedMarks) {
        bool changed = false;
        bool bookmarkChanged = false;
        foreach(moved; movedMarks) {
            if (moved.type == LineIconType.breakpoint) {
                Breakpoint bp = cast(Breakpoint)moved.objectParam;
                if (bp) {
                    // update Breakpoint line
                    bp.line = moved.line + 1;
                    changed = true;
                }
            } else if (moved.type == LineIconType.bookmark) {
                EditorBookmark bp = cast(EditorBookmark)moved.objectParam;
                if (bp) {
                    // update Breakpoint line
                    bp.line = moved.line + 1;
                    bookmarkChanged = true;
                }
            }
        }
        foreach(removed; removedMarks) {
            if (removed.type == LineIconType.breakpoint) {
                Breakpoint bp = cast(Breakpoint)removed.objectParam;
                if (bp) {
                    changed = true;
                }
            } else if (removed.type == LineIconType.bookmark) {
                EditorBookmark bp = cast(EditorBookmark)removed.objectParam;
                if (bp) {
                    bookmarkChanged = true;
                }
            }
        }
        if (changed)
            notifyBreakpointListChanged();
        if (bookmarkChanged)
            notifyBookmarkListChanged();
    }

    protected void notifyBreakpointListChanged() {
        if (projectSourceFile) {
            if (breakpointListChanged.assigned)
                breakpointListChanged(projectSourceFile, getBreakpointList());
        }
    }

    protected void notifyBookmarkListChanged() {
        if (projectSourceFile) {
            if (bookmarkListChanged.assigned)
                bookmarkListChanged(projectSourceFile, getBookmarkList());
        }
    }

    protected void handleBreakpointAction(const Action a) {
        int line = a.longParam >= 0 ? cast(int)a.longParam : caretPos.line;
        LineIcon icon = content.lineIcons.findByLineAndType(line, LineIconType.breakpoint);
        switch(a.id) {
            case IDEActions.DebugToggleBreakpoint:
                if (icon)
                    removeBreakpoint(line, icon);
                else
                    addBreakpoint(line);
                break;
            case IDEActions.DebugEnableBreakpoint:
                break;
            case IDEActions.DebugDisableBreakpoint:
                break;
            default:
                break;
        }
    }

    /// override to handle specific actions state (e.g. change enabled state for supported actions)
    override bool handleActionStateRequest(const Action a) {
        switch (a.id) {
            case IDEActions.GoToDefinition:
            case IDEActions.GetCompletionSuggestions:
            case IDEActions.GetDocComments:
            case IDEActions.GetParenCompletion:
            case IDEActions.DebugToggleBreakpoint:
            case IDEActions.DebugEnableBreakpoint:
            case IDEActions.DebugDisableBreakpoint:
                if (isDSourceFile)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            default:
                return super.handleActionStateRequest(a);
        }
    }

    /// override to handle mouse hover timeout in text
    override protected void onHoverTimeout(Point pt, TextPosition pos) {
        // override to do something useful on hover timeout
        Log.d("onHoverTimeout ", pos);
        if (!isDSourceFile)
            return;
        editorTool.getDocComments(this, pos, delegate(string[]results) {
            showDocCommentsPopup(results, pt);
        });
    }

    PopupWidget _docsPopup;
    void showDocCommentsPopup(string[] comments, Point pt = Point(-1, -1)) {
        if (comments.length == 0)
            return;
        if (pt.x < 0 || pt.y < 0) {
            pt = textPosToClient(_caretPos).topLeft;
            pt.x += left + _leftPaneWidth;
            pt.y += top;
        }
        dchar[] text;
        int lineCount = 0;
        foreach(s; comments) {
            int lineStart = 0;
            for (int i = 0; i <= s.length; i++) {
                if (i == s.length || (i < s.length - 1 && s[i] == '\\' && s[i + 1] == 'n')) {
                    if (i > lineStart) {
                        if (text.length)
                            text ~= "\n"d;
                        text ~= toUTF32(s[lineStart .. i]);
                        lineCount++;
                    }
                    if (i < s.length)
                        i++;
                    lineStart = i + 1;
                }
            }
        }
        if (lineCount > _numVisibleLines / 4)
            lineCount = _numVisibleLines / 4;
        if (lineCount < 1)
            lineCount = 1;
        // TODO
        EditBox widget = new EditBox("docComments");
        widget.readOnly = true;
        //TextWidget widget = new TextWidget("docComments");
        //widget.maxLines = lineCount * 2;
        //widget.text = "Test popup"d; //text.dup;
        widget.text = text.dup;
        //widget.layoutHeight = lineCount * widget.fontSize;
        widget.minHeight = (lineCount + 1) * widget.fontSize;
        widget.maxWidth = width * 3 / 4;
        widget.minWidth = width / 8;
       // widget.layoutWidth = width / 3;
        widget.styleId = "POPUP_MENU";
        widget.hscrollbarMode = ScrollBarMode.Auto;
        widget.vscrollbarMode = ScrollBarMode.Auto;
        uint pos = PopupAlign.Above;
        if (pt.y < top + height / 4)
            pos = PopupAlign.Below;
        if (_docsPopup) {
            _docsPopup.close();
            _docsPopup = null;
        }
        _docsPopup = window.showPopup(widget, this, PopupAlign.Point | pos, pt.x, pt.y);
        //popup.setFocus();
        _docsPopup.popupClosed = delegate(PopupWidget source) {
            Log.d("Closed Docs popup");
            _docsPopup = null;
            //setFocus(); 
        };
        _docsPopup.flags = PopupFlags.CloseOnClickOutside | PopupFlags.CloseOnMouseMoveOutside;
        invalidate();
        window.update();
    }

    protected CompletionPopupMenu _completionPopupMenu;
    protected PopupWidget _completionPopup;

    dstring identPrefixUnderCursor() {
        dstring line = _content[_caretPos.line];
        if (_caretPos.pos > line.length)
            return null;
        int end = _caretPos.pos;
        int start = end;
        while (start >= 0) {
            dchar prevChar = start > 0 ? line[start - 1] : 0;
            if (!isIdentChar(prevChar))
                break;
            start--;
        }
        if (start >= end)
            return null;
        return line[start .. end].dup;
    }

    void closeCompletionPopup(CompletionPopupMenu completion) {
        if (!_completionPopup || _completionPopupMenu !is completion)
            return;
        _completionPopup.close();
        _completionPopup = null;
        _completionPopupMenu = null;
    }

    void showCompletionPopup(dstring[] suggestions, string[] icons) {

        if(suggestions.length == 0) {
            setFocus();
            return;
        }

        if (suggestions.length == 1) {
            insertCompletion(suggestions[0]);
            return;
        }

        dstring prefix = identPrefixUnderCursor();
        _completionPopupMenu = new CompletionPopupMenu(this, suggestions, icons, prefix);
        int yOffset = font.height;
        _completionPopup = window.showPopup(_completionPopupMenu, this, PopupAlign.Point | PopupAlign.Right,
                                             textPosToClient(_caretPos).left + left + _leftPaneWidth,
                                             textPosToClient(_caretPos).top + top + margins.top + yOffset);
        _completionPopup.setFocus();
        _completionPopup.popupClosed = delegate(PopupWidget source) { 
            setFocus();
            _completionPopup = null;
        };
        _completionPopup.flags = PopupFlags.CloseOnClickOutside;

        Log.d("Showing popup at ", textPosToClient(_caretPos).left, " ", textPosToClient(_caretPos).top);
        window.update();
    }

    protected ulong _completionTimerId;
    protected enum COMPLETION_TIMER_MS = 700;
    protected void startCompletionTimer() {
        if (_completionTimerId) {
            cancelTimer(_completionTimerId);
        }
        _completionTimerId = setTimer(COMPLETION_TIMER_MS);
    }
    protected void cancelCompletionTimer() {
        if (_completionTimerId) {
            cancelTimer(_completionTimerId);
            _completionTimerId = 0;
        }
    }
    /// handle timer; return true to repeat timer event after next interval, false cancel timer
    override bool onTimer(ulong id) {
        if (id == _completionTimerId) {
            _completionTimerId = 0;
            if (!_completionPopup)
                window.dispatchAction(ACTION_GET_COMPLETIONS, this);
        }
        return super.onTimer(id);
    }

    /// override to handle focus changes
    override protected void handleFocusChange(bool focused, bool receivedFocusFromKeyboard = false) {
        if (!focused)
            cancelCompletionTimer();
        super.handleFocusChange(focused, receivedFocusFromKeyboard);
    }

    protected uint _lastKeyDownCode;
    protected uint _periodKeyCode;
    /// handle keys: support autocompletion after . press with delay
    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.KeyDown)
            _lastKeyDownCode = event.keyCode;
        if (event.action == KeyAction.Text && event.noModifiers && event.text==".") {
            _periodKeyCode = _lastKeyDownCode;
            startCompletionTimer();
        } else {
            if (event.action == KeyAction.KeyUp && (event.text == "." || event.keyCode == KeyCode.KEY_PERIOD || event.keyCode == _periodKeyCode)) {
                // keep completion timer
            } else {
                // cancel completion timer
                cancelCompletionTimer();
            }
        }
        return super.onKeyEvent(event);
    }

}

/// returns true if character is valid ident character
bool isIdentChar(dchar ch) {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_';
}

/// returns true if all characters are valid ident chars
bool isIdentText(dstring s) {
    foreach(ch; s)
        if (!isIdentChar(ch))
            return false;
    return true;
}

class CompletionPopupMenu : PopupMenu {
    protected dstring _initialPrefix;
    protected dstring _prefix;
    protected dstring[] _suggestions;
    protected string[] _icons;
    protected MenuItem _items;
    protected DSourceEdit _editor;
    this(DSourceEdit editor, dstring[] suggestions, string[] icons, dstring initialPrefix) {
        _initialPrefix = initialPrefix;
        _prefix = initialPrefix.dup;
        _editor = editor;
        _suggestions = suggestions;
        _icons = icons;
        _items = updateItems();
        super(_items);
        menuItemAction = _editor;
        maxHeight(400);
        selectItem(0);
    }
    MenuItem updateItems() {
        MenuItem res = new MenuItem();
        foreach(int i, dstring suggestion ; _suggestions) {
            if (_prefix.length && !suggestion.startsWith(_prefix))
                continue;
            string iconId;
            if (i < _icons.length)
                iconId = _icons[i];
            auto action = new Action(IDEActions.InsertCompletion, suggestion);
            action.iconId = iconId;
            res.add(action);
        }
        res.updateActionState(_editor);
        return res;
    }
    /// handle keys
    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.Text) {
            _prefix ~= event.text;
            MenuItem newItems = updateItems();
            if (newItems.subitemCount == 0) {
                // no matches anymore
                _editor.onKeyEvent(event);
                _editor.closeCompletionPopup(this);
                return true;
            } else {
                _editor.onKeyEvent(event);
                menuItems = newItems;
                selectItem(0);
                return true;
            }
        } else if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.BACK && event.noModifiers) {
            if (_prefix.length > _initialPrefix.length) {
                _prefix.length = _prefix.length - 1;
                MenuItem newItems = updateItems();
                _editor.onKeyEvent(event);
                menuItems = newItems;
                selectItem(0);
            } else {
                _editor.onKeyEvent(event);
                _editor.closeCompletionPopup(this);
            }
            return true;
        } else if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.RETURN) {
        } else if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.SPACE) {
        }
        return super.onKeyEvent(event);
    }
}
