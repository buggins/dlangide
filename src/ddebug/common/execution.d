/**
    Support for running stopping of project executable.

 */
module ddebug.common.execution;

enum ExecutionStatus {
    NotStarted,
    Running,
    Finished, // finished normally
    Killed,   // killed
    Error     // error while trying to start program
}

interface ProgramExecutionStatusListener {
    /// called when program execution is stopped
    void onProgramExecutionStatus(ProgramExecution process, ExecutionStatus status, int exitCode);
}

// Interface to run program and control program execution
interface ProgramExecution {
    /// set executable parameters before execution
    void setExecutableParams(string executableFile, string[] args, string workingDir, string[string] envVars);
    /// set external terminal parameters before execution
    void setTerminalExecutable(string terminalExecutable);
    /// set external terminal tty before execution
    void setTerminalTty(string terminalTty);

    /// returns true if it's debugger
    @property bool isDebugger();
    /// returns true if it's mago debugger
    @property bool isMagoDebugger();
    /// executable file
    @property string executableFile();
    /// returns execution status
    //@property ExecutionStatus status();
    /// start execution
    void run();
    /// stop execution
    void stop();
}

/// provides _executableFile, _executableArgs, _executableWorkingDir, _executableEnvVars parameters and setter function setExecutableParams
mixin template ExecutableParams() {
    protected string _executableFile;
    protected string[] _executableArgs;
    protected string _executableWorkingDir;
    protected string[string] _executableEnvVars;

    /// set executable parameters before execution
    void setExecutableParams(string executableFile, string[] args, string workingDir, string[string] envVars) {
        _executableFile = executableFile;
        _executableArgs = args;
        _executableWorkingDir = workingDir;
        _executableEnvVars = envVars;
    }
}


/// provides _terminalExecutable, _terminalTty, setTerminalExecutable, and setTerminalTty
mixin template TerminalParams() {

    /// executable file name for external console/terminal
    protected string _terminalExecutable;
    protected string _terminalTty;

    /// set external terminal parameters before execution
    void setTerminalExecutable(string terminalExecutable) {
        _terminalExecutable = terminalExecutable;
    }

    void setTerminalTty(string terminalTty) {
        _terminalTty = terminalTty;
    }
}

