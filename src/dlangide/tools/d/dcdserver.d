module dlangide.tools.d.dcdserver;

import dlangui.core.logger;
import dlangui.core.files;
import dlangide.builders.extprocess;
import dlangide.workspace.project;
import std.conv : to;
import dlangide.tools.d.dcdinterface;


/// encapsulates running DCD server access
class DCDServer {
	private ExternalProcess dcdProcess;
	private ProtectedTextStorage stdoutTarget;
    private int _port;
    private bool _running;
    private bool _error;

    /// port to connect to DCD
    @property int port() {
        return _port;
    }
    this(int port = DCD_SERVER_PORT_FOR_DLANGIDE) {
        _port = port;
    }
    /// returns true if there was error while trying to run server last time
    @property bool isError() {
        return _error;
    }
    /// returns true if server seems running
    @property bool isRunning() {
        return _running;
    }
    /// start DCD server
    bool start() {
        if (dcdProcess || stdoutTarget) {
            Log.e("Already started");
            return false;
        }
        _error = false;
        _running = false;
        string dcdServerExecutable = findExecutablePath("dcd-server");
        if (!dcdServerExecutable) {
            Log.e("dcd-server executable is not found");
            _error = true;
            return false;
        }

        string[] srcPaths = dmdSourcePaths();
		string[] arguments;
        foreach(p; srcPaths)
            arguments ~= "-I" ~ p;
        if (_port != DCD_DEFAULT_PORT)
            arguments ~= "-p" ~ to!string(_port);
        Log.i("starting dcd-server: executable path is ", dcdServerExecutable, " args: ", arguments);
        dcdProcess = new ExternalProcess();
		stdoutTarget = new ProtectedTextStorage();
		ExternalProcessState state = dcdProcess.run(dcdServerExecutable, arguments, null, stdoutTarget);
        if (state != ExternalProcessState.Running) {
            Log.e("Error while starting DCD: process state reported is ", state);
            _error = true;
            dcdProcess.kill();
            dcdProcess.wait();
            destroy(dcdProcess);
            dcdProcess = null;
            stdoutTarget = null;
            return false;
        }
        Log.i("DCD server is started successfully");
        _running = true;
        return true;
    }

    /// stop DCD server
    bool stop() {
        if (!dcdProcess) {
            Log.e("Cannot stop DCD server - it's not started");
            return false;
        }
        debug(DCD) Log.i("Current DCD server state: ", dcdProcess.poll());
        Log.i("Stopping DCD server");
        ExternalProcessState state = dcdProcess.kill();
        state = dcdProcess.wait();
        debug(DCD) Log.i("DCD server state: ", state);
        destroy(dcdProcess);
        dcdProcess = null;
        stdoutTarget = null;
        _running = false;
        return true;
    }
}
