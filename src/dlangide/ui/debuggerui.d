module dlangide.ui.debuggerui;

import dlangui.core.logger;
import dlangide.ui.frame;
import ddebug.common.execution;
import ddebug.common.debugger;

class DebuggerUIHandler : DebuggerCallback {
    IDEFrame _ide;
    Debugger _debugger;
    DebuggingState _state = DebuggingState.loaded;

    this(IDEFrame ide, Debugger debugger) {
        _ide = ide;
        _debugger = debugger;
        _debugger.setDebuggerCallback(this);
    }

    /// called when program execution is stopped
    void onProgramExecutionStatus(ProgramExecution process, ExecutionStatus status, int exitCode) {
        Log.d("Debugger exit status: ", status, " ", exitCode);
        _ide.debugFinished(process, status, exitCode);
		//_callbackDelegate( delegate() { _callback.onProgramExecutionStatus(this, status, exitCode); } );
    }

    void onResponse(ResponseCode code, string msg) {
        Log.d("Debugger response: ", code, " ", msg);
		//_callbackDelegate( delegate() { _callback.onResponse(code, msg); } );
    }

    void onDebuggerMessage(string msg) {
        _ide.logPanel.logLine("DBG: " ~ msg);
    }

    /// debugger is started and loaded program, you can set breakpoints at this time
    void onProgramLoaded(bool successful, bool debugInfoLoaded) {
        _ide.logPanel.logLine("Program is loaded");
        // TODO: check succes status and debug info
        _debugger.execStart();
    }

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, string msg, int param) {
        Log.d("onDebugState: ", state, " ", msg, " param=", param);
        _state = state;
        if (state == DebuggingState.stopped) {
            _ide.logPanel.logLine("Program is stopped: " ~ msg);
            _debugger.stop();
        }
    }

    void run() {
        _debugger.run();
    }
}
