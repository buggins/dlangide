module dlangide.ui.dsourceedit;

import dlangui.core.logger;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;
import dlangui.widgets.menu;

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
                default:
                    break;
            }
        }
        return super.handleAction(a);
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
        for (int i = 0; i < s.length - 2; i++) {
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
        Log.d("getPositionToken for ", pos);
        TextPosition start = tokenStart(pos);
        Log.d("token start found: ", start);
        initTokenizer(start);
        for (;;) {
            TokenWithRange tokenRange = nextToken();
            Log.d("read token: ", tokenRange);
            if (!tokenRange.token) {
                Log.d("end of file");
                return tokenRange;
            }
            if (pos >= tokenRange.range.start && pos < tokenRange.range.end) {
                Log.d("found: ", pos, " in ", tokenRange);
                return tokenRange;
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
        }
    }

    /// return true if toggle block comment is supported for file type
    override @property bool supportsToggleBlockComment() {
        // TODO
        return false;
    }
    /// return true if can toggle block comments for specified text range
    override bool canToggleBlockComment(TextRange range) {
        // TODO
        return false;
    }
    /// toggle block comments for specified text range
    override void toggleBlockComment(TextRange range, Object source) {
        // TODO
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
                if (token.type == TokenType.EOF) {
                    //Log.d("EOF token");
                    break;
                }
                uint newPos = token.pos - 1;
                uint newLine = token.line - 1;

                //Log.d("", token.line, ":", token.pos, "\t", tokenLine + 1, ":", tokenPos + 1, "\t", token.toString);

                // fill with category
                for (int i = tokenLine; i <= newLine; i++) {
                    int start = i > tokenLine ? 0 : tokenPos;
                    int end = i < newLine ? cast(int)lines[i].length : newPos;
                    for (int j = start; j < end; j++)
                        _props[i][j] = category;
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

