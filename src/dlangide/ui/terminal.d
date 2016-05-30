module dlangide.ui.terminal;

import dlangui.widgets.widget;
import dlangui.widgets.controls;

struct TerminalChar {
    ubyte bgColor = 0;
    ubyte textColor = 0;
    dchar ch = ' ';
}

struct TerminalLine {
    TerminalChar[] line;
    bool overflowFlag;
    bool eolFlag;
    void clear() {
        line.length = 0;
        overflowFlag = false;
        eolFlag = false;
    }
    void markLineOverflow() {}
    void markLineEol() {}
    void putCharAt(dchar ch, int x) {
        if (x >= line.length) {
            while (x >= line.length) {
                line.assumeSafeAppend;
                line ~= TerminalChar.init;
            }
        }
        line[x].ch = ch;
    }
}

struct TerminalContent {
    TerminalLine[] lines;
    Rect rc;
    FontRef font;
    int maxBufferLines = 3000;
    int topLine;
    int width; // width in chars
    int height; // height in chars
    int charw; // single char width
    int charh; // single char height
    int cursorx;
    int cursory;
    void layout(FontRef font, Rect rc) {
        this.rc = rc;
        this.font = font;
        this.charw = font.charWidth('0');
        this.charh = font.height;
        int w = rc.width / charw;
        int h = rc.height / charh;
        setViewSize(w, h);
    }
    void setViewSize(int w, int h) {
        if (h < 2)
            h = 2;
        if (w < 16)
            w = 16;
        width = w;
        height = h;
    }
    void draw(DrawBuf buf) {
        Rect lineRect = rc;
        dchar[] text;
        text.length = 1;
        text[0] = ' ';
        for (uint i = 0; i < height && i + topLine < lines.length; i++) {
            lineRect.bottom = lineRect.top + charh;
            TerminalLine * p = &lines[i + topLine];
            // draw line in rect
            for (int x = 0; x < p.line.length; x++) {
                dchar ch = p.line[x].ch;
                if (ch >= ' ') {
                    text[0] = ch;
                    font.drawText(buf, lineRect.left + x * charw, lineRect.top, text, 0);
                }
            }
            lineRect.top = lineRect.bottom;
        }
    }
    TerminalLine * getLine(ref int yy) {
        if (yy < 0)
            yy = 0;
        if (yy > height)
            yy = height;
        if (yy == height) {
            topLine++;
            yy--;
        }
        int y = yy;
        y = topLine + y;
        if (y >= maxBufferLines) {
            int delta = y - maxBufferLines;
            for (uint i = 0; i + delta < maxBufferLines && i + delta < lines.length; i++) {
                lines[i] = lines[i + delta];
            }
            y -= delta;
            if (lines.length < maxBufferLines) {
                size_t oldlen = lines.length;
                lines.length = maxBufferLines;
                for(auto i = oldlen; i < lines.length; i++)
                    lines[i] = TerminalLine.init;
            }
        }
        if (cast(uint)y >= lines.length) {
            for (auto i = lines.length; i <= y; i++)
                lines ~= TerminalLine.init;
        }
        return &lines[y];
    }
    void putCharAt(dchar ch, ref int x, ref int y) {
        if (x < 0)
            x = 0;
        TerminalLine * line = getLine(y);
        if (x >= width) {
            line.markLineOverflow();
            y++;
            line = getLine(y);
            x = 0;
        }
        line.putCharAt(ch, x);
    }
    int tabSize = 8;
    // supports printed characters and \r \n \t
    void putChar(dchar ch) {
        if (ch == '\r') {
            cursorx = 0;
            return;
        }
        if (ch == '\n') {
            TerminalLine * line = getLine(cursory);
            line.markLineEol();
            cursory++;
            line = getLine(cursory);
            cursorx = 0;
            return;
        }
        if (ch == '\t') {
            int newx = (cursorx + tabSize) / tabSize * tabSize;
            if (newx > width) {
                TerminalLine * line = getLine(cursory);
                line.markLineEol();
                cursory++;
                line = getLine(cursory);
                cursorx = 0;
            } else {
                for (int x = cursorx; x < newx; x++) {
                    putCharAt(' ', cursorx, cursory);
                    cursorx++;
                }
            }
            return;
        }
        putCharAt(ch, cursorx, cursory);
        cursorx++;
    }

    void updateScrollBar(ScrollBar sb) {
        sb.pageSize = height;
        sb.maxValue = lines.length ? lines.length - 1 : 0;
        sb.position = topLine;
    }
}

class TerminalWidget : WidgetGroup {
    protected ScrollBar _verticalScrollBar;
    protected TerminalContent _content;
    this() {
        this(null);
    }
    this(string ID) {
        super(ID);
        styleId = "TERMINAL";
        _verticalScrollBar = new ScrollBar("VERTICAL_SCROLLBAR", Orientation.Vertical);
        _verticalScrollBar.minValue = 0;
        addChild(_verticalScrollBar);
    }
    /** 
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 

    */
    override void measure(int parentWidth, int parentHeight) {
        int w = (parentWidth == SIZE_UNSPECIFIED) ? font.charWidth('0') * 80 : parentWidth;
        int h = (parentHeight == SIZE_UNSPECIFIED) ? font.height * 10 : parentHeight;
        Rect rc = Rect(0, 0, w, h);
        applyMargins(rc);
        applyPadding(rc);
        _verticalScrollBar.measure(rc.width, rc.height);
        rc.right -= _verticalScrollBar.measuredWidth;
        measuredContent(parentWidth, parentHeight, rc.width, rc.height);
    }

    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        if (visibility == Visibility.Gone) {
            return;
        }
        _pos = rc;
        _needLayout = false;
        applyMargins(rc);
        applyPadding(rc);
        Rect sbrc = rc;
        sbrc.left = sbrc.right - _verticalScrollBar.measuredWidth;
        _verticalScrollBar.layout(sbrc);
        rc.right = sbrc.left;
        _content.layout(font, rc);
        if (outputChars.length) {
            // push buffered text
            write(""d);
            _needLayout = false;
        }
    }
    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        Rect rc = _pos;
        applyMargins(rc);
        auto saver = ClipRectSaver(buf, rc, alpha);
        DrawableRef bg = backgroundDrawable;
        if (!bg.isNull) {
            bg.drawTo(buf, rc, state);
        }
        applyPadding(rc);
        _verticalScrollBar.onDraw(buf);
        _content.draw(buf);
    }

    private char[] outputBuffer;
    // write utf 8
    void write(string bytes) {
        if (!bytes.length)
            return;
        import std.utf;
        outputBuffer.assumeSafeAppend;
        outputBuffer ~= bytes;
        size_t index = 0;
        dchar[] decoded;
        decoded.assumeSafeAppend;
        dchar ch = 0;
        for (;;) {
            size_t oldindex = index;
            try {
                ch = decode(outputBuffer, index);
                decoded ~= ch;
            } catch (UTFException e) {
                if (index + 4 <= outputBuffer.length) {
                    // just append invalid character
                    ch = '?';
                    index++;
                }
            }
            if (oldindex == index)
                break;
        }
        if (index > 0) {
            // move content
            for (size_t i = 0; i + index < outputBuffer.length; i++)
                outputBuffer[i] = outputBuffer[i + index];
            outputBuffer.length = outputBuffer.length - index;
        }
        if (decoded.length)
            write(cast(dstring)decoded);
    }

    private dchar[] outputChars;
    // write utf32
    void write(dstring chars) {
        if (!chars.length && !outputChars.length)
            return;
        outputChars.assumeSafeAppend;
        outputChars ~= chars;
        if (!_content.width)
            return;
        uint i = 0;
        for (; i < outputChars.length; i++) {
            int ch = outputChars[i];
            if (ch < ' ') {
                // control character
                switch(ch) {
                    case '\r':
                    case '\n':
                    case '\t':
                        _content.putChar(ch);
                        break;
                    default:
                        break;
                }
            } else {
                _content.putChar(ch);
            }
        }
        if (i > 0) {
            if (i == outputChars.length)
                outputChars.length = 0;
            else {
                for (uint j = 0; j + i < outputChars.length; j++)
                    outputChars[j] = outputChars[j + i];
                outputChars.length = outputChars.length - i;
            }
        }
        _content.updateScrollBar(_verticalScrollBar);
    }
}
