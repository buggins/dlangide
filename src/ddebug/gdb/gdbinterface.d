module ddebug.gdb.gdbinterface;

public import ddebug.common.debugger;
import dlangui.core.logger;
import ddebug.common.queue;
import dlangide.builders.extprocess;
import std.utf;

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

	/// log lines
	override void writeText(dstring text) {
		string text8 = toUTF8(text);
		postRequest(delegate() {
				onStdoutText(text8);
		});
	}

}

class GDBInterface : ConsoleDebuggerInterface {

	override void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response) {
		string[] debuggerArgs;
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
		} else {
			response(ResponseCode.CannotRunDebugger, "Error while trying to run debugger process");
		}
	}

	override void stop() {
		if (_debuggerProcess !is null)
			_debuggerProcess.kill();
		super.stop();
	}

	/// return true to clear lines list
	override protected bool onDebuggerStdoutLines(string[] lines) {
		Log.d("onDebuggerStdout ", lines);
		return true;
	}
}
