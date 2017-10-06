module dlangide.ui.dmdprofilerview;

import dlangui.widgets.layouts;
import dlangui.widgets.widget;
import dlangui.widgets.scroll;
import dlangui.widgets.controls;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangui.core.i18n;
import dlangide.tools.d.dmdtrace;

class DMDProfilerView : ScrollWidget {
    protected IDEFrame _frame;
    protected DMDTraceLogParser _data;
    this(string ID, IDEFrame frame, DMDTraceLogParser data) {
        super(ID);
        _frame = frame;
        _data = data;
        contentWidget = new TextWidget(null, "DMD profiler view"d);
    }
}
