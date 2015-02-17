module dlangide.tools.d.simpledsyntaxhighlighter;

import dlangui.core.logger;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;

import ddc.lexer.textsource;
import ddc.lexer.exceptions;
import ddc.lexer.tokenizer;

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
                return startPos;
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
                    res ~= "//"d;
                    x += 2;
                } else {
                    res ~= ch;
                    x = newX;
                }
            } else {
                if (!commented && x == commentX) {
                    commented = true;
                    res ~= "//"d;
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
            res ~= "//"d;
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
}
