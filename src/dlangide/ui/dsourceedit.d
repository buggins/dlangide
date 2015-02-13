module dlangide.ui.dsourceedit;

import dlangui.core.logger;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;
import dlangui.widgets.menu;
import dlangui.widgets.popup;

import ddc.lexer.textsource;
import ddc.lexer.exceptions;
import ddc.lexer.tokenizer;

import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.ui.commands;

import std.algorithm;


/// DIDE source file editor
class DSourceEdit : SourceEdit {
	this(string ID) {
		super(ID);
		styleId = null;
		backgroundColor = 0xFFFFFF;
        setTokenHightlightColor(TokenCategory.Comment, 0x008000); // green
        setTokenHightlightColor(TokenCategory.Keyword, 0x0000FF); // blue
        setTokenHightlightColor(TokenCategory.String, 0xA31515);  // brown
        setTokenHightlightColor(TokenCategory.Character, 0xA31515);  // brown
        setTokenHightlightColor(TokenCategory.Error, 0xFF0000);  // red
        setTokenHightlightColor(TokenCategory.Comment_Documentation, 0x206000);
        //setTokenHightlightColor(TokenCategory.Identifier, 0x206000);  // no colors
		MenuItem editPopupItem = new MenuItem(null);
		editPopupItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT);
        popupMenu = editPopupItem;
        showIcons = true;
        showFolding = true;
	}
	this() {
		this("SRCEDIT");
	}
    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile projectSourceFile() { return _projectSourceFile; }
    /// load by filename
    override bool load(string fn) {
        _projectSourceFile = null;
        bool res = super.load(fn);
        setHighlighter();
        return res;
    }

    void setHighlighter() {
        if (filename.endsWith(".d") || filename.endsWith(".dd") || filename.endsWith(".dh") || filename.endsWith(".ddoc")) {
            content.syntaxHighlighter = new SimpleDSyntaxHighlighter(filename);
        } else {
            content.syntaxHighlighter = null;
        }
    }

    /// load by project item
    bool load(ProjectSourceFile f) {
        if (!load(f.filename)) {
            _projectSourceFile = null;
            return false;
        }
        _projectSourceFile = f;
        setHighlighter();
        return true;
    }

    /// save to the same file
    bool save() {
        return _content.save();
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case IDEActions.FileSave:
                    save();
                    return true;
                case IDEActions.InsertCompletion:
                    EditOperation edit = new EditOperation(EditAction.Replace, getCaretPosition, a.label);
                    _content.performOperation(edit, this);
                    return true;
                default:
                    break;
            }
        }
        return super.handleAction(a);
    }



    void showCompletionPopup(dstring[] suggestions) {
        MenuItem completionPopupItem = new MenuItem(null);
        //Create popup menu
        foreach(int i, dstring suggestion ; suggestions) {
            auto action = new Action(IDEActions.InsertCompletion, suggestion);
            completionPopupItem.add(action);
        }
        completionPopupItem.updateActionState(this);
        PopupMenu popupMenu = new PopupMenu(completionPopupItem);
        popupMenu.onMenuItemActionListener = this;
        PopupWidget popup = window.showPopup(popupMenu, this, PopupAlign.Point | PopupAlign.Right, textPosToClient(_caretPos).left + left + _leftPaneWidth, textPosToClient(_caretPos).top + top + margins.top);
        popup.flags = PopupFlags.CloseOnClickOutside;
        Log.d("Showing popup at ", textPosToClient(_caretPos).left, " ", textPosToClient(_caretPos).top);
    }

    TextPosition getCaretPosition() {
        return _caretPos;
    }

	/// change caret position and ensure it is visible
	void setCaretPos(int line, int column)
	{
		_caretPos = TextPosition(line,column);
		invalidate();
		ensureCaretVisible();
	}
}



class SimpleDSyntaxHighlighter : SyntaxHighlighter {

    EditableContent _content;
    SourceFile _file;
    ArraySourceLines _lines;
    Tokenizer _tokenizer;
    this (string filename) {
        _file = new SourceFile(filename);
        _lines = new ArraySourceLines();
        _tokenizer = new Tokenizer(_lines);
        _tokenizer.errorTolerant = true;
    }

    TokenPropString[] _props;

    /// returns editable content
    @property EditableContent content() { return _content; }
    /// set editable content
    @property SyntaxHighlighter content(EditableContent content) {
        _content = content;
        return this;
    }

    private enum BracketMatch {
        CONTINUE,
        FOUND,
        ERROR
    }
    private static struct BracketStack {
        dchar[] buf;
        int pos;
        bool reverse;
        void init(bool reverse) {
            this.reverse = reverse;
            pos = 0;
        }
        void push(dchar ch) {
            if (buf.length <= pos)
                buf.length = pos + 16;
            buf[pos++] = ch;
        }
        dchar pop() {
            if (pos <= 0)
                return 0;
            return buf[--pos];
        }
        BracketMatch process(dchar ch) {
            if (reverse) {
                if (isCloseBracket(ch)) {
                    push(ch);
                    return BracketMatch.CONTINUE;
                } else {
                    if (pop() != pairedBracket(ch))
                        return BracketMatch.ERROR;
                    if (pos == 0)
                        return BracketMatch.FOUND;
                    return BracketMatch.CONTINUE;
                }
            } else {
                if (isOpenBracket(ch)) {
                    push(ch);
                    return BracketMatch.CONTINUE;
                } else {
                    if (pop() != pairedBracket(ch))
                        return BracketMatch.ERROR;
                    if (pos == 0)
                        return BracketMatch.FOUND;
                    return BracketMatch.CONTINUE;
                }
            }
        }
    }
    BracketStack _bracketStack;
    static bool isBracket(dchar ch) {
        return pairedBracket(ch) != 0;
    }
    static dchar pairedBracket(dchar ch) {
        switch (ch) {
            case '(':
                return ')';
            case ')':
                return '(';
            case '{':
                return '}';
            case '}':
                return '{';
            case '[':
                return ']';
            case ']':
                return '[';
            default:
                return 0; // not a bracket
        }
    }
    static bool isOpenBracket(dchar ch) {
        switch (ch) {
            case '(':
            case '{':
            case '[':
                return true;
            default:
                return false;
        }
    }
    static bool isCloseBracket(dchar ch) {
        switch (ch) {
            case ')':
            case '}':
            case ']':
                return true;
            default:
                return false;
        }
    }

    protected dchar nextBracket(int dir, ref TextPosition p) {
        for (;;) {
            TextPosition oldpos = p;
            p = dir < 0 ? _content.prevCharPos(p) : _content.nextCharPos(p);
            if (p == oldpos)
                return 0;
            auto prop = _content.tokenProp(p);
            if (tokenCategory(prop) == TokenCategory.Op) {
                dchar ch = _content[p];
                if (isBracket(ch))
                    return ch;
            }
        }
    }

    /// returns paired bracket {} () [] for char at position p, returns paired char position or p if not found or not bracket
    override TextPosition findPairedBracket(TextPosition p) {
        if (p.line < 0 || p.line >= content.length)
            return p;
        dstring s = content.line(p.line);
        if (p.pos < 0 || p.pos >= s.length)
            return p;
        dchar ch = content[p];
        dchar paired = pairedBracket(ch);
        if (!paired)
            return p;
        TextPosition startPos = p;
        int dir = isOpenBracket(ch) ? 1 : -1;
        _bracketStack.init(dir < 0);
        _bracketStack.process(ch);
        for (;;) {
            ch = nextBracket(dir, p);
            if (!ch) // no more brackets
                break;
            auto match = _bracketStack.process(ch);
            if (match == BracketMatch.FOUND)
                return p;
            if (match == BracketMatch.ERROR)
                return startPos;
            // continue
        }
    }


    /// return true if toggle line comment is supported for file type
    override @property bool supportsToggleLineComment() {
        return true;
    }

    /// return true if can toggle line comments for specified text range
    override bool canToggleLineComment(TextRange range) {
        TextRange r = content.fullLinesRange(range);
        if (isInsideBlockComment(r.start) || isInsideBlockComment(r.end))
            return false;
        return true;
    }

    protected bool isLineComment(dstring s) {
        for (int i = 0; i < cast(int)s.length - 1; i++) {
            if (s[i] == '/' && s[i + 1] == '/')
                return true;
            else if (s[i] != ' ' && s[i] != '\t')
                return false;
        }
        return false;
    }

    protected dstring commentLine(dstring s, int commentX) {
        dchar[] res;
        int x = 0;
        bool commented = false;
        for (int i = 0; i < s.length; i++) {
            dchar ch = s[i];
            if (ch == '\t') {
                int newX = (x + _content.tabSize) / _content.tabSize * _content.tabSize;
                if (!commented && newX >= commentX) {
                    commented = true;
                    if (newX != commentX) {
                        // replace tab with space
                        for (; x <= commentX; x++)
                            res ~= ' ';
                    } else {
                        res ~= ch;
                        x = newX;
                    }
                    res ~= "//";
                    x += 2;
                } else {
                    res ~= ch;
                    x = newX;
                }
            } else {
                if (!commented && x == commentX) {
                    commented = true;
                    res ~= "//";
                    res ~= ch;
                    x += 3;
                } else {
                    res ~= ch;
                    x++;
                }
            }
        }
        if (!commented) {
            for (; x < commentX; x++)
                res ~= ' ';
            res ~= "//";
        }
        return cast(dstring)res;
    }

    /// remove single line comment from beginning of line
    protected dstring uncommentLine(dstring s) {
        int p = -1;
        for (int i = 0; i < cast(int)s.length - 1; i++) {
            if (s[i] == '/' && s[i + 1] == '/') {
                p = i;
                break;
            }
        }
        if (p < 0)
            return s;
        s = s[0..p] ~ s[p + 2 .. $];
        for (int i = 0; i < s.length; i++) {
            if (s[i] != ' ' && s[i] != '\t') {
                return s;
            }
        }
        return null;
    }

    /// searches for neares token start before or equal to position
    protected TextPosition tokenStart(TextPosition pos) {
        TextPosition p = pos;
        for (;;) {
            TextPosition prevPos = content.prevCharPos(p);
            if (p == prevPos)
                return p; // begin of file
            TokenProp prop = content.tokenProp(p);
            TokenProp prevProp = content.tokenProp(prevPos);
            if (prop && prop != prevProp)
                return p;
            p = prevPos;
        }
    }

    static struct TokenWithRange {
        Token token;
        TextRange range;
        @property string toString() {
            return token.toString ~ range.toString;
        }
    }
    protected TextPosition _lastTokenStart;
    protected Token _lastToken;
    protected bool initTokenizer(TextPosition startPos) {
        const dstring[] lines = content.lines;
        _lines.init(cast(dstring[])(lines[startPos.line .. $]), _file, startPos.line);
        _tokenizer.init(_lines, startPos.pos);
        _lastTokenStart = startPos;
        _lastToken = null;
        nextToken();
        return true;
    }

    protected TokenWithRange nextToken() {
        TokenWithRange res;
        if (_lastToken && _lastToken.type == TokenType.EOF) {
            // end of file
            res.range.start = _lastTokenStart;
            res.range.end = content.endOfFile();
            res.token = null;
            return res;
        }
        res.range.start = _lastTokenStart;
        res.token = _lastToken;
        _lastToken = _tokenizer.nextToken();
        if (_lastToken)
            _lastToken = _lastToken.clone();
        _lastTokenStart = _lastToken ? TextPosition(_lastToken.line - 1, _lastToken.pos - 1) : content.endOfFile();
        res.range.end = _lastTokenStart;
        return res;
    }

    protected TokenWithRange getPositionToken(TextPosition pos) {
        //Log.d("getPositionToken for ", pos);
        TextPosition start = tokenStart(pos);
        //Log.d("token start found: ", start);
        initTokenizer(start);
        for (;;) {
            TokenWithRange tokenRange = nextToken();
            //Log.d("read token: ", tokenRange);
            if (!tokenRange.token) {
                //Log.d("end of file");
                return tokenRange;
            }
            if (pos >= tokenRange.range.start && pos < tokenRange.range.end) {
                //Log.d("found: ", pos, " in ", tokenRange);
                return tokenRange;
            }
        }
    }

    protected TokenWithRange[] getRangeTokens(TextRange range) {
        TokenWithRange[] res;
        //Log.d("getPositionToken for ", pos);
        TextPosition start = tokenStart(range.start);
        //Log.d("token start found: ", start);
        initTokenizer(start);
        for (;;) {
            TokenWithRange tokenRange = nextToken();
            //Log.d("read token: ", tokenRange);
            if (!tokenRange.token) {
                //Log.d("end of file");
                return res;
            }
            if (tokenRange.range.intersects(range)) {
                //Log.d("found: ", pos, " in ", tokenRange);
                res ~= tokenRange;
            }
        }
    }

    protected bool isInsideBlockComment(TextPosition pos) {
        TokenWithRange tokenRange = getPositionToken(pos);
        if (tokenRange.token && tokenRange.token.type == TokenType.COMMENT && tokenRange.token.isMultilineComment)
            return pos > tokenRange.range.start && pos < tokenRange.range.end;
        return false;
    }

    /// toggle line comments for specified text range
    override void toggleLineComment(TextRange range, Object source) {
        TextRange r = content.fullLinesRange(range);
        if (isInsideBlockComment(r.start) || isInsideBlockComment(r.end))
            return;
        int lineCount = r.end.line - r.start.line;
        bool noEolAtEndOfRange = false;
        if (lineCount == 0 || r.end.pos > 0) {
            noEolAtEndOfRange = true;
            lineCount++;
        }
        int minLeftX = -1;
        bool hasComments = false;
        bool hasNoComments = false;
        bool hasNonEmpty = false;
        dstring[] srctext;
        dstring[] dsttext;
        for (int i = 0; i < lineCount; i++) {
            int lineIndex = r.start.line + i;
            dstring s = content.line(lineIndex);
            srctext ~= s;
            TextLineMeasure m = content.measureLine(lineIndex);
            if (!m.empty) {
                if (minLeftX < 0 || minLeftX > m.firstNonSpaceX)
                    minLeftX = m.firstNonSpaceX;
                hasNonEmpty = true;
                if (isLineComment(s))
                    hasComments = true;
                else
                    hasNoComments = true;
            }
        }
        if (minLeftX < 0)
            minLeftX = 0;
        if (hasNoComments || !hasComments) {
            // comment
            for (int i = 0; i < lineCount; i++) {
                dsttext ~= commentLine(srctext[i], minLeftX);
            }
            if (!noEolAtEndOfRange)
                dsttext ~= ""d;
            EditOperation op = new EditOperation(EditAction.Replace, r, dsttext);
            _content.performOperation(op, source);
        } else {
            // uncomment
            for (int i = 0; i < lineCount; i++) {
                dsttext ~= uncommentLine(srctext[i]);
            }
            if (!noEolAtEndOfRange)
                dsttext ~= ""d;
            EditOperation op = new EditOperation(EditAction.Replace, r, dsttext);
            _content.performOperation(op, source);
        }
    }

    /// return true if toggle block comment is supported for file type
    override @property bool supportsToggleBlockComment() {
        return true;
    }
    /// return true if can toggle block comments for specified text range
    override bool canToggleBlockComment(TextRange range) {
        TokenWithRange startToken = getPositionToken(range.start);
        TokenWithRange endToken = getPositionToken(range.end);
        //Log.d("canToggleBlockComment: startToken=", startToken, " endToken=", endToken);
        if (startToken.token && endToken.token && startToken.range == endToken.range && startToken.token.isMultilineComment) {
            //Log.d("canToggleBlockComment: can uncomment");
            return true;
        }
        if (range.empty)
            return false;
        TokenWithRange[] tokens = getRangeTokens(range);
        foreach(ref t; tokens) {
            if (t.token.type == TokenType.COMMENT) {
                if (t.token.isMultilineComment) {
                    // disable until nested comments support is implemented
                    return false;
                } else {
                    // single line comment
                    if (t.range.isInside(range.start) || t.range.isInside(range.end))
                        return false;
                }
            }
        }
        return true;
    }
    /// toggle block comments for specified text range
    override void toggleBlockComment(TextRange srcrange, Object source) {
        TokenWithRange startToken = getPositionToken(srcrange.start);
        TokenWithRange endToken = getPositionToken(srcrange.end);
        if (startToken.token && endToken.token && startToken.range == endToken.range && startToken.token.isMultilineComment) {
            TextRange range = startToken.range;
            dstring[] dsttext;
            for (int i = range.start.line; i <= range.end.line; i++) {
                dstring s = content.line(i);
                int charsRemoved = 0;
                int minp = 0;
                if (i == range.start.line) {
                    int maxp = content.lineLength(range.start.line);
                    if (i == range.end.line)
                        maxp = range.end.pos - 2;
                    charsRemoved = 2;
                    for (int j = range.start.pos + charsRemoved; j < maxp; j++) {
                        if (s[j] != s[j - 1])
                            break;
                        charsRemoved++;
                    }
                    //Log.d("line before removing start of comment:", s);
                    s = s[range.start.pos + charsRemoved .. $];
                    //Log.d("line after removing start of comment:", s);
                    charsRemoved += range.start.pos;
                }
                if (i == range.end.line) {
                    int endp = range.end.pos;
                    if (charsRemoved > 0)
                        endp -= charsRemoved;
                    int endRemoved = 2;
                    for (int j = endp - endRemoved; j >= 0; j--) {
                        if (s[j] != s[j + 1])
                            break;
                        endRemoved++;
                    }
                    //Log.d("line before removing end of comment:", s);
                    s = s[0 .. endp - endRemoved];
                    //Log.d("line after removing end of comment:", s);
                }
                dsttext ~= s;
            }
            EditOperation op = new EditOperation(EditAction.Replace, range, dsttext);
            _content.performOperation(op, source);
            return;
        } else {
            if (srcrange.empty)
                return;
            TokenWithRange[] tokens = getRangeTokens(srcrange);
            foreach(ref t; tokens) {
                if (t.token.type == TokenType.COMMENT) {
                    if (t.token.isMultilineComment) {
                        // disable until nested comments support is implemented
                        return;
                    } else {
                        // single line comment
                        if (t.range.isInside(srcrange.start) || t.range.isInside(srcrange.end))
                            return;
                    }
                }
            }
            dstring[] dsttext;
            for (int i = srcrange.start.line; i <= srcrange.end.line; i++) {
                dstring s = content.line(i);
                int charsAdded = 0;
                if (i == srcrange.start.line) {
                    int p = srcrange.start.pos;
                    if (p < s.length) {
                        s = s[p .. $];
                        charsAdded = -p;
                    } else {
                        charsAdded = -(cast(int)s.length);
                        s = null;
                    }
                    s = "/*" ~ s;
                    charsAdded += 2;
                }
                if (i == srcrange.end.line) {
                    int p = srcrange.end.pos + charsAdded;
                    s = p > 0 ? s[0..p] : null;
                    s ~= "*/";
                }
                dsttext ~= s;
            }
            EditOperation op = new EditOperation(EditAction.Replace, srcrange, dsttext);
            _content.performOperation(op, source);
            return;
        }

    }

    /// categorize characters in content by token types
    void updateHighlight(dstring[] lines, TokenPropString[] props, int changeStartLine, int changeEndLine) {
        //Log.d("updateHighlight");
        long ms0 = currentTimeMillis();
        _props = props;
        changeStartLine = 0;
        changeEndLine = cast(int)lines.length;
        _lines.init(lines[changeStartLine..$], _file, changeStartLine);
        _tokenizer.init(_lines);
        int tokenPos = 0;
        int tokenLine = 0;
        ubyte category = 0;
        try {
            for (;;) {
                Token token = _tokenizer.nextToken();
                if (token is null) {
                    //Log.d("Null token returned");
                    break;
                }
                uint newPos = token.pos - 1;
                uint newLine = token.line - 1;

                //Log.d("", tokenLine + 1, ":", tokenPos + 1, "  \t", token.line, ":", token.pos, "\t", token.toString);
                if (token.type == TokenType.EOF) {
                    //Log.d("EOF token");
                }

                // fill with category
                for (int i = tokenLine; i <= newLine; i++) {
                    int start = i > tokenLine ? 0 : tokenPos;
                    int end = i < newLine ? cast(int)lines[i].length : newPos;
                    for (int j = start; j < end; j++) {
						if (j < _props[i].length) {
							_props[i][j] = category;
						}
					}
                }

                // handle token - convert to category
                switch(token.type) {
                    case TokenType.COMMENT:
                        category = token.isDocumentationComment ? TokenCategory.Comment_Documentation : TokenCategory.Comment;
                        break;
                    case TokenType.KEYWORD:
                        category = TokenCategory.Keyword;
                        break;
                    case TokenType.IDENTIFIER:
                        category = TokenCategory.Identifier;
                        break;
                    case TokenType.STRING:
                        category = TokenCategory.String;
                        break;
                    case TokenType.CHARACTER:
                        category = TokenCategory.Character;
                        break;
                    case TokenType.INTEGER:
                        category = TokenCategory.Integer;
                        break;
                    case TokenType.FLOAT:
                        category = TokenCategory.Float;
                        break;
                    case TokenType.OP:
                        category = TokenCategory.Op;
                        break;
                    case TokenType.INVALID:
                        switch (token.invalidTokenType) {
                            case TokenType.IDENTIFIER:
                                category = TokenCategory.Error_InvalidIdentifier;
                                break;
                            case TokenType.STRING:
                                category = TokenCategory.Error_InvalidString;
                                break;
                            case TokenType.COMMENT:
                                category = TokenCategory.Error_InvalidComment;
                                break;
                            case TokenType.OP:
                                category = TokenCategory.Error_InvalidOp;
                                break;
                            case TokenType.FLOAT:
                            case TokenType.INTEGER:
                                category = TokenCategory.Error_InvalidNumber;
                                break;
                            default:
                                category = TokenCategory.Error;
                                break;
                        }
                        break;
                    default:
                        category = 0;
                        break;
                }
                tokenPos = newPos;
                tokenLine= newLine;

                if (token.type == TokenType.EOF) {
                    //Log.d("EOF token");
                    break;
                }
            }
        } catch (Exception e) {
            Log.e("exception while trying to parse D source", e);
        }
        _lines.close();
        _props = null;
		long elapsed = currentTimeMillis() - ms0;
		if (elapsed > 20)
			Log.d("updateHighlight took ", elapsed, "ms");
    }
}
