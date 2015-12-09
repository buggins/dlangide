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

interface ProgramExecution {
    /// returns true if it's debugger
    @property bool isDebugger();
    /// executable file
    @property string executableFile();
    /// returns execution status
    @property ExecutionStatus status();
    /// start execution
    bool run();
    /// stop execution
    bool stop();
}
