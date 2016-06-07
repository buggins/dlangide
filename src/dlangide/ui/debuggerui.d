module dlangide.ui.debuggerui;

import dlangui.core.logger;
import dlangui.core.events;
import dlangui.widgets.docks;
import dlangide.workspace.project;
import dlangide.workspace.workspace;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangide.ui.dsourceedit;
import dlangide.ui.stackpanel;
import dlangide.ui.watchpanel;
import ddebug.common.execution;
import ddebug.common.debugger;

class DebuggerUIHandler : DebuggerCallback, StackFrameSelectedHandler {

    private IDEFrame _ide;
    private Debugger _debugger;
    private DebuggingState _state = DebuggingState.loaded;
    private DebugFrame _location;
    private WatchPanel _watchPanel;
    private StackPanel _stackPanel;
    private DebugThreadList _debugInfo;
    private ulong _currentThreadId;

    this(IDEFrame ide, Debugger debugger) {
        _ide = ide;
        _debugger = debugger;
        _debugger.setDebuggerCallback(this);
    }

    /// called when program execution is stopped
    void onProgramExecutionStatus(ProgramExecution process, ExecutionStatus status, int exitCode) {
        Log.d("Debugger exit status: ", status, " ", exitCode);
        updateLocation(null);
        switchToDevelopPerspective();
        _ide.debugFinished(process, status, exitCode);
        //_callbackDelegate( delegate() { _callback.onProgramExecutionStatus(this, status, exitCode); } );
    }

    /// send debug context (threads, stack frames, local vars...)
    void onDebugContextInfo(DebugThreadList info, ulong threadId, int frameId) {
        Log.d("Debugger context received threadId=", threadId, " frameId=", frameId);
        _debugInfo = info;
        _currentThreadId = threadId;
        _stackPanel.updateDebugInfo(info, threadId, frameId);
        _watchPanel.updateDebugInfo(info, threadId, frameId);
    }

    void onStackFrameSelected(ulong threadId, int frame) {
        Log.d("Stack frame selected threadId=", threadId, " frameId=", frame);
        if (_debugInfo) {
            if (DebugThread t = _debugInfo.findThread(threadId)) {
                DebugFrame f = (frame < t.length) ? t[frame] : t.frame;
                updateLocation(f);
                _debugger.requestDebugContextInfo(threadId, frame);
            }
        }
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
        _ide.statusLine.setStatusText("Loaded"d);
        switchToDebugPerspective();
        // TODO: check succes status and debug info
        if (_breakpoints.length) {
            Log.v("Setting breakpoints");
            _debugger.setBreakpoints(_breakpoints);
        }
        Log.v("Starting execution");
        _debugger.execStart();
    }

    void updateLocation(DebugFrame location) {
        _location = location;
        ProjectSourceFile sourceFile = location ? currentWorkspace.findSourceFile(location.projectFilePath, location.fullFilePath) : null;
        if (location) {
            if (sourceFile) {
                _ide.openSourceFile(sourceFile.filename, sourceFile, true);
            } else {
	        import std.file;
		if (exists(location.fullFilePath)) {
	             _ide.openSourceFile(location.fullFilePath, null, true);
		} else {
		     Log.d("can not update location sourcefile does not exists:" ~ location.fullFilePath);
		}
            }
        }
        DSourceEdit[] editors = _ide.allOpenedEditors;
        foreach(ed; editors) {
            if (location && ed.projectSourceFile is sourceFile)
                ed.executionLine = location.line - 1;
            else
                ed.executionLine = -1;
        }
    }

    /// state changed: running / paused / stopped
    void onDebugState(DebuggingState state, StateChangeReason reason, DebugFrame location, Breakpoint bp) {
        Log.d("onDebugState: ", state, " reason=", reason);
        _state = state;
        if (state == DebuggingState.stopped) {
            _ide.logPanel.logLine("Program is stopped");
            _ide.statusLine.setStatusText("Stopped"d);
            _debugger.stop();
        } else if (state == DebuggingState.running) {
            //_ide.logPanel.logLine("Program is started");
            _ide.statusLine.setStatusText("Running"d);
            _ide.window.update();
        } else if (state == DebuggingState.paused) {
            updateLocation(location);
            //_ide.logPanel.logLine("Program is paused.");
            if (reason == StateChangeReason.exception)
                _ide.statusLine.setStatusText("Signal received"d);
            else
                _ide.statusLine.setStatusText("Paused"d);
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

    @property ulong currentThreadId() {
        if (_currentThreadId)
            return _currentThreadId;
        return _debugInfo ? _debugInfo.currentThreadId : 0;
    }
    bool handleAction(const Action a) {
        switch(a.id) {
            case IDEActions.DebugPause:
                if (_state == DebuggingState.running) {
                    _currentThreadId = 0;
                    _debugger.execPause();
                }
                return true;
            case IDEActions.DebugContinue:
                if (_state == DebuggingState.paused) {
                    _currentThreadId = 0;
                    _debugger.execContinue();
                }
                return true;
            case IDEActions.DebugStop:
                //_debugger.execStop();
                Log.d("Trying to stop debugger");
                _currentThreadId = 0;
                _debugger.stop();
                return true;
            case IDEActions.DebugStepInto:
                if (_state == DebuggingState.paused) {
                    Log.d("DebugStepInto threadId=", currentThreadId);
                    _debugger.execStepIn(currentThreadId);
                }
                return true;
            case IDEActions.DebugStepOver:
                if (_state == DebuggingState.paused) {
                    Log.d("DebugStepOver threadId=", currentThreadId);
                    _debugger.execStepOver(currentThreadId);
                }
                return true;
            case IDEActions.DebugStepOut:
                if (_state == DebuggingState.paused) {
                    Log.d("DebugStepOut threadId=", currentThreadId);
                    _debugger.execStepOut(currentThreadId);
                }
                return true;
            case IDEActions.DebugRestart:
                _currentThreadId = 0;
                _debugger.execRestart();
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



    void switchToDebugPerspective() {
        _ide.dockHost.layoutPriority = [DockAlignment.Bottom, DockAlignment.Top, DockAlignment.Left, DockAlignment.Right];
        _watchPanel = new WatchPanel("watch");
        _watchPanel.dockAlignment = DockAlignment.Bottom;
        _ide.dockHost.addDockedWindow(_watchPanel);
        _stackPanel = new StackPanel("stack");
        _stackPanel.dockAlignment = DockAlignment.Right;
        _ide.dockHost.addDockedWindow(_stackPanel);
        _stackPanel.stackFrameSelected = this;
    }

    void switchToDevelopPerspective() {
        _ide.dockHost.layoutPriority = [DockAlignment.Top, DockAlignment.Left, DockAlignment.Right, DockAlignment.Bottom];
        _watchPanel = null;
        auto w = _ide.dockHost.removeDockedWindow("watch");
        if (w)
            destroy(w);
        _stackPanel = null;
        w = _ide.dockHost.removeDockedWindow("stack");
        if (w)
            destroy(w);
    }
}
