module ddebug.common.nodebug;

import ddebug.common.execution;

import core.thread;
import std.process;
import dlangui.core.logger;

class ProgramExecutionNoDebug : Thread, ProgramExecution {

    // parameters
    /// provides _executableFile, _executableArgs, _executableWorkingDir, _executableEnvVars parameters and setter function setExecutableParams
    mixin ExecutableParams;
    /// provides _terminalExecutable, _terminalTty, setTerminalExecutable, and setTerminalTty
    mixin TerminalParams;

    protected ProgramExecutionStatusListener _listener;
    void setProgramExecutionStatusListener(ProgramExecutionStatusListener listener) {
        _listener = listener;
    }

    // status
    protected Pid _pid;
    protected ExecutionStatus _status = ExecutionStatus.NotStarted;
    protected int _exitCode = 0;

    /// initialize but do not run
    this() {
        super(&threadFunc);
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
        import std.array: empty;

        // prepare parameter list
        string[] params;
        params ~= _executableFile;
        params ~= _executableArgs;

        // external console support
        if (!_terminalExecutable.empty) {
            string cmdline = escapeShellCommand(params);
            string shellScript = `
rm $0
` ~ cmdline ~ `
exit_code=$?
echo "
-----------------------
(program returned exit code: $exit_code)"
echo "Press return to continue..."
dummy_var=""
read dummy_var
exit $exit_code
`;
            static import std.file;
            static import std.path;
            std.file.write(std.path.buildPath(_executableWorkingDir, "dlangide_run_script.sh"), shellScript);
            string setExecFlagCommand = escapeShellCommand("chmod", "+x", "dlangide_run_script.sh");
            spawnShell(setExecFlagCommand, stdin, stdout, stderr, null, Config.none, _executableWorkingDir);
            params = [_terminalExecutable, "-e", "./dlangide_run_script.sh"];
        }

        File newstdin;
        File newstdout;
        File newstderr;
        version (Windows) {
        } else {
            newstdin = stdin;
            newstdout = stdout;
            newstderr = stderr;
        }
        try {
            _pid = spawnProcess(params, newstdin, newstdout, newstderr, null, Config.none, _executableWorkingDir);
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

    /// returns true if it's mago debugger
    @property bool isMagoDebugger() { return false; }

    /// executable file
    @property string executableFile() { return _executableFile; }

    /// returns execution status
    @property ExecutionStatus status() { return _status; }

    /// start execution
    void run() {
        if (_runRequested)
            return; // already running
        assert(_listener !is null);
        _runRequested = true;
        _threadStarted = true;
        _status = ExecutionStatus.Running;
        start();
    }

    /// stop execution (call from GUI thread)
    void stop() {
        if (!_runRequested)
            return;
        if (_stopRequested)
            return;
        _stopRequested = true;
        if (_threadStarted && !_threadJoined) {
            _threadJoined = true;
            join();
        }
    }

    protected bool _threadStarted;
    protected bool _threadJoined;
    protected bool _stopRequested;
    protected bool _runRequested;
}
