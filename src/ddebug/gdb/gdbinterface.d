module ddebug.gdb.gdbinterface;

public import ddebug.common.debugger;
import dlangui.core.logger;
import ddebug.common.queue;
import dlangide.builders.extprocess;
import std.utf;
import std.conv : to;

class ConsoleDebuggerInterface : DebuggerBase, TextWriter {
	protected ExternalProcess _debuggerProcess;

	protected ExternalProcessState runDebuggerProcess(string executable, string[]args, string dir) {
		_debuggerProcess = new ExternalProcess();
		ExternalProcessState state = _debuggerProcess.run(executable, args, dir, this);
		return state;
	}

	private string[] _stdoutLines;
	private char[] _stdoutBuf;
	/// return true to clear lines list
	protected bool onDebuggerStdoutLines(string[] lines) {
		return true;
	}
	private void onStdoutText(string text) {
		_stdoutBuf ~= text;
		// pass full lines
		int startPos = 0;
		bool fullLinesFound = false;
		for (int i = 0; i < _stdoutBuf.length; i++) {
			if (_stdoutBuf[i] == '\n' || _stdoutBuf[i] == '\r') {
				if (i <= startPos)
					_stdoutLines ~= "";
				else
					_stdoutLines ~= _stdoutBuf[startPos .. i].dup;
				fullLinesFound = true;
				if (i + 1 < _stdoutBuf.length) {
					if ((_stdoutBuf[i] == '\n' && _stdoutBuf[i + 1] == '\r')
							|| (_stdoutBuf[i] == '\r' && _stdoutBuf[i + 1] == '\n'))
						i++;
				}
				startPos = i + 1;
			}
		}
		if (fullLinesFound) {
			for (int i = 0; i + startPos < _stdoutBuf.length; i++)
				_stdoutBuf[i] = _stdoutBuf[i + startPos];
			_stdoutBuf.length = _stdoutBuf.length - startPos;
			if (onDebuggerStdoutLines(_stdoutLines)) {
				_stdoutLines.length = 0;
			}
		}
	}

	bool sendLine(string text) {
		return _debuggerProcess.write(text ~ "\n");
	}

	/// log lines
	override void writeText(dstring text) {
		string text8 = toUTF8(text);
		postRequest(delegate() {
				onStdoutText(text8);
		});
	}

}

import std.process;
class GDBInterface : ConsoleDebuggerInterface {

	protected int commandId;


	int sendCommand(string text) {
		commandId++;
		sendLine(to!string(commandId) ~ text);
		return commandId;
	}

	Pid terminalPid;
	string terminalTty;

	string startTerminal(string termExecutable) {
		Log.d("Starting terminal");
		import std.random;
		import std.file;
		import std.path;
		import std.string;
		import core.thread;
		uint n = uniform(0, 0x10000000, rndGen());
		terminalTty = null;
		string termfile = buildPath(tempDir, format("dlangide-term-name-%07x.tmp", n));
		Log.d("temp file for tty name: ", termfile);
		try {
			terminalPid = spawnProcess([
				termExecutable,
				"-title",
				"DLangIDE External Console",
				"-e",
				"echo 'DlangIDE External Console' && tty > " ~ termfile ~ " && sleep 1000000"
			]);
			for (int i = 0; i < 20; i++) {
				Thread.sleep(dur!"msecs"(100));
				if (!isTerminalActive) {
					Log.e("Failed to get terminal TTY");
					return null;
				}
				if (!exists(termfile)) {
					Thread.sleep(dur!"msecs"(20));
					break;
				}
			}
			// read TTY from file
			if (exists(termfile)) {
				terminalTty = readText(termfile);
				if (terminalTty.endsWith("\n"))
					terminalTty = terminalTty[0 .. $-1];
				// delete file
				remove(termfile);
			}
		} catch (Exception e) {
			Log.e("Failed to start terminal ", e);
			killTerminal();
		}
		if (terminalTty.length == 0) {
			Log.i("Cannot start terminal");
			killTerminal();
		} else {
			Log.i("Terminal: ", terminalTty);
		}
		return terminalTty;
	}

	bool isTerminalActive() {
		if (terminalPid is null)
			return false;
		auto res = tryWait(terminalPid);
		if (res.terminated) {
			Log.d("isTerminalActive: Terminal is stopped");
			wait(terminalPid);
			terminalPid = Pid.init;
			return false;
		} else {
			return true;
		}
	}

	void killTerminal() {
		if (terminalPid is null)
			return;
		try {
			Log.d("Trying to kill terminal");
			kill(terminalPid, 9);
			Log.d("Waiting for terminal process termination");
			wait(terminalPid);
			terminalPid = Pid.init;
			Log.d("Killed");
		} catch (Exception e) {
			Log.d("Exception while killing terminal", e);
			terminalPid = Pid.init;
		}
	}

	string terminalExecutableFileName = "xterm";
	override void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response) {
		string[] debuggerArgs;
		terminalTty = startTerminal(terminalExecutableFileName);
		if (terminalTty.length == 0) {
			response(ResponseCode.CannotRunDebugger, "Cannot start terminal");
			return;
		}
		debuggerArgs ~= "-tty";
		debuggerArgs ~= terminalTty;
		debuggerArgs ~= "--interpreter=mi";
		debuggerArgs ~= "--silent";
		debuggerArgs ~= "--args";
		debuggerArgs ~= executable;
		foreach(arg; args)
			debuggerArgs ~= arg;
		ExternalProcessState state = runDebuggerProcess(debuggerExecutable, debuggerArgs, workingDir);
		Log.i("Debugger process state:");
		if (state == ExternalProcessState.Running) {
			response(ResponseCode.Ok, "Started");
			//sendCommand("-break-insert main");
			sendCommand("-exec-run");
		} else {
			response(ResponseCode.CannotRunDebugger, "Error while trying to run debugger process");
			return;
		}
	}

	override void stop() {
		if (_debuggerProcess !is null)
			_debuggerProcess.kill();
		killTerminal();
		super.stop();
	}

	/// return true to clear lines list
	override protected bool onDebuggerStdoutLines(string[] lines) {
		Log.d("onDebuggerStdout ", lines);
		return true;
	}
}
