module ddebug.common.debugger;

import core.thread;
import dlangui.core.logger;
import ddebug.common.queue;
import ddebug.common.execution;

enum DebuggingState {
    loaded,
    running,
    paused,
    stopped
}

class Breakpoint {
    int id;
    string file;
    string fullFilePath;
    string projectFilePath;
    int line;
    bool enabled = true;
    string projectName;
    this() {
        id = _nextBreakpointId++;
    }
    Breakpoint clone() {
        Breakpoint v = new Breakpoint();
        id = v.id;
        file = v.file;
        fullFilePath = v.fullFilePath;
        projectFilePath = v.projectFilePath;
        line = v.line;
        enabled = v.enabled;
        projectName = v.projectName;
        return v;
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
    void execStepOver();
    /// step in
    void execStepIn();
    /// step out
    void execStepOut();

    /// update list of breakpoints
    void setBreakpoints(Breakpoint[] bp);
}

interface DebuggerCallback : ProgramExecutionStatusListener {
    /// debugger message line
    void onDebuggerMessage(string msg);

    /// debugger is started and loaded program, you can set breakpoints at this time
    void onProgramLoaded(bool successful, bool debugInfoLoaded);

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, string msg, int param);

    void onResponse(ResponseCode code, string msg);
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
//	/// start debugging
//	void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response);
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
    void onDebugState(DebuggingState state, string msg, int param) {
		_callbackDelegate( delegate() { _callback.onDebugState(state, msg, param); } );
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
		//_debugger.postRequest(delegate() { _debugger.run();	});
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
    void execStepOver() {
        _debugger.postRequest(delegate() { _debugger.execStepOver(); });
    }
    /// step in
    void execStepIn() {
        _debugger.postRequest(delegate() { _debugger.execStepIn(); });
    }
    /// step out
    void execStepOut() {
        _debugger.postRequest(delegate() { _debugger.execStepOut(); });
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
    /// provides _terminalExecutable and setTerminalExecutable setter
    mixin TerminalParams;

    protected DebuggerCallback _callback;
    void setDebuggerCallback(DebuggerCallback callback) {
        _callback = callback;
    }

    protected string _debuggerExecutable;
    void setDebuggerExecutable(string debuggerExecutable) {
        _debuggerExecutable = debuggerExecutable;
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
		stop();
		destroy(_queue);
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

	protected void onDebuggerThreadStarted() {
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
		    Log.e("Exception in debugger thread");
        }
		Log.i("Debugger thread finished");
		_finished = true;
		onDebuggerThreadFinished();
	}

}
