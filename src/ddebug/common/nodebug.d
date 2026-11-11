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

    protected string _errorMessage;
    /// why the program could not be started (ExecutionStatus.Error), e.g. "Executable file not found: xterm"
    @property string errorMessage() { return _errorMessage; }

    void setProgramExecutionStatusListener(ProgramExecutionStatusListener listener) {
        _listener = listener;
    }

    // status
    protected Pid _pid;
    version (Windows) {
        import core.sys.windows.windows : HANDLE;
        /// process started in the IDE terminal's pseudo console (#507)
        protected HANDLE _hProcess;
    }
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
        version (Windows) {
            if (_hProcess) {
                import core.sys.windows.windows;
                if (WaitForSingleObject(_hProcess, 0) == WAIT_TIMEOUT)
                    return true;
                DWORD code = 0;
                GetExitCodeProcess(_hProcess, &code);
                _exitCode = cast(int)code;
                CloseHandle(_hProcess);
                _hProcess = null;
                Log.d("Process ", _executableFile, " is stopped");
                return false;
            }
        }
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
        version (Windows) {
            if (_hProcess) {
                import core.sys.windows.windows;
                Log.d("Terminating process ", _executableFile);
                TerminateProcess(_hProcess, 1);
                WaitForSingleObject(_hProcess, 5000);
                DWORD code = 0;
                GetExitCodeProcess(_hProcess, &code);
                _exitCode = cast(int)code;
                CloseHandle(_hProcess);
                _hProcess = null;
                return;
            }
        }
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
            // run in the IDE's internal terminal (Output panel) if one is given
            if (!_terminalTty.empty && _terminalTty != "external-console" && _terminalExecutable.empty) {
                try {
                    newstdin = File(_terminalTty, "r");
                    newstdout = File(_terminalTty, "w");
                    newstderr = newstdout;
                } catch (Exception e) {
                    Log.e("ProgramExecutionNoDebug: cannot open terminal ", _terminalTty, ": ", e.msg);
                    newstdin = stdin;
                    newstdout = stdout;
                    newstderr = stderr;
                }
            }
        }
        bool started = false;
        version (Windows) {
            // run in the IDE's internal terminal (Output panel): a pseudo console (#507)
            import ddebug.common.conpty;
            if (isPseudoConsoleDevice(_terminalTty)) {
                if (PseudoConsoleHost host = findPseudoConsoleHost(_terminalTty)) {
                    string error;
                    _hProcess = host.startProcess(params, _executableWorkingDir, error);
                    if (!_hProcess) {
                        Log.e("ProgramExecutionNoDebug: Failed to start process in terminal: ", error);
                        _errorMessage = error;
                        _status = ExecutionStatus.Error;
                    }
                    started = true;
                } else {
                    Log.w("ProgramExecutionNoDebug: terminal ", _terminalTty, " not found, starting the program with its own console");
                }
            }
        }
        if (!started) {
            try {
                _pid = spawnProcess(params, newstdin, newstdout, newstderr, null, Config.none, _executableWorkingDir);
            } catch (Exception e) {
                Log.e("ProgramExecutionNoDebug: Failed to spawn process: ", e);
                _errorMessage = e.msg;
                killProcess();
                _status = ExecutionStatus.Error;
            }
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
