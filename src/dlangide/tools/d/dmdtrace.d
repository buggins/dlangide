/// DMD trace.log parser
module dlangide.tools.d.dmdtrace;

/*
Based on d-profile-viewer: https://bitbucket.org/andrewtrotman/d-profile-viewer

Copyright (c) 2015-2016 eBay Software Foundation
Written by Andrew Trotman
Licensed under the 3-clause BSD license (see here:https://en.wikipedia.org/wiki/BSD_licenses)

*/


import dlangui.core.logger;
//import core.stdc.stdlib;
import std.file;
import std.stdio;
import std.string;
//import dlangide.tools.d.demangle;
import core.runtime;
import std.conv;
import std.algorithm;
import std.exception;
//import std.demangle;
import dlangide.ui.outputpanel;
import dlangide.builders.extprocess;
import dlangui.widgets.appframe;
import core.thread;

enum TraceSortOrder {
    BY_FUNCTION_TIME,
    BY_TOTAL_TIME,
    BY_CALL_COUNT,
    BY_NAME,
}

void sortFunctionNodes(FunctionNode[] nodes, TraceSortOrder sortOrder) {
    import std.algorithm.sorting : sort;
    final switch(sortOrder) {
        case TraceSortOrder.BY_FUNCTION_TIME:
            sort!((a,b) => a.function_time > b.function_time)(nodes);
            break;
        case TraceSortOrder.BY_TOTAL_TIME:
            sort!((a,b) => a.function_and_descendant_time > b.function_and_descendant_time)(nodes);
            break;
        case TraceSortOrder.BY_CALL_COUNT:
            sort!((a,b) => a.number_of_calls > b.number_of_calls)(nodes);
            break;
        case TraceSortOrder.BY_NAME:
            sort!((a,b) => a.name < b.name)(nodes);
            break;
    }
}

class DMDTraceLogParser {
    private string filename;
    private string content;
    private string[] lines;
    private bool _cancelRequested;

    FunctionNode[string] nodes;
    FunctionNode[] nodesByFunctionTime;
    FunctionNode[] nodesByTotalTime;
    FunctionNode[] nodesByCallCount;
    FunctionNode[] nodesByName;
    //FunctionEdge[string] caller_graph;
    //FunctionEdge[string] called_graph;
    ulong ticks_per_second;

    this(string fname) {
        filename = fname;
    }
    void requestCancel() {
        _cancelRequested = true;
    }
    private void splitLines(void[] buffer) {
        lines.assumeSafeAppend;
        content = cast(string)buffer;
        int lineStart = 0;
        for (int i = 0; i < content.length; i++) {
            char ch = content.ptr[i];
            if (ch == '\r' || ch == '\n') {
                if (lineStart < i) {
                    lines ~= content[lineStart .. i];
                }
                lineStart = i + 1;
            }
        }
        // append last line if any
        if (lineStart < content.length)
            lines ~= content[lineStart .. $];
    }
    bool load() {
        void[] file;
        try
        {
            file = read(filename);
        }
        catch (Exception ex)
        {
            Log.e("Cannot open trace file ", filename);
            return false;
        }
        if (file.length == 0) {
            Log.e("Trace log ", filename, " is empty");
            return false;
        }
        Log.d("Opened file ", filename, " ", file.length, " bytes");
        splitLines(file);
        Log.d("Lines: ", lines.length);
        return lines.length > 0;
    }
    bool parse() {
        bool caller = true;
        string function_name;
        FunctionEdge[string] caller_graph;
        FunctionEdge[string] called_graph;
        ulong function_times;
        ulong function_and_descendant;
        ulong function_only;
        foreach(i, line; lines) {
            if (_cancelRequested)
                return false;
            if (line.length == 0) {
                continue; // Ignore blank lines
            } else if (line[0] == '=') { // Seperator between call graph and summary data
                auto number = indexOfAny(line, "1234567890");
                if (number < 0)
                {
                    Log.e("Corrupt trace.log (can't compute ticks per second), please re-profile and try again");
                    return false;
                }
                auto space = indexOf(line[number .. $], ' ') + number;
                ticks_per_second = to!ulong(line[number .. space]);
                break;
            } else if (line[0] == '-') { //Seperator between each function call graph
                caller = true;
                if (function_name.length != 0)
                    nodes[text(function_name)] = new FunctionNode(function_name,
                                                                  function_times, function_and_descendant, function_only,
                                                                  caller_graph, called_graph);
                caller_graph = null;
                called_graph = null;
            } else if (line[0] == '\t')
            {
                // A function either calling or called by this function
                /*
				We can't assume a name starts with an '_' because it might be an extern "C" which hasn't been mangled.
				We also can't assume the character encodin of what ever language that is so we look for the last tab
				and asusme the identifier starts on the next character.
                */
                //            auto pos = indexOfAny(line, "_");
                auto pos = lastIndexOf(line, '\t') + 1;
                auto start_pos = indexOfAny(line, "1234567890");
                if (start_pos < 0 || pos < 0 || pos < start_pos)
                {
                    Log.e("Corrupt trace.log (call count is non-numeric), please re-profile and try again");
                    return false;
                }
                immutable times = to!ulong(line[start_pos .. pos - 1]);
                auto name = line[pos .. $];
                if (caller)
                {
                    caller_graph[text(name)] = new FunctionEdge(name, times);
                }
                else
                {
                    called_graph[text(name)] = new FunctionEdge(name, times);
                }
            }
            /*
			In the case of a call to a non-D function, the identifier might not start with an '_' (e.g. extern "C").  But, we can't know
			how those identifiers are stored so we can't assume an encoding - and hence we must assume that what ever we have is correct.
            */
            //      else if (indexOf("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", line[0]) >= 0) //The name of the function were're currently examining the call graph for (seperates callers from called)
            else //The name of the function were're currently examining the call graph for (seperates callers from called)
            {
                auto start_tab = indexOf(line, '\t');
                auto middle_tab = indexOf(line[start_tab + 1 .. $], '\t') + start_tab + 1;
                auto last_tab = indexOf(line[middle_tab + 1 .. $], '\t') + middle_tab + 1;
                function_name = line[0 .. start_tab];
                //if (function_name.length > 1024)
                //    Log.d("long function name: ", function_name);
                function_times = to!ulong(line[start_tab + 1 .. middle_tab]);
                function_and_descendant = to!ulong(line[middle_tab + 1 .. last_tab]);
                function_only = to!ulong(line[last_tab + 1 .. $]);
                caller = false;
            }
        }
        if (function_name.length != 0)
        {
            nodes[text(function_name)] = new FunctionNode(function_name,
                                                          function_times, function_and_descendant, function_only, caller_graph, called_graph);
        }
        makeSorted();
        return true;
    }

    void makeSorted() {
        nodesByFunctionTime.reserve(nodes.length);
        foreach(key, value; nodes) {
            nodesByFunctionTime ~= value;
        }
        nodesByTotalTime = nodesByFunctionTime.dup;
        nodesByCallCount = nodesByFunctionTime.dup;
        nodesByName = nodesByFunctionTime.dup;
        sortFunctionNodes(nodesByFunctionTime, TraceSortOrder.BY_FUNCTION_TIME);
        sortFunctionNodes(nodesByTotalTime, TraceSortOrder.BY_TOTAL_TIME);
        sortFunctionNodes(nodesByCallCount, TraceSortOrder.BY_CALL_COUNT);
        sortFunctionNodes(nodesByName, TraceSortOrder.BY_NAME);
    }
}

private __gshared static char[] demangleBuffer;

private string demangle(string mangled_name) {
    import core.demangle : demangle;
    //const (char) [] demangled_name;
    string demangled_name; // = dlangide.tools.d.demangle.demangle(mangled_name);
    //if (demangled_name[0] == '_') { // in the unlikely event that we fail to demangle, fall back to the phobos demangler
        try {
            static import core.demangle;
            if (demangleBuffer.length < mangled_name.length + 16384)
                demangleBuffer.length = mangled_name.length * 2 + 16384;
            demangled_name = cast(string)core.demangle.demangle(mangled_name, demangleBuffer[]);
        } catch (Exception e) {
            demangled_name = mangled_name;
        }
    //}
    if (demangled_name.length > 1024)
        return demangled_name[0..1024] ~ "...";
    return demangled_name.dup;
}

/*
CLASS FUNCTION_EDGE
-------------------
There's one of these objects for each function in program being profiled.
*/
class FunctionEdge
{
public:
    string name; // the demangled name of the function
    string mangled_name; // the mangled name
    ulong calls; // number of times the function is called

public:
    /*
        THIS()
        ------
        Constructor
    */
    this(string mangled_name, ulong calls)
    {
        this.mangled_name = mangled_name;

        this.name = demangle(mangled_name);

        this.calls = calls;
    }
}

/*
CLASS FUNCTION_NODE
-------------------

*/
class FunctionNode
{
public:
    FunctionEdge[string] called_by;
    FunctionEdge[string] calls_to;
    string name;
    string mangled_name;
    ulong number_of_calls;
    ulong function_and_descendant_time; // in cycles
    ulong function_time; // in cycles

private:
    /*
    PERCENT()
    ---------
    Compute top/bottom to 2 decimal places
	*/
    double percent(double top, double bottom)
    {
        return cast(double)(cast(size_t)((top / bottom * 100_00.0))) / 100.0;
    }

    /*
    TO_US()
    -------
    Convert from ticks to micro-seconds
	*/
    size_t to_us(double ticks, double ticks_per_second)
    {
        return cast(size_t)(ticks / ticks_per_second * 1000 * 1000);
    }

public:
    /*
    THIS()
    ------
	*/
    this(string mangled_name, ulong calls, ulong function_and_descendant_time,
         ulong function_time, FunctionEdge[string] called_by, FunctionEdge[string] calls_to)
    {
        this.mangled_name = mangled_name;

        this.name = demangle(mangled_name);

        this.number_of_calls = calls;
        this.function_and_descendant_time = function_and_descendant_time;
        this.function_time = function_time;
        this.called_by = called_by;
        this.calls_to = calls_to;
    }

}

DMDTraceLogParser parseDMDTraceLog(string filename) {
    scope(exit) demangleBuffer = null;
    DMDTraceLogParser parser = new DMDTraceLogParser(filename);
    if (!parser.load())
        return null;
    if (!parser.parse())
        return null;
    return parser;
}

class DMDProfilerLogParserThread : Thread {
    private DMDTraceLogParser _parser;
    private bool _finished;
    private bool _success;

    this(string filename) {
        super(&run);
        _parser = new DMDTraceLogParser(filename);
    }

    @property bool finished() { return _finished; }
    @property DMDTraceLogParser parser() { return _success ? _parser : null; }

    void requestCancel() {
        _parser.requestCancel();
    }
    void run() {
        scope(exit) demangleBuffer = null;
        if (!_parser.load()) {
            _finished = true;
            return;
        }
        if (!_parser.parse()) {
            _finished = true;
            return;
        }
        _success = true;
        _finished = true;
        // Done
    }
}

alias DMDProfilerLogParserListener = void delegate(DMDTraceLogParser parser);

class DMDProfilerLogParserOperation : BackgroundOperationWatcher {

    string _filename;
    DMDProfilerLogParserListener _listener;
    dstring _description;
    DMDProfilerLogParserThread _thread;
    DMDTraceLogParser _result;

    this(AppFrame frame, string filename, OutputPanel log, DMDProfilerLogParserListener listener) {
        super(frame);
        _filename = filename;
        _listener = listener;
        _description = "Parsing DMD trace log file"d;
        _thread = new DMDProfilerLogParserThread(filename);
        _thread.start();
    }

    /// returns description of background operation to show in status line
    override @property dstring description() { return _description; }
    /// returns icon of background operation to show in status line
    override @property string icon() { return "folder"; }
    /// update background operation status
    override void update() {
        if (_finished) {
            return;
        }
        if (_thread.finished) {
            _thread.join();
            _result = _thread.parser;
            //_extprocess.kill();
            //_extprocess.wait();
            _finished = true;
            return;
        }
        if (_cancelRequested) {
            _thread.requestCancel();
            _thread.join();
            _result = _thread.parser;
            //_extprocess.kill();
            //_extprocess.wait();
            _finished = true;
            return;
        }
        super.update();
    }
    override void removing() {
        super.removing();
        //if (_exitCode != int.min && _listener)
        _listener(_result);
    }
}
