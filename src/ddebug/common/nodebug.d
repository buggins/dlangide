module ddebug.common.nodebug;

import ddebug.common.execution;

import core.thread;
import std.process;
import dlangui.core.logger;

class ProgramExecutionNoDebug : Thread, ProgramExecution {

    // parameters
    protected string _executableFile;
    protected string[] _args;
    protected string _workDir;
    protected string _externalConsole;
    protected ProgramExecutionStatusListener _listener;


    // status
	protected Pid _pid;
    protected ExecutionStatus _status = ExecutionStatus.NotStarted;
    protected int _exitCode = 0;



    /// initialize but do not run
    this(string executable, string[] args, string workDir, string externalConsole, ProgramExecutionStatusListener listener) {
        super(&threadFunc);
        _executableFile = executable;
        _args = args;
        _workDir = workDir;
        _externalConsole = externalConsole;
        _listener = listener;
        assert(_listener !is null);
    }

    ~this() {
        stop();
    }

	private bool isProcessActive() {
		if (_pid is null)
			return false;
		auto res = tryWait(_pid);
		if (res.terminated) {
			Log.d("Process ", _executableFile, " is stopped");
			_exitCode = wait(_pid);
			_pid = Pid.init;
			return false;
		} else {
			return true;
		}
	}

	private void killProcess() {
		if (_pid is null)
			return;
		try {
			Log.d("Trying to kill process", _executableFile);
			kill(_pid, 9);
			Log.d("Waiting for process termination");
			_exitCode = wait(_pid);
			_pid = Pid.init;
			Log.d("Killed");
		} catch (Exception e) {
			Log.d("Exception while killing process " ~ _executableFile, e);
			_pid = Pid.init;
		}
	}

    private void threadFunc() {
        import std.stdio;
        string[] params;
        params ~= _executableFile;
        params ~= _args;
        File newstdin;
        File newstdout;
        File newstderr;
        try {
		    _pid = spawnProcess(params, newstdin, newstdout, newstderr, null, Config.none, _workDir);
        } catch (Exception e) {
            Log.e("ProgramExecutionNoDebug: Failed to spawn process: ", e);
            killProcess();
            _status = ExecutionStatus.Error;
        }

        if (_status != ExecutionStatus.Error) {
            // thread loop: poll process status
            while (!_stopRequested) {
		        Thread.sleep(dur!"msecs"(50));
                if (!isProcessActive()) {
                    _status = ExecutionStatus.Finished;
                    break;
                }
            }
            if (_stopRequested) {
                killProcess();
                _status = ExecutionStatus.Killed;
            }
        }

        // finished
        Log.d("ProgramExecutionNoDebug: finished, execution status: ", _status);
        _listener.onProgramExecutionStatus(this, _status, _exitCode);
    }

    // implement ProgramExecution interface

    /// returns true if it's debugger
    @property bool isDebugger() { return false; }

    /// executable file
    @property string executableFile() { return _executableFile; }

    /// returns execution status
    @property ExecutionStatus status() { return _status; }

    /// start execution
    bool run() {
        if (_runRequested)
            return false; // already running
        _runRequested = true;
        _threadStarted = true;
        _status = ExecutionStatus.Running;
        start();
        return true;
    }

    /// stop execution (call from GUI thread)
    bool stop() {
        if (!_runRequested)
            return false;
        if (_stopRequested)
            return true;
        _stopRequested = true;
        if (_threadStarted && !_threadJoined) {
            _threadJoined = true;
            join();
        }
        return true;
    }

    protected bool _threadStarted;
    protected bool _threadJoined;
    protected bool _stopRequested;
    protected bool _runRequested;
}
