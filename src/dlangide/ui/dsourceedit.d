module dlangide.ui.dsourceedit;

import dlangui.core.logger;
import dlangui.core.signals;
import dlangui.graphics.drawbuf;
import dlangui.widgets.widget;
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
import dlangide.tools.editortool;
import ddebug.common.debugger;

import std.algorithm;
import std.utf : toUTF32;
import dlangui.core.types : toUTF8;

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
        _hscrollbarMode = ScrollBarMode.Auto;
        _vscrollbarMode = ScrollBarMode.Auto;
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
    protected int _previousFontSizeSetting;
    void applySettings() {
        if (!_settings)
            return;
        tabSize = _settings.tabSize;
        useSpacesForTabs = _settings.useSpacesForTabs;
        smartIndents = _settings.smartIndents;
        smartIndentsAfterPaste = _settings.smartIndentsAfterPaste;
        showWhiteSpaceMarks = _settings.showWhiteSpaceMarks;
        showTabPositionMarks = _settings.showTabPositionMarks;
        externalChangeMode = _settings.externalChangeMode;
        _content.atomicSave = _settings.atomicSave;
        string face = _settings.editorFontFace;
        if (face == "Default")
            face = null;
        else if (face)
            face ~= ",";
        face ~= DEFAULT_SOURCE_EDIT_FONT_FACES;
        fontFace = face;
        int newFontSizeSetting = _settings.editorFontSize;
        bool needChangeFontSize = _previousFontSizeSetting == 0 || (_previousFontSizeSetting != newFontSizeSetting && _previousFontSizeSetting.pointsToPixels == fontSize);
        if (needChangeFontSize) {
            fontSize = newFontSizeSetting.pointsToPixels;
            _previousFontSizeSetting = newFontSizeSetting;
        }
    }

    protected EditorTool _editorTool;
    @property EditorTool editorTool() { return _editorTool; }
    @property EditorTool editorTool(EditorTool tool) {
        if (_editorTool && _editorTool !is tool) {
            destroy(_editorTool);
            _editorTool = null;
        }
        return _editorTool = tool;
    }

    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile projectSourceFile() { return _projectSourceFile; }
    @property void projectSourceFile(ProjectSourceFile v) { _projectSourceFile = v; }
    /// load by filename
    override bool load(string fn) {
        _projectSourceFile = null;
        bool res = super.load(fn);
        if (res)
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
    string[] importPaths(IDESettings ideSettings) {
        if (_projectSourceFile)
            return _projectSourceFile.project.importPaths(ideSettings);
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

    /// save to the same file; shows an error message if it fails
    bool save() {
        return reportSaveResult(_content.save(), filename);
    }

    /// runs when the save question is answered and nothing is left to save (see saveChecked)
    protected void delegate() _afterSaveQuestion;

    /**
    Saves the text to its file after a check for changes by other programs (File > Save, Save all, Save when
    closing): if the file was changed since it was loaded, the editor asks first (Overwrite / Reload / Cancel) and
    false is returned; a failed save shows an error message. afterSaveQuestion, if set, runs (posted to the UI
    thread) when the user answers the question with Overwrite (and the text is saved) or Reload, e.g. to go on
    closing; it is dropped if the text is changed before that.
    */
    bool saveChecked(void delegate() afterSaveQuestion = null) {
        _afterSaveQuestion = null; // a new save request replaces an unanswered one
        if (!checkBeforeSave()) {
            _afterSaveQuestion = afterSaveQuestion;
            return false;
        }
        return save();
    }

    override protected bool handleExternalChangeAction(const Action action) {
        void delegate() afterSaveQuestion = _afterSaveQuestion;
        _afterSaveQuestion = null; // any answer ends the pending save request
        bool question = _externalChangeShown == ExternalChangeReaction.confirmSave;
        bool handled = super.handleExternalChangeAction(action);
        // Overwrite saved the text, or Reload replaced it with the file: nothing is left to save; posted, because it
        // may close this editor, whose message bar is still handling the click
        if (question && afterSaveQuestion && !_content.modified && window
                && (action.id == EditorActions.SaveFile || action.id == EditorActions.ReloadFile))
            window.executeInUiThread(afterSaveQuestion);
        return handled;
    }

    /// called when the "file deleted" message appears for text with unsaved changes
    void delegate(DSourceEdit editor) deletedFileKeptOpen;

    override protected void applyExternalChangeReaction(ExternalChangeReaction reaction) {
        bool shown = findMessage(EXTERNAL_CHANGE_MESSAGE_ID) !is null;
        bool newDeletedMessage = reaction == ExternalChangeReaction.notifyDeleted && _content.modified
            && !(shown && _externalChangeShown == ExternalChangeReaction.notifyDeleted);
        super.applyExternalChangeReaction(reaction);
        // the save question was replaced (the file changed again while it was shown): a pending close is cancelled,
        // the new message needs its own answer
        if (_externalChangeShown != ExternalChangeReaction.confirmSave)
            _afterSaveQuestion = null;
        if (newDeletedMessage && deletedFileKeptOpen)
            deletedFileKeptOpen(this);
    }

    /// Save and Overwrite on the external change message: SourceEdit's save(fn), so the failure is shown by the
    /// message bar only (this class's save(fn) would also show a message box)
    override protected bool saveAfterExternalChange() {
        return super.save(filename.length ? filename : _content.filename);
    }

    /// a change of the text drops a pending save request (see saveChecked)
    override void onContentChange(EditableContent content, EditOperation operation, ref TextRange rangeBefore,
            ref TextRange rangeAfter, Object source) {
        _afterSaveQuestion = null;
        super.onContentChange(content, operation, rangeBefore, rangeAfter, source);
    }

    /// the file was deleted: Save / Keep, and Close (closes the tab, asking about unsaved changes as usual)
    override protected const(Action)[] externalChangeActions(ExternalChangeReaction reaction) {
        const(Action)[] actions = super.externalChangeActions(reaction);
        if (reaction == ExternalChangeReaction.notifyDeleted)
            actions ~= ACTION_CLOSE_DELETED_FILE;
        return actions;
    }

    /// save to file fn; shows an error message if it fails
    override bool save(string fn) {
        return reportSaveResult(super.save(fn), fn);
    }

    /// shows an error message for a failed save (e.g. a full disk or a read-only file; #212); returns ok
    protected bool reportSaveResult(bool ok, string fn) {
        import std.path : baseName;
        if (!ok && window)
            window.showMessageBox(UIString.fromId("ERROR_CANNOT_SAVE_FILE"c) ~ " " ~ toUTF32(baseName(fn)),
                    UIString.fromRaw(toUTF32(fn) ~ "\n\n"d ~ UIString.fromId("MSG_SAVE_FAILED"c).value));
        return ok;
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
                    saveChecked(); // asks if the file was changed on disk; shows an error message if saving fails
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
            case IDEActions.FileSaveAs:
                a.state = ACTION_STATE_ENABLED;
                return true;
            case IDEActions.FileSave:
                if (_content.modified)
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

    /// returns widget visibility (Visible, Invisible, Gone)
    override @property Visibility visibility() { return super.visibility; }
    /// sets widget visibility (Visible, Invisible, Gone)
    override @property Widget visibility(Visibility visible) {
        super.visibility(visible);
        if (visible != Visibility.Visible)
            cancelEditorToolTasks();
        return this;
    }

    void cancelEditorToolTasks() {
        if (editorTool) {
            editorTool.cancelGoToDefinition();
            editorTool.cancelGetDocComments();
            editorTool.cancelGetCompletions();
        }
    }

    PopupWidget _docsPopup;
    /// close doc comments / call tips popup if shown
    void closeDocsPopup() {
        if (_docsPopup) {
            _docsPopup.close();
            _docsPopup = null;
        }
    }
    void showDocCommentsPopup(string[] comments, Point pt = Point(-1, -1)) {
        if (!visible)
            return;
        if (comments.length == 0)
            return;
        if (pt.x < 0 || pt.y < 0) {
            pt = textPosToClient(_caretPos).topLeft;
            pt.x += left + _leftPaneWidth;
            pt.y += top;
        }
        // one doc comment per matching symbol (e.g. overloads), separated by an empty line
        dchar[] text;
        foreach(s; comments) {
            if (text.length)
                text ~= "\n\n"d;
            text ~= toUTF32(s);
        }
        // TODO
        EditBox widget = new EditBox("docComments");
        widget.styleId = "DOC_POPUP";
        widget.readOnly = true;
        //TextWidget widget = new TextWidget("docComments");
        //widget.maxLines = lineCount * 2;
        //widget.text = "Test popup"d; //text.dup;
        widget.text = text.dup;

        widget.hscrollbarMode = ScrollBarMode.Invisible;
        widget.vscrollbarMode = ScrollBarMode.Invisible;
        Point bestSize = widget.fullContentSizeWithBorders();
        bestSize.x += 5.pointsToPixels;
        //bestSize.y += 8.pointsToPixels;
        //widget.layoutHeight = lineCount * widget.fontSize;
        if (bestSize.y > height / 3) {
            bestSize.y = height / 3;
            bestSize.x += 30.pointsToPixels;
            widget.vscrollbarMode = ScrollBarMode.Visible;
        }
        if (bestSize.x > width * 3 / 4) {
            bestSize.x = width * 3 / 4;
            bestSize.y += 30.pointsToPixels;
            widget.hscrollbarMode = ScrollBarMode.Visible;
        }
        widget.minHeight = bestSize.y; //max((lineCount + 1) * widget.fontSize, bestSize.y);
        widget.maxHeight = bestSize.y;

        widget.maxWidth = bestSize.x; //width * 3 / 4;
        widget.minWidth = bestSize.x; //width / 8;
       // widget.layoutWidth = width / 3;
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

    void showCallTipsPopup(dstring[] suggestions) {
        // TODO: replace this temp solution
        string[] list;
        foreach(s; suggestions) {
            list ~= s.toUTF8;
        }
        showDocCommentsPopup(list);
    }

    void showCompletionPopup(dstring[] suggestions, string[] icons, CompletionTypes type) {

        if(suggestions.length == 0) {
            setFocus();
            return;
        }

        if (type == CompletionTypes.CallTips) {
            showCallTipsPopup(suggestions);
            return;
        }

        // Only insert singular autocompletion if automatic autocomplete is turned off!
        if (!_settings.autoAutoComplete && suggestions.length == 1) {
            insertCompletion(suggestions[0]);
            return;
        }

        dstring prefix = identPrefixUnderCursor();
        _completionPopupMenu = new CompletionPopupMenu(this, suggestions, icons, prefix);

        int yOffset = font.height;
        int popupPositionX = textPosToClient(_caretPos).left + left + _leftPaneWidth;
        int popupPositionY = textPosToClient(_caretPos).top + top + margins.top;
        uint popupAlign = PopupAlign.Point | PopupAlign.Right;
        int spaceBelow = window.mainWidget.pos.bottom - (popupPositionY + yOffset);
        int spaceAbove = popupPositionY - clientRect.top;
        int space = spaceBelow;
        if (spaceBelow < clientRect.height / 4) {
            // show popup above
            space = spaceAbove;
            popupAlign |= PopupAlign.Above;
            yOffset = 0;
        }
        Point bestSize = _completionPopupMenu.fullContentSizeWithBorders();
        if (bestSize.y > space) {
            bestSize.y = space;
            // the items scroll: the vertical scrollbar takes part of the width, which cut off the longest names (#579)
            bestSize.x += _completionPopupMenu.scrollbarWidth;
        }
        if (bestSize.x > width * 3 / 4) {
            bestSize.x = width * 3 / 4;
        }
        _completionPopupMenu.minHeight = bestSize.y; //max((lineCount + 1) * widget.fontSize, bestSize.y);
        _completionPopupMenu.maxHeight = bestSize.y;

        _completionPopupMenu.maxWidth = bestSize.x; //width * 3 / 4;
        _completionPopupMenu.minWidth = bestSize.x; //width / 8;


        _completionPopup = window.showPopup(_completionPopupMenu, this, popupAlign,
                                             popupPositionX,
                                             popupPositionY + yOffset);
        _completionPopup.setFocus();
        _completionPopup.popupClosed = delegate(PopupWidget source) {
            setFocus();
            if (source is _completionPopup) {
                _completionPopup = null;
                _completionPopupMenu = null; // destroyed with the popup
            }
        };
        _completionPopup.flags = PopupFlags.CloseOnClickOutside;

        debug Log.d("Showing popup at ", textPosToClient(_caretPos).left, " ", textPosToClient(_caretPos).top);
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

    /// true if the text before the caret is something to complete: an identifier or '.', not in a comment or a
    /// string and not a number (#603); completions after Backspace only then, not after deleting spaces, brackets
    /// or a line break
    private bool isCompletionContextBeforeCaret() {
        TextPosition p = caretPos;
        if (p.pos <= 0 || p.line < 0 || p.line >= _content.length)
            return false;
        dstring line = _content.line(p.line);
        if (p.pos > line.length)
            return false;
        // the token props are updated on each change, before the key handling returns
        if (isNoCompletionToken(_content.tokenProp(TextPosition(p.line, p.pos - 1))))
            return false;
        return isCompletionPrefix(line[0 .. p.pos]);
    }

    /// where a completion request was made, see isCompletionContextCurrent()
    static struct CompletionContext {
        TextPosition caretPos;
        dstring lineBeforeCaret;
    }

    /// the caret position and the text before it on its line, to check that a completion answer still fits (#603)
    @property CompletionContext completionContext() {
        CompletionContext context;
        context.caretPos = _caretPos;
        if (_caretPos.line >= 0 && _caretPos.line < _content.length) {
            dstring line = _content.line(_caretPos.line);
            context.lineBeforeCaret = line[0 .. (_caretPos.pos < line.length ? _caretPos.pos : line.length)];
        }
        return context;
    }

    /// true if a completion answer for a request made at context can be shown: the editor has the focus, the caret
    /// is at the same position and the text before it on its line wasn't changed (#603)
    bool isCompletionContextCurrent(const ref CompletionContext context) {
        return focused && completionContext == context;
    }

    /// true for a key event that changes the text in a way that should show completions: a typed identifier
    /// character or '.' (Text event), or Backspace (it deletes on KeyDown)
    private bool isAutoCompleteEdit(ref KeyEvent event) {
        // shortcuts like Ctrl+Z, Ctrl+H must not trigger completion (Shift is fine: capitals, '_')
        if (event.flags & (KeyFlag.Control | KeyFlag.Alt | KeyFlag.Menu))
            return false;
        if (event.action == KeyAction.KeyDown)
            return event.keyCode == KeyCode.BACK;
        if (event.action == KeyAction.Text && event.text.length == 1)
            return isIdentChar(event.text[0]) || event.text[0] == '.';
        return false;
    }

    /// set when Ctrl+Space or AltGr+Space accepted a completion: the Text event of that key is not typed (#605)
    protected bool _skipKeyText;

    /// called by the completion popup when a key accepts a suggestion: the space the key types (or the non-breaking
    /// space some layouts give for AltGr+Space) is dropped, so that e.g. a '.' typed next follows the name directly.
    /// Only a space Text event before the next other event: some backends send none (X11 for Ctrl+Space), and then
    /// a key typed before Space is released must still be typed
    void skipTextOfCurrentKey(bool skip = true) {
        _skipKeyText = skip;
    }

    /// true while the completion popup is shown
    @property bool completionPopupShown() {
        return _completionPopup !is null;
    }

    protected uint _lastKeyDownCode;
    protected uint _periodKeyCode;
    /// handle keys: support autocompletion after . press with delay
    override bool onKeyEvent(KeyEvent event) {
        if (_skipKeyText) {
            _skipKeyText = false;
            if (event.action == KeyAction.Text && isSpaceText(event.text))
                return true;
        }
        // doc comments / call tips popup doesn't take focus: close it on Escape, at the end of the call,
        // or when the caret moves to another line
        if (_docsPopup) {
            if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.ESCAPE) {
                closeDocsPopup();
                return true;
            }
            if ((event.action == KeyAction.KeyDown && (event.keyCode == KeyCode.RETURN || event.keyCode == KeyCode.UP
                    || event.keyCode == KeyCode.DOWN || event.keyCode == KeyCode.PAGEUP || event.keyCode == KeyCode.PAGEDOWN))
                    || (event.action == KeyAction.Text && (event.text == ")" || event.text == ";")))
                closeDocsPopup();
        }
        if (event.action == KeyAction.KeyDown)
            _lastKeyDownCode = event.keyCode;
        if (_settings.autoAutoComplete) {
            // request completions after the key has changed the text, once per key (#601): a request on the KeyDown
            // of '.' got the text without the dot, and its fast answer (identifier completions) opened the popup,
            // which then blocked the later requests. Keys typed while the popup is open come here after it is closed.
            cancelCompletionTimer(); // the period timer is used only without auto autocomplete
            immutable bool edit = isAutoCompleteEdit(event);
            immutable bool res = super.onKeyEvent(event);
            if (edit && !_completionPopup && isCompletionContextBeforeCaret())
                window.dispatchAction(ACTION_GET_COMPLETIONS, this);
            return res;
        }
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

/// true for the text of a typed space: ' ' or a non-breaking space (AltGr+Space in some layouts) (#605)
bool isSpaceText(dstring text) {
    return text.length == 1 && (text[0] == ' ' || text[0] == '\u00A0');
}

unittest {
    assert(isSpaceText(" "d) && isSpaceText("\u00A0"d));
    assert(!isSpaceText(""d) && !isSpaceText("."d) && !isSpaceText("  "d) && !isSpaceText("\t"d));
}

/// true for the modifiers of a Space that accepts the selected completion: Ctrl, or AltGr (Win32 reports it as
/// Ctrl+Alt, SDL and X11 as right Alt). Left Alt+Space (window menu) and Win+Space (keyboard layout) go to the
/// system (#608)
bool isCompletionAcceptSpace(uint flags) {
    if (flags & KeyFlag.Control)
        return true;
    version (Windows) {
        // right Alt without Ctrl is plain Alt here (US layouts): it opens the window menu too
        return false;
    } else {
        return (flags & KeyFlag.RAlt) == KeyFlag.RAlt && (flags & KeyFlag.LAlt) != KeyFlag.LAlt
            && !(flags & KeyFlag.Menu);
    }
}

unittest {
    assert(isCompletionAcceptSpace(KeyFlag.Control) && isCompletionAcceptSpace(KeyFlag.Control | KeyFlag.Shift));
    assert(isCompletionAcceptSpace(KeyFlag.LControl | KeyFlag.RAlt)); // AltGr on Win32
    assert(!isCompletionAcceptSpace(0) && !isCompletionAcceptSpace(KeyFlag.Shift));
    assert(!isCompletionAcceptSpace(KeyFlag.Alt) && !isCompletionAcceptSpace(KeyFlag.LAlt));
    assert(!isCompletionAcceptSpace(KeyFlag.Menu) && !isCompletionAcceptSpace(KeyFlag.LMenu));
    version (Windows) {
        assert(!isCompletionAcceptSpace(KeyFlag.RAlt));
    } else {
        assert(isCompletionAcceptSpace(KeyFlag.RAlt)); // AltGr on SDL and X11
        assert(!isCompletionAcceptSpace(KeyFlag.RAlt | KeyFlag.LAlt));
        assert(!isCompletionAcceptSpace(KeyFlag.RAlt | KeyFlag.Menu));
    }
}

/// returns true if all characters are valid ident chars
bool isIdentText(dstring s) {
    foreach(ch; s)
        if (!isIdentChar(ch))
            return false;
    return true;
}

/// true for a token category without completions: comments, string and character literals (#603)
bool isNoCompletionToken(ubyte tokenProp) {
    switch (tokenCategory(tokenProp)) {
        case TokenCategory.Comment:
        case TokenCategory.String:
        case TokenCategory.Character:
            return true;
        default:
            // unterminated strings and comments (also character literals: Error_InvalidString in dsyntax.d)
            return tokenProp == TokenCategory.Error_InvalidString || tokenProp == TokenCategory.Error_InvalidComment;
    }
}

/**
    True if the text of a line before the caret ends with something to complete (#603): an identifier that doesn't
    start with a digit, or a '.' after such an identifier or another expression (`foo().`, `a[1].`, `.` for the
    module scope). Not after a number (`1.`, `1.5`, `0x1F`) or in `..`.
*/
bool isCompletionPrefix(dstring textBeforeCaret) {
    size_t end = textBeforeCaret.length;
    if (!end)
        return false;
    immutable bool dot = textBeforeCaret[end - 1] == '.';
    if (dot)
        end--;
    else if (!isIdentChar(textBeforeCaret[end - 1]))
        return false;
    size_t start = end;
    while (start > 0 && isIdentChar(textBeforeCaret[start - 1]))
        start--;
    if (start < end)
        return !(textBeforeCaret[start] >= '0' && textBeforeCaret[start] <= '9'); // an identifier, not a number
    // a '.' without an identifier before it: not in ".."
    return !(start > 0 && textBeforeCaret[start - 1] == '.');
}

unittest {
    assert(isCompletionPrefix("    foo"d));
    assert(isCompletionPrefix("_cur"d));
    assert(isCompletionPrefix("x1"d));
    assert(isCompletionPrefix("_currentFigure."d));
    assert(isCompletionPrefix("x1."d));
    assert(isCompletionPrefix("foo()."d));
    assert(isCompletionPrefix("a[1]."d));
    assert(isCompletionPrefix("."d));
    assert(isCompletionPrefix("a[0 .. b"d)); // the identifier after ".."
    assert(!isCompletionPrefix(""d));
    assert(!isCompletionPrefix("foo("d));
    assert(!isCompletionPrefix("foo "d));
    assert(!isCompletionPrefix("1"d));
    assert(!isCompletionPrefix("x = 1."d));
    assert(!isCompletionPrefix("x = 1.5"d));
    assert(!isCompletionPrefix("0x1F"d));
    assert(!isCompletionPrefix(".5"d));
    assert(!isCompletionPrefix("a.."d));

    assert(isNoCompletionToken(TokenCategory.Comment_SingleLine));
    assert(isNoCompletionToken(TokenCategory.Comment_MultyLineDoc));
    assert(isNoCompletionToken(TokenCategory.String));
    assert(isNoCompletionToken(TokenCategory.Character));
    assert(isNoCompletionToken(TokenCategory.Error_InvalidString));
    assert(isNoCompletionToken(TokenCategory.Error_InvalidComment));
    assert(!isNoCompletionToken(TokenCategory.Identifier));
    assert(!isNoCompletionToken(TokenCategory.Identifier_Member));
    assert(!isNoCompletionToken(TokenCategory.Op));
    assert(!isNoCompletionToken(TokenCategory.Keyword));
    assert(!isNoCompletionToken(0)); // no syntax highlight
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
        //maxHeight(400);
        selectItem(0);
    }

    Point fullContentSizeWithBorders() {
        measure(2000.pointsToPixels, 2000.pointsToPixels);
        // measured size already includes padding and margins
        return Point(measuredWidth, measuredHeight);
    }

    /// width of the vertical scrollbar shown when the items don't fit the height, after fullContentSizeWithBorders (#579)
    @property int scrollbarWidth() {
        return _scrollbar ? _scrollbar.measuredWidth : 0;
    }

    MenuItem updateItems() {
        MenuItem res = new MenuItem();
        foreach(i, dstring suggestion ; _suggestions) {
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
    /// accept the selected suggestion, if there is one; this closes and destroys the popup
    private void acceptSelected() {
        if (_selectedItemIndex >= 0)
            itemClicked(_selectedItemIndex);
    }

    /// handle keys
    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.Text) {
            if (isSpaceText(event.text) && (event.flags & (KeyFlag.Control | KeyFlag.Alt | KeyFlag.Menu))) {
                // Ctrl+Space or AltGr+Space as a Text event (SDL sends one for AltGr+Space, Win32 one after a
                // KeyDown below that accepted nothing): accept, type nothing (#605)
                if (isCompletionAcceptSpace(event.flags)) {
                    acceptSelected();
                    return true;
                }
                // left Alt+Space, Win+Space (X11 sends only a Text event when the window manager doesn't take
                // them): not for the popup, it stays open and nothing is typed (#608)
                return false;
            }
            // close first, then pass the key on: the editor requests completions for the new text (#601);
            // closing destroys this popup, so keep the editor in a local variable
            auto editor = _editor;
            editor.closeCompletionPopup(this);
            editor.onKeyEvent(event);
            return true;
        } else if (event.keyCode == KeyCode.ESCAPE) {
            _editor.closeCompletionPopup(this);
            return true;
        } else if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.BACK && event.noModifiers) {
            if (_prefix.length > _initialPrefix.length) {
                _prefix.length = _prefix.length - 1;
                MenuItem newItems = updateItems();
                _editor.onKeyEvent(event);
                menuItems = newItems;
                selectItem(0);
            } else {
                // Backspace past the prefix: close first, as for typed characters
                auto editor = _editor;
                editor.closeCompletionPopup(this);
                editor.onKeyEvent(event);
            }
            return true;
        } else if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.SPACE) {
            // Space doesn't accept the selected suggestion (#605): the menu would activate it on KeyDown. The Text
            // event that follows closes the popup and types the space into the editor (see above); Enter accepts
            if (!(event.flags & (KeyFlag.Control | KeyFlag.Alt | KeyFlag.Menu)))
                return true;
            // left Alt+Space opens the window menu (Windows, most Linux window managers), Win+Space switches the
            // keyboard layout: not handled, so that the system gets them; not passed to the menu either, which
            // would activate the selected item (#608)
            if (!isCompletionAcceptSpace(event.flags))
                return false;
            // Ctrl+Space and AltGr+Space accept it, without typing a character: a name accepted this way can be
            // followed by '.' directly
            auto editor = _editor;
            editor.skipTextOfCurrentKey();
            acceptSelected();
            if (editor.completionPopupShown)
                editor.skipTextOfCurrentKey(false); // nothing accepted (no item selected)
            // handled also then: not the window's Ctrl+Space accelerator, which would show a second popup
            return true;
        }
        return super.onKeyEvent(event);
    }
}
