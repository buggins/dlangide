module dlangide.ui.dmdprofilerview;

import dlangui.widgets.layouts;
import dlangui.widgets.widget;
import dlangui.widgets.grid;
import dlangui.widgets.scroll;
import dlangui.widgets.controls;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangui.core.i18n;
import dlangide.tools.d.dmdtrace;

class DMDProfilerView : WidgetGroupDefaultDrawing {
    protected IDEFrame _frame;
    protected DMDTraceLogParser _data;
    protected TraceFunctionList _fullFunctionList;
    this(string ID, IDEFrame frame, DMDTraceLogParser data) {
        super(ID);
        _frame = frame;
        _data = data;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _fullFunctionList = new TraceFunctionList("FULL_FUNCTION_LIST", "All functions"d, _data.nodesByTotalTime, _data.ticks_per_second); // new TextWidget(null, "DMD profiler view"d);
        addChild(_fullFunctionList);
    }
    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        super.layout(rc);
        applyMargins(rc);
        applyPadding(rc);
        Rect rc1 = rc;
        rc1.right = rc1.left + rc.width / 2;
        _fullFunctionList.layout(rc1);
    }
    /**
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout).

    */
    override void measure(int parentWidth, int parentHeight) {
        _fullFunctionList.measure(parentWidth, parentHeight);
        measuredContent(parentWidth, parentHeight, _fullFunctionList.measuredWidth, _fullFunctionList.measuredHeight);
    }
}

class TraceFuncionGrid : StringGridWidgetBase {
    protected FunctionNode[] _list;
    protected dstring[] _colTitles;
    protected ulong _ticksPerSecond;
    this(string ID, FunctionNode[] list, ulong ticks_per_second) {
        super(ID);
        _ticksPerSecond = ticks_per_second;
        _list = list;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        fullColumnOnLeft(false);
        fullRowOnTop(false);
        resize(4, cast(int)list.length);
        setColTitle(0, "Function name"d);
        setColTitle(1, "Called"d);
        setColTitle(2, "F us"d);
        setColTitle(3, "F+D us"d);
        showRowHeaders = false;
        rowSelect = true;
        minVisibleRows = 10;
        minVisibleCols = 4;
    }

    private dchar[128] _numberFormatBuf;
    dstring formatNumber(ulong v, dchar[] buffer) {
        dchar[64] buf;
        int k = 0;
        if (!v) {
            buf[k++] = '0';
        } else {
            while (v) {
                buf[k++] = '0' + (cast(int)(v % 10));
                v /= 10;
            }
        }
        // reverse order
        for (int i = 0; i < k; i++)
            buffer[i] = buf[k - i - 1];
        return cast(dstring)buffer[0..k];
    }
    dstring formatDurationTicks(ulong n) {
        ulong v = n * 1000000 / _ticksPerSecond;
        return formatNumber(v, _numberFormatBuf[]);
    }

    /// get cell text
    override dstring cellText(int col, int row) {
        import std.conv : to;
        if (row < 0 || row >= _list.length)
            return ""d;
        FunctionNode entry = _list[row];
        switch (col) {
            case 0:
                string fn = entry.name;
                if (fn.length > 256)
                    fn = fn[0..256] ~ "...";
                return fn.to!dstring;
            case 1:
                return formatNumber(entry.number_of_calls, _numberFormatBuf);
            case 2:
                return formatDurationTicks(entry.function_time);
            case 3:
                return formatDurationTicks(entry.function_and_descendant_time);
            default:
                return ""d;
        }
    }
    /// set cell text
    override StringGridWidgetBase setCellText(int col, int row, dstring text) {
        // do nothing
        return this;
    }
    /// returns row header title
    override dstring rowTitle(int row) {
        return ""d;
    }
    /// set row header title
    override StringGridWidgetBase setRowTitle(int row, dstring title) {
        return this;
    }

    /// returns row header title
    override dstring colTitle(int col) {
        return _colTitles[col];
    }

    /// set col header title
    override StringGridWidgetBase setColTitle(int col, dstring title) {
        _colTitles[col] = title;
        return this;
    }

    void autofit() {
        autoFitColumnWidths();
        fillColumnWidth(0);
    }

    /// set new size
    override void resize(int c, int r) {
        if (c == cols && r == rows)
            return;
        int oldcols = cols;
        int oldrows = rows;
        super.resize(c, r);
        _colTitles.length = c;
    }

    protected override Point measureCell(int x, int y) {
        if (_customCellAdapter && _customCellAdapter.isCustomCell(x, y)) {
            return _customCellAdapter.measureCell(x, y);
        }
        //Log.d("measureCell ", x, ", ", y);
        FontRef fnt = font;
        dstring txt;
        if (x >= 0 && y >= 0)
            txt = cellText(x, y);
        else if (y < 0 && x >= 0)
            txt = colTitle(x);
        else if (y >= 0 && x < 0)
            txt = rowTitle(y);
        Point sz = fnt.textSize(txt);
        if (sz.y < fnt.height)
            sz.y = fnt.height;
        return sz;
    }


    /// draw cell content
    protected override void drawCell(DrawBuf buf, Rect rc, int col, int row) {
        if (_customCellAdapter && _customCellAdapter.isCustomCell(col, row)) {
            return _customCellAdapter.drawCell(buf, rc, col, row);
        }
        if (BACKEND_GUI)
            rc.shrink(2, 1);
        else
            rc.right--;
        FontRef fnt = font;
        dstring txt = cellText(col, row);
        Point sz = fnt.textSize(txt);
        Align ha = Align.Right;
        //if (sz.y < rc.height)
        applyAlign(rc, sz, ha, Align.VCenter);
        int offset = BACKEND_CONSOLE ? 0 : 1;
        fnt.drawText(buf, rc.left + offset, rc.top + offset, txt, textColor);
    }

    /// draw cell content
    protected override void drawHeaderCell(DrawBuf buf, Rect rc, int col, int row) {
        if (BACKEND_GUI)
            rc.shrink(2, 1);
        else
            rc.right--;
        FontRef fnt = font;
        dstring txt;
        if (row < 0 && col >= 0)
            txt = colTitle(col);
        else if (row >= 0 && col < 0)
            txt = rowTitle(row);
        if (!txt.length)
            return;
        Point sz = fnt.textSize(txt);
        Align ha = Align.Left;
        if (col < 0)
            ha = Align.Right;
        //if (row < 0)
        //    ha = Align.HCenter;
        applyAlign(rc, sz, ha, Align.VCenter);
        int offset = BACKEND_CONSOLE ? 0 : 1;
        uint cl = textColor;
        cl = style.customColor("grid_cell_text_color_header", cl);
        fnt.drawText(buf, rc.left + offset, rc.top + offset, txt, cl);
    }

    /// draw cell background
    protected override void drawHeaderCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        bool selectedCol = (c == col) && !_rowSelect;
        bool selectedRow = r == row;
        bool selectedCell = selectedCol && selectedRow;
        if (_rowSelect && selectedRow)
            selectedCell = true;
        if (!selectedCell && _multiSelect) {
            selectedCell = Point(c, r) in _selection || (_rowSelect && Point(0, r) in _selection);
        }
        // draw header cell background
        DrawableRef dw = c < 0 ? _cellRowHeaderBackgroundDrawable : _cellHeaderBackgroundDrawable;
        uint cl = _cellHeaderBackgroundColor;
        if (c >= 0 || r >= 0) {
            if (c < 0 && selectedRow) {
                cl = _cellHeaderSelectedBackgroundColor;
                dw = _cellRowHeaderSelectedBackgroundDrawable;
            } else if (r < 0 && selectedCol) {
                cl = _cellHeaderSelectedBackgroundColor;
                dw = _cellHeaderSelectedBackgroundDrawable;
            }
        }
        if (!dw.isNull)
            dw.drawTo(buf, rc);
        else
            buf.fillRect(rc, cl);
        static if (BACKEND_GUI) {
            uint borderColor = _cellHeaderBorderColor;
            buf.drawLine(Point(rc.right - 1, rc.bottom), Point(rc.right - 1, rc.top), _cellHeaderBorderColor); // vertical
            buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right - 1, rc.bottom - 1), _cellHeaderBorderColor); // horizontal
        }
    }

    /// draw cell background
    protected override void drawCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        bool selectedCol = c == col;
        bool selectedRow = r == row;
        bool selectedCell = selectedCol && selectedRow;
        if (_rowSelect && selectedRow)
            selectedCell = true;
        if (!selectedCell && _multiSelect) {
            selectedCell = Point(c, r) in _selection || (_rowSelect && Point(0, r) in _selection);
        }
        uint borderColor = _cellBorderColor;
        if (c < fixedCols || r < fixedRows) {
            // fixed cell background
            buf.fillRect(rc, _fixedCellBackgroundColor);
            borderColor = _fixedCellBorderColor;
        }
        static if (BACKEND_GUI) {
            buf.drawLine(Point(rc.left, rc.bottom + 1), Point(rc.left, rc.top), borderColor); // vertical
            buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right - 1, rc.bottom - 1), borderColor); // horizontal
        }
        if (selectedCell) {
            static if (BACKEND_GUI) {
                if (_rowSelect)
                    buf.drawFrame(rc, _selectionColorRowSelect, Rect(0,1,0,1), _cellBorderColor);
                else
                    buf.drawFrame(rc, _selectionColor, Rect(1,1,1,1), _cellBorderColor);
            } else {
                if (_rowSelect)
                    buf.fillRect(rc, _selectionColorRowSelect);
                else
                    buf.fillRect(rc, _selectionColor);
            }
        }
    }

    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        super.layout(rc);
        autofit();
    }
}

class TraceFunctionList : VerticalLayout {
    TraceFuncionGrid _grid;

    this(string ID, dstring title, FunctionNode[] list, ulong ticks_per_second) {
        super(ID);
        addChild(new TextWidget("gridTitle", title).layoutWidth(FILL_PARENT));
        _grid = new TraceFuncionGrid("FUNCTION_LIST", list, ticks_per_second);
        addChild(_grid);
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    }
}
