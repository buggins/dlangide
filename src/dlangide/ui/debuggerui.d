module dlangide.ui.debuggerui;

import dlangui.core.logger;
import dlangui.core.events;
import dlangide.ui.frame;
import dlangide.ui.commands;
import ddebug.common.execution;
import ddebug.common.debugger;

class DebuggerUIHandler : DebuggerCallback {
    IDEFrame _ide;
    Debugger _debugger;
    DebuggingState _state = DebuggingState.loaded;
    DebugLocation _location;

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
        if (_breakpoints.length)
            _debugger.setBreakpoints(_breakpoints);
        _debugger.execStart();
    }

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, StateChangeReason reason, DebugLocation location, Breakpoint bp) {
        Log.d("onDebugState: ", state, " reason=", reason);
        _state = state;
        if (state == DebuggingState.stopped) {
            _ide.logPanel.logLine("Program is stopped");
            _debugger.stop();
        } else if (state == DebuggingState.running) {
            _ide.logPanel.logLine("Program is started");
        } else if (state == DebuggingState.paused) {
            _location = location;
            _ide.logPanel.logLine("Program is paused.");
            _ide.window.update();
        }
    }

    private Breakpoint[] _breakpoints;
    void onBreakpointListUpdated(Breakpoint[] breakpoints) {
        _breakpoints = breakpoints;
        if (_state == DebuggingState.running || _state == DebuggingState.paused) {
            _debugger.setBreakpoints(_breakpoints);
        }
    }

    void run() {
        _debugger.run();
    }

	bool handleAction(const Action a) {
        switch(a.id) {
            case IDEActions.DebugPause:
                if (_state == DebuggingState.running)
                    _debugger.execPause();
                return true;
            case IDEActions.DebugContinue:
                if (_state == DebuggingState.paused)
                    _debugger.execContinue();
                return true;
            case IDEActions.DebugStop:
                _debugger.execStop();
                return true;
            case IDEActions.DebugStepInto:
                if (_state == DebuggingState.paused)
                    _debugger.execStepIn();
                return true;
            case IDEActions.DebugStepOver:
                if (_state == DebuggingState.paused)
                    _debugger.execStepOver();
                return true;
            case IDEActions.DebugStepOut:
                if (_state == DebuggingState.paused)
                    _debugger.execStepOut();
                return true;
            case IDEActions.DebugRestart:
                //_debugger.execStepOut();
                return true;
            default:
                return false;
        }
    }

	/// override to handle specific actions state (e.g. change enabled state for supported actions)
	bool handleActionStateRequest(const Action a) {
        switch (a.id) {
            case IDEActions.DebugStop:
            case IDEActions.DebugPause:
                if (_state == DebuggingState.running)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.DebugContinue:
            case IDEActions.DebugStepInto:
            case IDEActions.DebugStepOver:
            case IDEActions.DebugStepOut:
                if (_state == DebuggingState.paused)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            case IDEActions.DebugRestart:
                a.state = ACTION_STATE_ENABLED;
                return true;
            default:
                return true;
        }
    }
}
