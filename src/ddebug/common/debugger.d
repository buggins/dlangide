module ddebug.common.debugger;

import core.thread;
import dlangui.core.logger;
import ddebug.common.queue;
import ddebug.common.execution;
import std.array : empty;
import std.algorithm : startsWith, endsWith, equal;
import std.string : format;

enum DebuggingState {
    loaded,
    running,
    paused,
    stopped
}

enum StateChangeReason {
    unknown,
    breakpointHit,
    endSteppingRange,
    exception,
    exited,
}

class LocationBase {
    string file;
    string fullFilePath;
    string projectFilePath;
    string from;
    int line;
    this() {}
    this(LocationBase v) {
        file = v.file;
        fullFilePath = v.fullFilePath;
        projectFilePath = v.projectFilePath;
        line = v.line;
        from = v.from;
    }
    LocationBase clone() { return new LocationBase(this); }
}

class Breakpoint : LocationBase {
    int id;
    bool enabled = true;
    string projectName;
    this() {
        id = _nextBreakpointId++;
    }
    this(Breakpoint v) {
        super(v);
        id = v.id;
        enabled = v.enabled;
        projectName = v.projectName;
    }
    override Breakpoint clone() {
        return new Breakpoint(this);
    }
}

class DebugFrame : LocationBase {
    ulong address;
    string func;
    int level;
    DebugVariableList locals;

    @property string formattedAddress() {
        if (address < 0x100000000) {
            return "%08x".format(address);
        } else {
            return "%016x".format(address);
        }
    }

    this() {}
    this(DebugFrame v) {
        super(v);
        address = v.address;
        func = v.func;
        level = v.level;
        if (v.locals)
            locals = new DebugVariableList(v.locals);
    }
    override DebugFrame clone() { return new DebugFrame(this); }

    void fillMissingFields(LocationBase v) {
        if (file.empty)
            file = v.file;
        if (fullFilePath.empty)
            fullFilePath = v.fullFilePath;
        if (projectFilePath.empty)
            projectFilePath = v.projectFilePath;
        if (!line)
            line = v.line;
    }
}

class DebugThread {
    ulong id;
    string name;
    DebugFrame frame;
    DebuggingState state;
    DebugStack stack;

    this() {
    }
    this(DebugThread v) {
        id = v.id;
        name = v.name;
        if (v.frame)
            frame = new DebugFrame(v.frame);
        state = v.state;
        if (v.stack)
            stack = new DebugStack(v.stack);
    }
    DebugThread clone() { return new DebugThread(this); }

    @property string displayName() {
        return "%u: %s".format(id, name);
    }

    @property int length() { 
        if (stack && stack.length > 0)
            return stack.length;
        if (frame)
            return 1;
        return 0; 
    }
    DebugFrame opIndex(int index) { 
        if (index < 0 || index > length)
            return null;
        if (stack && stack.length > 0)
            return stack[index];
        if (frame && index == 0)
            return frame;
        return null; 
    }
}

class DebugThreadList {
    DebugThread[] threads;
    ulong currentThreadId;
    this() {}
    this(DebugThreadList v) {
        currentThreadId = v.currentThreadId;
        foreach(t; v.threads)
            threads ~= new DebugThread(t);
    }
    DebugThreadList clone() { return new DebugThreadList(this); }

    @property DebugThread currentThread() {
        return findThread(currentThreadId);
    }
    DebugThread findThread(ulong id) {
        foreach(t; threads)
            if (t.id == id)
                return t;
        return null;
    }
    @property int length() { return cast(int)threads.length; }
    DebugThread opIndex(int index) { return threads[index]; }
}

class DebugStack {
    DebugFrame[] frames;

    this() {}
    this(DebugStack v) {
        foreach(t; v.frames)
            frames ~= new DebugFrame(t);
    }

    @property int length() { return cast(int)frames.length; }
    DebugFrame opIndex(int index) { return frames[index]; }
}

class DebugVariable {
    string name;
    string type;
    string value;
    DebugVariable[] children;

    this() {}
    /// deep copy
    this(DebugVariable v) {
        name = v.name;
        type = v.type;
        value = v.value;
        // deep copy of child vars
        foreach(item; v.children)
            children ~= new DebugVariable(item);
    }
}

class DebugVariableList {
    DebugVariable[] variables;
    this() {}
    this(DebugVariableList v) {
        foreach(t; v.variables)
            variables ~= new DebugVariable(t);
    }

    @property int length() { return variables ? cast(int)variables.length : 0; }

    DebugVariable opIndex(int index) { 
        if (!variables || index < 0 || index > variables.length)
            return null;
        return variables[index];
    }
}

static __gshared _nextBreakpointId = 1;

interface Debugger : ProgramExecution {
    void setDebuggerCallback(DebuggerCallback callback);
    void setDebuggerExecutable(string debuggerExecutable);

    /// can be called after program is loaded
    void execStart();
    /// continue execution
    void execContinue();
    /// stop program execution
    void execStop();
    /// interrupt execution
    void execPause();
    /// step over
    void execStepOver(ulong threadId);
    /// step in
    void execStepIn(ulong threadId);
    /// step out
    void execStepOut(ulong threadId);
    /// restart
    void execRestart();

    /// update list of breakpoints
    void setBreakpoints(Breakpoint[] bp);

    /// request stack trace and local vars for thread and frame
    void requestDebugContextInfo(ulong threadId, int frame);
}

interface DebuggerCallback : ProgramExecutionStatusListener {
    /// debugger message line
    void onDebuggerMessage(string msg);

    /// debugger is started and loaded program, you can set breakpoints at this time
    void onProgramLoaded(bool successful, bool debugInfoLoaded);

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, StateChangeReason reason, DebugFrame location, Breakpoint bp);

    void onResponse(ResponseCode code, string msg);

    /// send debug context (threads, stack frames, local vars...)
    void onDebugContextInfo(DebugThreadList info, ulong threadId, int frame);
}

enum ResponseCode : int {
    /// Operation finished successfully
    Ok = 0,

    // more success codes here

    /// General purpose failure code
    Fail = 1000,
    /// method is not implemented
    NotImplemented,
    /// error running debugger
    CannotRunDebugger,

    // more error codes here
}

alias Runnable = void delegate();

//interface Debugger {
//    /// start debugging
//    void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response);
//}



/// proxy for debugger interface implementing async calls
class DebuggerProxy : Debugger, DebuggerCallback {
    private DebuggerBase _debugger;
    private void delegate(void delegate() runnable) _callbackDelegate;

    this(DebuggerBase debugger, void delegate(void delegate() runnable) callbackDelegate) {
        _debugger = debugger;
        _callbackDelegate = callbackDelegate;
    }

    /// returns true if it's debugger
    @property bool isDebugger() { return true; }
    /// returns true if it's mago debugger
    @property bool isMagoDebugger() { return _debugger.isMagoDebugger; }

    /// executable file
    @property string executableFile() { return _debugger.executableFile; }
    /// returns execution status
    //@property ExecutionStatus status();

    void setExecutableParams(string executableFile, string[] args, string workingDir, string[string] envVars) {
        _debugger.setExecutableParams(executableFile, args, workingDir, envVars);
    }

    /// set external terminal parameters before execution
    void setTerminalExecutable(string terminalExecutable) {
        _debugger.setTerminalExecutable(terminalExecutable);
    }

    /// set terminal device name before execution
    void setTerminalTty(string terminalTty) {
        _debugger.setTerminalTty(terminalTty);
    }

    /// set debugger executable
    void setDebuggerExecutable(string debuggerExecutable) {
        _debugger.setDebuggerExecutable(debuggerExecutable);
    }

    protected DebuggerCallback _callback;
    /// set debugger callback
    void setDebuggerCallback(DebuggerCallback callback) {
        _callback = callback;
        _debugger.setDebuggerCallback(this);
    }

    /// called when program execution is stopped
    void onProgramExecutionStatus(ProgramExecution process, ExecutionStatus status, int exitCode) {
        DebuggerProxy proxy = this;
        _callbackDelegate( delegate() { _callback.onProgramExecutionStatus(proxy, status, exitCode); } );
    }

    /// debugger is started and loaded program, you can set breakpoints at this time
    void onProgramLoaded(bool successful, bool debugInfoLoaded) {
        _callbackDelegate( delegate() { _callback.onProgramLoaded(successful, debugInfoLoaded); } );
    }

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, StateChangeReason reason, DebugFrame location, Breakpoint bp) {
        _callbackDelegate( delegate() { _callback.onDebugState(state, reason, location, bp); } );
    }

    /// send debug context (threads, stack frames, local vars...)
    void onDebugContextInfo(DebugThreadList info, ulong threadId, int frame) {
        _callbackDelegate( delegate() { _callback.onDebugContextInfo(info, threadId, frame); } );
    }

    void onResponse(ResponseCode code, string msg) {
        _callbackDelegate( delegate() { _callback.onResponse(code, msg); } );
    }

    void onDebuggerMessage(string msg) {
        _callbackDelegate( delegate() { _callback.onDebuggerMessage(msg); } );
    }

    /// start execution
    void run() {
        Log.d("DebuggerProxy.run()");
        _debugger.run();
        //_debugger.postRequest(delegate() { _debugger.run();    });
    }
    /// stop execution
    void stop() {
        Log.d("DebuggerProxy.stop()");
        _debugger.stop();
        //_debugger.postRequest(delegate() { _debugger.stop(); });
    }

    /// start execution, can be called after program is loaded
    void execStart() {
        _debugger.postRequest(delegate() { _debugger.execStart(); });
    }
    /// continue program
    void execContinue() {
        _debugger.postRequest(delegate() { _debugger.execContinue(); });
    }
    /// stop program execution
    void execStop() {
        _debugger.postRequest(delegate() { _debugger.execStop(); });
    }
    /// interrupt execution
    void execPause() {
        _debugger.postRequest(delegate() { _debugger.execPause(); });
    }
    /// step over
    void execStepOver(ulong threadId) {
        _debugger.postRequest(delegate() { _debugger.execStepOver(threadId); });
    }
    /// step in
    void execStepIn(ulong threadId) {
        _debugger.postRequest(delegate() { _debugger.execStepIn(threadId); });
    }
    /// step out
    void execStepOut(ulong threadId) {
        _debugger.postRequest(delegate() { _debugger.execStepOut(threadId); });
    }
    /// restart
    void execRestart() {
        _debugger.postRequest(delegate() { _debugger.execRestart(); });
    }
    /// request stack trace and local vars for thread and frame
    void requestDebugContextInfo(ulong threadId, int frame) {
        _debugger.postRequest(delegate() { _debugger.requestDebugContextInfo(threadId, frame); });
    }
    /// update list of breakpoints
    void setBreakpoints(Breakpoint[] breakpoints) {
        Breakpoint[] cloned;
        foreach(bp; breakpoints)
            cloned ~= bp.clone;
        _debugger.postRequest(delegate() { _debugger.setBreakpoints(cloned); });
    }
}

abstract class DebuggerBase : Thread, Debugger {
    protected bool _runRequested;
    protected bool _stopRequested;
    private bool _finished;
    protected BlockingQueue!Runnable _queue;

    protected ExecutionStatus _status = ExecutionStatus.NotStarted;
    protected int _exitCode = 0;

    /// provides _executableFile, _executableArgs, _executableWorkingDir, _executableEnvVars parameters and setter function setExecutableParams
    mixin ExecutableParams;
    /// provides _terminalExecutable, _terminalTty, setTerminalExecutable, and setTerminalTty
    mixin TerminalParams;

    protected DebuggerCallback _callback;
    void setDebuggerCallback(DebuggerCallback callback) {
        _callback = callback;
    }

    protected string _debuggerExecutable;
    void setDebuggerExecutable(string debuggerExecutable) {
        _debuggerExecutable = debuggerExecutable;
    }

    /// returns true if it's mago debugger
    @property bool isMagoDebugger() {
        import std.string;
        return _debuggerExecutable.indexOf("mago-mi") >= 0;
    }


    @property bool isDebugger() { return true; }

    @property string executableFile() {
        return _executableFile;
    }

    void postRequest(Runnable request) {
        _queue.put(request);
    }

    this() {
        super(&threadFunc);
        _queue = new BlockingQueue!Runnable();
    }

    ~this() {
        //stop();
        //destroy(_queue);
        _queue = null;
    }

    // call from GUI thread
    void run() {
        Log.d("DebuggerBase.run()");
        assert(!_runRequested);
        _runRequested = true;
        postRequest(&startDebugging);
        start();
    }

    void startDebugging() {
        // override to implement
    }

    void stop() {
        Log.i("Debugger.stop()");
        if (_stopRequested)
            return;
        _stopRequested = true;
        _queue.close();
    }

    bool _threadStarted;
    protected void onDebuggerThreadStarted() {
        _threadStarted = true;
    }

    protected void onDebuggerThreadFinished() {
        _callback.onProgramExecutionStatus(this, _status, _exitCode);
    }
    
    /// thread func: execute all tasks from queue
    private void threadFunc() {
        onDebuggerThreadStarted();
        Log.i("Debugger thread started");
        try {
            while (!_stopRequested) {
                Runnable task;
                if (_queue.get(task, 0)) {
                    task();
                }
            }
        } catch (Exception e) {
            Log.e("Exception in debugger thread", e);
        }
        Log.i("Debugger thread finished");
        _finished = true;
        onDebuggerThreadFinished();
    }

}

/// helper for removing class array item by ref
T removeItem(T)(ref T[]array, T item) {
    for (int i = cast(int)array.length - 1; i >= 0; i--) {
        if (array[i] is item) {
            for (int j = i; j < array.length - 1; j++)
                array[j] = array[j + 1];
            array.length = array.length - 1;
            return item;
        }
    }
    return null;
}

/// helper for removing array item by index
T removeItem(T)(ref T[]array, ulong index) {
    if (index >= 0 && index < array.length) {
        T res = array[index];
        for (int j = cast(int)index; j < array.length - 1; j++)
            array[j] = array[j + 1];
        array.length = array.length - 1;
        return res;
    }
    return null;
}

