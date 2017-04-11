module ddebug.gdb.gdbinterface;

public import ddebug.common.debugger;
import ddebug.common.execution;
import dlangui.core.logger;
import ddebug.common.queue;
import dlangide.builders.extprocess;
import ddebug.gdb.gdbmiparser;
import std.utf;
import std.conv : to;
import std.array : empty;
import std.algorithm : startsWith, endsWith, equal;
import core.thread;

abstract class ConsoleDebuggerInterface : DebuggerBase, TextWriter {
    protected ExternalProcess _debuggerProcess;

    protected ExternalProcessState runDebuggerProcess(string executable, string[]args, string dir) {
        _debuggerProcess = new ExternalProcess();
        ExternalProcessState state = _debuggerProcess.run(executable, args, dir, this);
        return state;
    }

    private string[] _stdoutLines;
    private char[] _stdoutBuf;
    /// return true to clear lines list
    protected bool onDebuggerStdoutLines(string[] lines) {
        foreach(line; lines) {
            onDebuggerStdoutLine(line);
        }
        return true;
    }
    protected void onDebuggerStdoutLine(string line) {
    }
    private void onStdoutText(string text) {
        Log.v("onStdoutText: ", text);
        _stdoutBuf ~= text;
        // pass full lines
        int startPos = 0;
        bool fullLinesFound = false;
        for (int i = 0; i < _stdoutBuf.length; i++) {
            if (_stdoutBuf[i] == '\n' || _stdoutBuf[i] == '\r') {
                if (i <= startPos)
                    _stdoutLines ~= "";
                else
                    _stdoutLines ~= _stdoutBuf[startPos .. i].dup;
                fullLinesFound = true;
                if (i + 1 < _stdoutBuf.length) {
                    if ((_stdoutBuf[i] == '\n' && _stdoutBuf[i + 1] == '\r')
                            || (_stdoutBuf[i] == '\r' && _stdoutBuf[i + 1] == '\n'))
                        i++;
                }
                startPos = i + 1;
            }
        }
        if (fullLinesFound) {
            //Log.v("onStdoutText: full lines found");
            for (int i = 0; i + startPos < _stdoutBuf.length; i++)
                _stdoutBuf[i] = _stdoutBuf[i + startPos];
            _stdoutBuf.length = _stdoutBuf.length - startPos;
            if (onDebuggerStdoutLines(_stdoutLines)) {
                _stdoutLines.length = 0;
            }
        }
    }

    bool sendLine(string text) {
        return _debuggerProcess.write(text ~ "\n");
    }

    /// log lines
    override void writeText(dstring text) {
        string text8 = toUTF8(text);
        postRequest(delegate() {
                onStdoutText(text8);
        });
    }

}

interface TextCommandTarget {
    /// send command as a text string
    int sendCommand(string text, int commandId = 0);
    /// reserve next command id
    int reserveCommandId();
}

import std.process;
class GDBInterface : ConsoleDebuggerInterface, TextCommandTarget {

    this() {
        _requests.setTarget(this);
    }

    // last command id
    private int _commandId;

    int reserveCommandId() {
        _commandId++;
        return _commandId;
    }

    int sendCommand(string text, int id = 0) {
        ExternalProcessState state = _debuggerProcess.poll();
        if (state != ExternalProcessState.Running) {
            _stopRequested = true;
            return 0;
        }
        if (!id)
            id = reserveCommandId();
        string cmd = to!string(id) ~ text;
        Log.d("GDB command[", id, "]> ", text);
        sendLine(cmd);
        return id;
    }

    Pid terminalPid;
    string externalTerminalTty;

    string startTerminal() {
        if (!_terminalTty.empty)
            return _terminalTty;
        Log.d("Starting terminal ", _terminalExecutable);
        import std.random;
        import std.file;
        import std.path;
        import std.string;
        import core.thread;
        uint n = uniform(0, 0x10000000, rndGen());
        externalTerminalTty = null;
        string termfile = buildPath(tempDir, format("dlangide-term-name-%07x.tmp", n));
        Log.d("temp file for tty name: ", termfile);
        try {
            string[] args = [
                _terminalExecutable,
                "-title",
                "DLangIDE External Console",
                "-e",
                "echo 'DlangIDE External Console' && tty > " ~ termfile ~ " && sleep 1000000"
            ];
            Log.d("Terminal command line: ", args);
            terminalPid = spawnProcess(args);
            for (int i = 0; i < 80; i++) {
                Thread.sleep(dur!"msecs"(100));
                if (!isTerminalActive) {
                    Log.e("Failed to get terminal TTY");
                    return null;
                }
                if (exists(termfile)) {
                    Thread.sleep(dur!"msecs"(20));
                    break;
                }
            }
            // read TTY from file
            if (exists(termfile)) {
                externalTerminalTty = readText(termfile);
                if (externalTerminalTty.endsWith("\n"))
                    externalTerminalTty = externalTerminalTty[0 .. $-1];
                // delete file
                remove(termfile);
                Log.d("Terminal tty: ", externalTerminalTty);
            }
        } catch (Exception e) {
            Log.e("Failed to start terminal ", e);
            killTerminal();
        }
        if (externalTerminalTty.length == 0) {
            Log.i("Cannot start terminal");
            killTerminal();
        } else {
            Log.i("Terminal: ", externalTerminalTty);
        }
        return externalTerminalTty;
    }

    bool isTerminalActive() {
        if (!_terminalTty.empty)
            return true;
        if (_terminalExecutable.empty)
            return true;
        if (terminalPid is null)
            return false;
        auto res = tryWait(terminalPid);
        if (res.terminated) {
            Log.d("isTerminalActive: Terminal is stopped");
            wait(terminalPid);
            terminalPid = Pid.init;
            return false;
        } else {
            return true;
        }
    }

    void killTerminal() {
        if (!_terminalTty.empty)
            return;
        if (_terminalExecutable.empty)
            return;
        if (terminalPid is null)
            return;
        try {
            Log.d("Trying to kill terminal");
            kill(terminalPid, 9);
            Log.d("Waiting for terminal process termination");
            wait(terminalPid);
            terminalPid = Pid.init;
            Log.d("Killed");
        } catch (Exception e) {
            Log.d("Exception while killing terminal", e);
            terminalPid = Pid.init;
        }
    }

    override void startDebugging() {
        Log.d("GDBInterface.startDebugging()");
        string[] debuggerArgs;
        if (!_terminalExecutable.empty || !_terminalTty.empty) {
            externalTerminalTty = startTerminal();
            if (externalTerminalTty.length == 0) {
                //_callback.onResponse(ResponseCode.CannotRunDebugger, "Cannot start terminal");
                _status = ExecutionStatus.Error;
                _stopRequested = true;
                return;
            }
            if (!USE_INIT_SEQUENCE) {
                debuggerArgs ~= "-tty";
                debuggerArgs ~= externalTerminalTty;
            }
        }
        debuggerArgs ~= "--interpreter";
        debuggerArgs ~= "mi2";
        debuggerArgs ~= "--silent";
        if (!USE_INIT_SEQUENCE) {
            debuggerArgs ~= "--args";
            debuggerArgs ~= _executableFile;
            foreach(arg; _executableArgs)
                debuggerArgs ~= arg;
        }
        ExternalProcessState state = runDebuggerProcess(_debuggerExecutable, debuggerArgs, _executableWorkingDir);
        Log.i("Debugger process state:", state);
        if (USE_INIT_SEQUENCE) {
            if (state == ExternalProcessState.Running) {
                submitInitRequests();
            } else {
                _status = ExecutionStatus.Error;
                _stopRequested = true;
                return;
            }
        } else {
            if (state == ExternalProcessState.Running) {
                Thread.sleep(dur!"seconds"(1));
                _callback.onProgramLoaded(true, true);
                //sendCommand("-break-insert main");
            } else {
                _status = ExecutionStatus.Error;
                _stopRequested = true;
                return;
            }
        }
    }

    immutable bool USE_INIT_SEQUENCE = true;

    override protected void onDebuggerThreadFinished() {
        Log.d("Debugger thread finished");
        if (_debuggerProcess !is null) {
            Log.d("Killing debugger process");
            _debuggerProcess.kill();
            Log.d("Waiting for debugger process finishing");
            //_debuggerProcess.wait();
        }
        killTerminal();
        Log.d("Sending execution status");
        _callback.onProgramExecutionStatus(this, _status, _exitCode);
    }

    bool _threadJoined = false;
    override void stop() {
        if (_stopRequested) {
            Log.w("GDBInterface.stop() - _stopRequested flag already set");
            return;
        }
        _stopRequested = true;
        Log.d("GDBInterface.stop()");
        postRequest(delegate() {
            Log.d("GDBInterface.stop() processing in queue");
            execStop();
        });
        Thread.sleep(dur!"msecs"(200));
        postRequest(delegate() {
        });
        _queue.close();
        if (!_threadJoined) {
            _threadJoined = true;
            if (_threadStarted) {
                try {
                    join();
                } catch (Exception e) {
                    Log.e("Exception while trying to join debugger thread");
                }
            }
        }
    }

    /// start program execution, can be called after program is loaded
    int _startRequestId;
    void execStart() {
        submitRequest("handle SIGUSR1 nostop noprint");
        submitRequest("handle SIGUSR2 nostop noprint");
        _startRequestId = submitRequest("-exec-run");
    }

    void execAbort() {
        _startRequestId = submitRequest("-exec-abort");
    }

    /// start program execution, can be called after program is loaded
    int _continueRequestId;
    void execContinue() {
        _continueRequestId = submitRequest("-exec-continue");
    }

    /// stop program execution
    int _stopRequestId;
    void execStop() {
        _continueRequestId = submitRequest("-gdb-exit");
    }
    /// interrupt execution
    int _pauseRequestId;
    void execPause() {
        _pauseRequestId = submitRequest("-exec-interrupt", true);
    }

    /// step over
    int _stepOverRequestId;
    void execStepOver(ulong threadId) {
        _stepOverRequestId = submitRequest("-exec-next".appendThreadParam(threadId));
    }
    /// step in
    int _stepInRequestId;
    void execStepIn(ulong threadId) {
        _stepInRequestId = submitRequest("-exec-step".appendThreadParam(threadId));
    }
    /// step out
    int _stepOutRequestId;
    void execStepOut(ulong threadId) {
        _stepOutRequestId = submitRequest("-exec-finish".appendThreadParam(threadId));
    }
    /// restart
    int _restartRequestId;
    void execRestart() {
        //_restartRequestId = sendCommand("-exec-restart");
    }

    private GDBBreakpoint[] _breakpoints;
    private static class GDBBreakpoint {
        Breakpoint bp;
        string number;
        int createRequestId;
    }
    private GDBBreakpoint findBreakpoint(Breakpoint bp) {
        foreach(gdbbp; _breakpoints) {
            if (gdbbp.bp.id == bp.id)
                return gdbbp;
        }
        return null;
    }

    private GDBBreakpoint findBreakpointByNumber(string number) {
        if (number.empty)
            return null;
        foreach(gdbbp; _breakpoints) {
            if (gdbbp.number.equal(number))
                return gdbbp;
        }
        return null;
    }

    static string quotePathIfNeeded(string s) {
        char[] buf;
        buf.assumeSafeAppend();
        bool hasSpaces = false;
        for(uint i = 0; i < s.length; i++) {
            if (s[i] == ' ')
                hasSpaces = true;
        }
        if (hasSpaces)
            buf ~= '\"';
        for(uint i = 0; i < s.length; i++) {
            char ch = s[i];
            if (ch == '\t')
                buf ~= "\\t";
            else if (ch == '\n')
                buf ~= "\\n";
            else if (ch == '\r')
                buf ~= "\\r";
            else if (ch == '\\')
                buf ~= "\\\\";
            else 
                buf ~= ch;
        }
        if (hasSpaces)
            buf ~= '\"';
        return buf.dup;
    }

    class AddBreakpointRequest : GDBRequest {
        GDBBreakpoint gdbbp;
        this(Breakpoint bp) { 
            gdbbp = new GDBBreakpoint();
            gdbbp.bp = bp;
            char[] cmd;
            cmd ~= "-break-insert ";
            if (!bp.enabled)
                cmd ~= "-d "; // create disabled
            cmd ~= quotePathIfNeeded(bp.fullFilePath);
            cmd ~= ":";
            cmd ~= to!string(bp.line);
            command = cmd.dup; 
            _breakpoints ~= gdbbp;
        }

        override void onResult() {
            if (MIValue bkpt = params["bkpt"]) {
                string number = bkpt.getString("number");
                gdbbp.number = number;
                Log.d("GDB number for breakpoint " ~ gdbbp.bp.id.to!string ~ " assigned is " ~ number);
            }
        }
    }

    /// update list of breakpoints
    void setBreakpoints(Breakpoint[] breakpoints) {
        char[] breakpointsToDelete;
        char[] breakpointsToEnable;
        char[] breakpointsToDisable;
        // checking for removed breakpoints
        for (int i = cast(int)_breakpoints.length - 1; i >= 0; i--) {
            bool found = false;
            foreach(bp; breakpoints)
                if (bp.id == _breakpoints[i].bp.id) {
                    found = true;
                    break;
                }
            if (!found) {
                for (int j = i; j < _breakpoints.length - 1; j++)
                    _breakpoints[j] = _breakpoints[j + 1];
                if (breakpointsToDelete.length)
                    breakpointsToDelete ~= ",";
                breakpointsToDelete ~= _breakpoints[i].number;
                _breakpoints.length = _breakpoints.length - 1;
            }
        }
        // checking for added or updated breakpoints
        foreach(bp; breakpoints) {
            GDBBreakpoint existing = findBreakpoint(bp);
            if (!existing) {
                submitRequest(new AddBreakpointRequest(bp));
            } else {
                if (bp.enabled && !existing.bp.enabled) {
                    if (breakpointsToEnable.length)
                        breakpointsToEnable ~= ",";
                    breakpointsToEnable ~= existing.number;
                    existing.bp.enabled = true;
                } else if (!bp.enabled && existing.bp.enabled) {
                    if (breakpointsToDisable.length)
                        breakpointsToDisable ~= ",";
                    breakpointsToDisable ~= existing.number;
                    existing.bp.enabled = false;
                }
            }
        }
        if (breakpointsToDelete.length) {
            Log.d("Deleting breakpoints: " ~ breakpointsToDelete);
            submitRequest(("-break-delete " ~ breakpointsToDelete).dup);
        }
        if (breakpointsToEnable.length) {
            Log.d("Enabling breakpoints: " ~ breakpointsToEnable);
            submitRequest(("-break-enable " ~ breakpointsToEnable).dup);
        }
        if (breakpointsToDisable.length) {
            Log.d("Disabling breakpoints: " ~ breakpointsToDisable);
            submitRequest(("-break-disable " ~ breakpointsToDisable).dup);
        }
    }


    // ~message
    void handleStreamLineCLI(string s) {
        Log.d("GDB CLI: ", s);
        if (s.length >= 2 && s.startsWith('\"') && s.endsWith('\"'))
            s = parseCString(s);
        _callback.onDebuggerMessage(s);
    }

    // @message
    void handleStreamLineProgram(string s) {
        Log.d("GDB program stream: ", s);
        //_callback.onDebuggerMessage(s);
    }

    // &message
    void handleStreamLineGDBDebug(string s) {
        Log.d("GDB internal debug message: ", s);
    }

    long _stoppedThreadId = 0;

    // *stopped,reason="exited-normally"
    // *running,thread-id="all"
    // *asyncclass,result
    void handleExecAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        MIValue params = parseMI(s);
        if (!params) {
            Log.e("Failed to parse exec state params");
            return;
        }
        Log.v("GDB async *[", token, "] ", msgType, " params: ", params.toString);
        string reason = params.getString("reason");
        if (msgId == AsyncClass.running) {
            _callback.onDebugState(DebuggingState.running, StateChangeReason.unknown, null, null);
        } else if (msgId == AsyncClass.stopped) {
            StateChangeReason reasonId = StateChangeReason.unknown;
            DebugFrame location = parseFrame(params["frame"]);
            string threadId = params.getString("thread-id");
            _stoppedThreadId = params.getUlong("thread-id", 0);
            string stoppedThreads = params.getString("all");
            Breakpoint bp = null;
            if (reason.equal("end-stepping-range")) {
                updateState();
                _callback.onDebugState(DebuggingState.paused, StateChangeReason.endSteppingRange, location, bp);
            } else if (reason.equal("breakpoint-hit")) {
		        Log.v("handling breakpoint-hit");
                if (GDBBreakpoint gdbbp = findBreakpointByNumber(params.getString("bkptno"))) {
                    bp = gdbbp.bp;
                    if (!location && bp) {
                        location = new DebugFrame();
                        location.fillMissingFields(bp);
                    }
                }
                //_requests.targetIsReady();
                updateState();
                _callback.onDebugState(DebuggingState.paused, StateChangeReason.breakpointHit, location, bp);
            } else if (reason.equal("signal-received")) {
                //_requests.targetIsReady();
                updateState();
                _callback.onDebugState(DebuggingState.paused, StateChangeReason.exception, location, bp);
            } else if (reason.equal("exited-normally")) {
                _exitCode = 0;
                Log.i("Program exited. Exit code ", _exitCode);
                _callback.onDebugState(DebuggingState.stopped, StateChangeReason.exited, null, null);
            } else if (reason.equal("exited")) {
                _exitCode = params.getInt("exit-code");
                Log.i("Program exited. Exit code ", _exitCode);
                _callback.onDebugState(DebuggingState.stopped, StateChangeReason.exited, null, null);
            } else if (reason.equal("exited-signalled")) {
                _exitCode = -2; //params.getInt("exit-code");
                string signalName = params.getString("signal-name");
                string signalMeaning = params.getString("signal-meaning");
                Log.i("Program exited by signal. Signal code: ", signalName, " Signal meaning: ", signalMeaning);
                _callback.onDebugState(DebuggingState.stopped, StateChangeReason.exited, null, null);
            } else {
                _exitCode = -1;
                _callback.onDebugState(DebuggingState.stopped, StateChangeReason.exited, null, null);
            }
        } else {
	        Log.e("unknown async type `", msgType, "`");
        }
    }

    int _stackListLocalsRequest;
    DebugThreadList _currentState;
    void updateState() {
        _currentState = null;
        submitRequest(new ThreadInfoRequest());
    }

    // +asyncclass,result
    void handleStatusAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        Log.v("GDB async +[", token, "] ", msgType, " params: ", s);
    }

    // =asyncclass,result
    void handleNotifyAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        Log.v("GDB async =[", token, "] ", msgType, " params: ", s);
    }

    // ^resultClass,result
    void handleResultMessage(uint token, string s) {
        Log.v("GDB result ^[", token, "] ", s);
        string msgType = parseIdentAndSkipComma(s);
        ResultClass msgId = resultByName(msgType);
        if (msgId == ResultClass.other)
            Log.d("GDB WARN unknown result class type: ", msgType);
        MIValue params = parseMI(s);
        Log.v("GDB result ^[", token, "] ", msgType, " params: ", (params ? params.toString : "unparsed: " ~ s));
        if (_requests.handleResult(token, msgId, params)) {
            // handled using result list
        } else {
            Log.w("received results for unknown request");
        }
    }

    GDBRequestList _requests;
    /// submit single request or request chain
    void submitRequest(GDBRequest[] requests ... ) {
        for (int i = 0; i + 1 < requests.length; i++)
            requests[i].chain(requests[i + 1]);
        _requests.submit(requests[0]);
    }

    /// submit simple text command request
    int submitRequest(string text, bool forceNoWaitDebuggerReady = false) {
        auto request = new GDBRequest(text);
        _requests.submit(request, forceNoWaitDebuggerReady);
        return request.id;
    }

    /// request stack trace and local vars for thread and frame
    void requestDebugContextInfo(ulong threadId, int frame) {
        Log.d("requestDebugContextInfo threadId=", threadId, " frame=", frame);
        submitRequest(new StackListFramesRequest(threadId, frame));
    }

    private int initRequestsSuccessful = 0;
    private int initRequestsError = 0;
    private int initRequestsWarnings = 0;
    private int totalInitRequests = 0;
    private int finishedInitRequests = 0;
    class GDBInitRequest : GDBRequest {
        bool _mandatory;
        this(string cmd, bool mandatory) { 
            command = cmd; 
            _mandatory = mandatory;
            totalInitRequests++;
        }

        override void onOtherResult() {
            initRequestsSuccessful++;
            finishedInitRequests++;
            checkFinished();
        }
        
        override void onResult() {
            initRequestsSuccessful++;
            finishedInitRequests++;
            checkFinished();
        }

        /// called if resultClass is error
        override void onError() {
            if (_mandatory)
                initRequestsError++;
            else
                initRequestsWarnings++;
            finishedInitRequests++;
            checkFinished();
        }

        void checkFinished() {
            if (initRequestsError)
                initRequestsCompleted(false);
            else if (finishedInitRequests == totalInitRequests)
                initRequestsCompleted(true);
        }
    }

    void initRequestsCompleted(bool successful = true) {
        Log.d("Init sequence complection result: ", successful);
        if (successful) {
            // ok
            _callback.onProgramLoaded(true, true);
        } else {
            // error
            _requests.cancelPendingRequests();
            _status = ExecutionStatus.Error;
            _stopRequested = true;
        }
    }

    void submitInitRequests() {
        initRequestsSuccessful = 0;
        initRequestsError = 0;
        totalInitRequests = 0;
        initRequestsWarnings = 0;
        finishedInitRequests = 0;
        submitRequest(new GDBInitRequest("-environment-cd " ~ quotePathIfNeeded(_executableWorkingDir), true));
        if (externalTerminalTty)
            submitRequest(new GDBInitRequest("-inferior-tty-set " ~ quotePathIfNeeded(externalTerminalTty), true));
        
        submitRequest(new GDBInitRequest("-gdb-set breakpoint pending on", false));
        //submitRequest(new GDBInitRequest("-enable-pretty-printing", false));
        submitRequest(new GDBInitRequest("-gdb-set print object on", false));
        submitRequest(new GDBInitRequest("-gdb-set print sevenbit-strings on", false));
        submitRequest(new GDBInitRequest("-gdb-set host-charset UTF-8", false));
        //11-gdb-set target-charset WINDOWS-1252
        //12-gdb-set target-wide-charset UTF-16
        //13source .gdbinit
        submitRequest(new GDBInitRequest("-gdb-set target-async off", false));
        submitRequest(new GDBInitRequest("-gdb-set auto-solib-add on", false));
        if (_executableArgs.length) {
            char[] buf;
            for(uint i = 0; i < _executableArgs.length; i++) {
                if (i > 0) 
                    buf ~= " ";
                buf ~= quotePathIfNeeded(_executableArgs[i]);
            }
            submitRequest(new GDBInitRequest(("-exec-arguments " ~ buf).dup, true));
        }
        submitRequest(new GDBInitRequest("-file-exec-and-symbols " ~ quotePathIfNeeded(_executableFile), true));

        //debuggerArgs ~= _executableFile;
        //foreach(arg; _executableArgs)
        //    debuggerArgs ~= arg;
        //ExternalProcessState state = runDebuggerProcess(_debuggerExecutable, debuggerArgs, _executableWorkingDir);
        //17-gdb-show language
        //18-gdb-set language c
        //19-interpreter-exec console "p/x (char)-1"
        //20-data-evaluate-expression "sizeof (void*)"
        //21-gdb-set language auto

    }

    class ThreadInfoRequest : GDBRequest {
        this() { command = "-thread-info"; }
        override void onResult() {
            _currentState = parseThreadList(params);
			if (_currentState) {
                // TODO
                Log.d("Thread list is parsed");
                if (!_currentState.currentThreadId)
                	_currentState.currentThreadId = _stoppedThreadId;
                submitRequest(new StackListFramesRequest(_currentState.currentThreadId, 0));
            }
        }
    }

    class StackListFramesRequest : GDBRequest {
        private ulong _threadId;
        private int _frameId;
        this(ulong threadId, int frameId) {
            _threadId = threadId;
            _frameId = frameId;
            if (!_threadId)
                _threadId = _currentState ? _currentState.currentThreadId : 0;
            command = "-stack-list-frames --thread " ~ to!string(_threadId); 
        }
        override void onResult() {
            DebugStack stack = parseStack(params);
            if (stack) {
                // TODO
                Log.d("Stack frames list is parsed: " ~ to!string(stack));
                if (_currentState) {
                    if (DebugThread currentThread = _currentState.findThread(_threadId)) {
                        currentThread.stack = stack;
                        Log.d("Setting stack frames for current thread");
                    }
                    submitRequest(new LocalVariableListRequest(_threadId, _frameId));
                }
            }
        }
    }

    class LocalVariableListRequest : GDBRequest {
        ulong _threadId;
        int _frameId;
        this(ulong threadId, int frameId) {
            _threadId = threadId;
            _frameId = frameId;
            //command = "-stack-list-variables --thread " ~ to!string(_threadId) ~ " --frame " ~ to!string(_frameId) ~ " --simple-values"; 
            command = "-stack-list-locals --thread " ~ to!string(_threadId) ~ " --frame " ~ to!string(_frameId) ~ " 1"; 
        }
        override void onResult() {
            DebugVariableList variables = parseVariableList(params, "locals");
            if (variables) {
                // TODO
                Log.d("Variable list is parsed: " ~ to!string(variables));
                if (_currentState) {
                    if (DebugThread currentThread = _currentState.findThread(_threadId)) {
                        if (currentThread.length > 0) {
                            if (_frameId > currentThread.length)
                                _frameId = 0;
                            if (_frameId < currentThread.length)
                                currentThread[_frameId].locals = variables;
                            Log.d("Setting variables for current thread top frame");
                            _callback.onDebugContextInfo(_currentState.clone(), _threadId, _frameId);
                        }
                    }
                }
            }
        }
    }

    bool _firstIdle = true;
    // (gdb)
    void onDebuggerIdle() {
        Log.d("GDB idle");
        _requests.targetIsReady();
        if (_firstIdle) {
            _firstIdle = false;
            return;
        }
    }

    override protected void onDebuggerStdoutLine(string gdbLine) {
        Log.d("GDB stdout: '", gdbLine, "'");
        string line = gdbLine;
        if (line.empty)
            return;
        // parse token (sequence of digits at the beginning of message)
        uint tokenId = 0;
        int tokenLen = 0;
        while (tokenLen < line.length && line[tokenLen] >= '0' && line[tokenLen] <= '9')
            tokenLen++;
        if (tokenLen > 0) {
            tokenId = to!uint(line[0..tokenLen]);
            line = line[tokenLen .. $];
        }
        if (line.length == 0)
            return; // token only, no message!
        char firstChar = line[0];
        string restLine = line.length > 1 ? line[1..$] : "";
        if (firstChar == '~') {
            handleStreamLineCLI(restLine);
            return;
        } else if (firstChar == '@') {
            handleStreamLineProgram(restLine);
            return;
        } else if (firstChar == '&') {
            handleStreamLineGDBDebug(restLine);
            return;
        } else if (firstChar == '*') {
            handleExecAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '+') {
            handleStatusAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '=') {
            handleNotifyAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '^') {
            handleResultMessage(tokenId, restLine);
            return;
        } else if (line.startsWith("(gdb)")) {
            onDebuggerIdle();
            return;
        } else {
            Log.d("GDB unprocessed: ", gdbLine);
        }
    }

}


class GDBRequest {
    int id;
    string command;
    ResultClass resultClass;
    MIValue params;
    GDBRequest next;

    this() {
    }

    this(string cmdtext) {
        command = cmdtext;
    }

    /// called if resultClass is done
    void onResult() {
    }
    /// called if resultClass is error
    void onError() {
    }
    /// called on other result types
    void onOtherResult() {
    }

    /// chain additional request, for case when previous finished ok
    GDBRequest chain(GDBRequest next) {
        this.next = next;
        return this;
    }
}

struct GDBRequestList {

    private bool _synchronousMode = false;

    void setSynchronousMode(bool flg) {
        _synchronousMode = flg;
        _ready = _ready | _synchronousMode;
    }

    private TextCommandTarget _target;
    private GDBRequest[int] _activeRequests;
    private GDBRequest[] _pendingRequests;

    private bool _ready = false;

    void setTarget(TextCommandTarget target) {
        _target = target;
    }

    private void executeRequest(GDBRequest request) {
        request.id = _target.sendCommand(request.command, request.id);
        if (request.id)
            _activeRequests[request.id] = request;
    }

    int submit(GDBRequest request, bool forceNoWaitDebuggerReady = false) {
        if (!request.id)
            request.id = _target.reserveCommandId();
        if (Log.traceEnabled)
            Log.v("submitting request " ~ to!string(request.id) ~ " " ~ request.command);
        if (_ready || _synchronousMode || forceNoWaitDebuggerReady) {
            if (!forceNoWaitDebuggerReady)
                _ready = _synchronousMode;
            executeRequest(request);
        } else
            _pendingRequests ~= request;
        return request.id;
    }

    // (gdb) prompt received
    void targetIsReady() {
        _ready = true;
        if (_pendingRequests.length) {
            // execute next pending request
            GDBRequest next = _pendingRequests[0];
            for (uint i = 0; i + 1 < _pendingRequests.length; i++)
                _pendingRequests[i] = _pendingRequests[i + 1];
            _pendingRequests[$ - 1] = null;
            _pendingRequests.length = _pendingRequests.length - 1;
            executeRequest(next);
        }
    }

    void cancelPendingRequests() {
        foreach(ref r; _pendingRequests)
            r = null; // just to help GC
        _pendingRequests.length = 0;
    }

    bool handleResult(int token, ResultClass resultClass, MIValue params) {
        if (token in _activeRequests) {
            GDBRequest r = _activeRequests[token];
            _activeRequests.remove(token);
            r.resultClass = resultClass;
            r.params = params;
            if (resultClass == ResultClass.done) {
                r.onResult();
                if (r.next)
                    submit(r.next);
            } else if (resultClass == ResultClass.error) {
                r.onError();
            } else {
                r.onOtherResult();
            }
            return true;
        }
        return false;
    }
}

/// appends --thread parameter to command text if threadId != 0
string appendThreadParam(string src, ulong threadId) {
    if (!threadId)
        return src;
    return src ~= " --thread " ~ to!string(threadId);
}
