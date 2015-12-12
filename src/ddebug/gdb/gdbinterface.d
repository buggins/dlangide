module ddebug.gdb.gdbinterface;

public import ddebug.common.debugger;
import ddebug.common.execution;
import dlangui.core.logger;
import ddebug.common.queue;
import dlangide.builders.extprocess;
import std.utf;
import std.conv : to;
import std.array : empty;
import std.algorithm : startsWith, equal;

abstract class ConsoleDebuggerInterface : DebuggerBase, TextWriter {
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
        foreach(line; lines) {
            onDebuggerStdoutLine(line);
        }
		return true;
	}
	protected void onDebuggerStdoutLine(string line) {
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
        string cmd = to!string(commandId) ~ text;
        Log.d("GDB command[", commandId, "]> ", text);
		sendLine(cmd);
		return commandId;
	}

	Pid terminalPid;
	string terminalTty;

	string startTerminal() {
		Log.d("Starting terminal ", _terminalExecutable);
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
            string[] args = [
                _terminalExecutable,
                "-title",
                "DLangIDE External Console",
                "-e",
                "echo 'DlangIDE External Console' && tty > " ~ termfile ~ " && sleep 1000000"
            ];
            Log.d("Terminal command line: ", args);
			terminalPid = spawnProcess(args);
			for (int i = 0; i < 40; i++) {
				Thread.sleep(dur!"msecs"(100));
				if (!isTerminalActive) {
					Log.e("Failed to get terminal TTY");
					return null;
				}
				if (exists(termfile)) {
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
                Log.d("Terminal tty: ", terminalTty);
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
        if (_terminalExecutable.empty)
            return true;
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
        if (_terminalExecutable.empty)
            return;
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

    override void startDebugging() {
        Log.d("GDBInterface.startDebugging()");
		string[] debuggerArgs;
        if (!_terminalExecutable.empty) {
		    terminalTty = startTerminal();
		    if (terminalTty.length == 0) {
			    //_callback.onResponse(ResponseCode.CannotRunDebugger, "Cannot start terminal");
                _status = ExecutionStatus.Error;
                _stopRequested = true;
                return;
		    }
		    debuggerArgs ~= "-tty";
		    debuggerArgs ~= terminalTty;
        }
		debuggerArgs ~= "--interpreter=mi";
		debuggerArgs ~= "--silent";
		debuggerArgs ~= "--args";
		debuggerArgs ~= _executableFile;
		foreach(arg; _executableArgs)
			debuggerArgs ~= arg;
		ExternalProcessState state = runDebuggerProcess(_debuggerExecutable, debuggerArgs, _executableWorkingDir);
		Log.i("Debugger process state:");
		if (state == ExternalProcessState.Running) {
            _callback.onProgramLoaded(true, true);
			//sendCommand("-break-insert main");
		} else {
            _status = ExecutionStatus.Error;
            _stopRequested = true;
			return;
		}
    }

    override protected void onDebuggerThreadFinished() {
        Log.d("Debugger thread finished");
        if (_debuggerProcess !is null) {
            Log.d("Killing debugger process");
            _debuggerProcess.kill();
            Log.d("Waiting for debugger process finishing");
            //_debuggerProcess.wait();
        }
        killTerminal();
        Log.d("Sending execution status");
        _callback.onProgramExecutionStatus(this, _status, _exitCode);
    }

    bool _threadJoined = false;
	override void stop() {
        if (_stopRequested)
            return;
        Log.d("GDBInterface.stop()");
        postRequest(delegate() {
            execStop();
        });
        _stopRequested = true;
        postRequest(delegate() {
        });
        _queue.close();
        if (!_threadJoined) {
            _threadJoined = true;
            join();
        }
	}

    /// start program execution, can be called after program is loaded
    int _startRequestId;
    void execStart() {
        _startRequestId = sendCommand("-exec-run");
    }

    /// start program execution, can be called after program is loaded
    int _continueRequestId;
    void execContinue() {
        _continueRequestId = sendCommand("-exec-continue");
    }

    /// stop program execution
    int _stopRequestId;
    void execStop() {
        _continueRequestId = sendCommand("-gdb-exit");
    }
    /// interrupt execution
    int _pauseRequestId;
    void execPause() {
        _pauseRequestId = sendCommand("-exec-interrupt");
    }
    /// step over
    int _stepOverRequestId;
    void execStepOver() {
        _stepOverRequestId = sendCommand("-exec-next");
    }
    /// step in
    int _stepInRequestId;
    void execStepIn() {
        _stepInRequestId = sendCommand("-exec-step");
    }
    /// step out
    int _stepOutRequestId;
    void execStepOut() {
        _stepOutRequestId = sendCommand("-exec-finish");
    }

    // ~message
    void handleStreamLineCLI(string s) {
        Log.d("GDB CLI: ", s);
        _callback.onDebuggerMessage(s);
    }

    // @message
    void handleStreamLineProgram(string s) {
        Log.d("GDB program stream: ", s);
        //_callback.onDebuggerMessage(s);
    }

    // &message
    void handleStreamLineGDBDebug(string s) {
        Log.d("GDB internal debug message: ", s);
    }

    // *stopped,reason="exited-normally"
    // *running,thread-id="all"
    // *asyncclass,result
    void handleExecAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        Log.v("GDB async *[", token, "] ", msgType, " params: ", s);
        if (msgId == AsyncClass.running) {
            _callback.onDebugState(DebuggingState.running, s, 0);
        } else if (msgId == AsyncClass.stopped) {
            _callback.onDebugState(DebuggingState.stopped, s, 0);
        }
    }

    // +asyncclass,result
    void handleStatusAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        Log.v("GDB async +[", token, "] ", msgType, " params: ", s);
    }

    // =asyncclass,result
    void handleNotifyAsyncMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        AsyncClass msgId = asyncByName(msgType);
        if (msgId == AsyncClass.other)
            Log.d("GDB WARN unknown async class type: ", msgType);
        Log.v("GDB async =[", token, "] ", msgType, " params: ", s);
    }

    // ^resultClass,result
    void handleResultMessage(uint token, string s) {
        string msgType = parseIdentAndSkipComma(s);
        ResultClass msgId = resultByName(msgType);
        if (msgId == ResultClass.other)
            Log.d("GDB WARN unknown result class type: ", msgType);
        Log.v("GDB result ^[", token, "] ", msgType, " params: ", s);
    }

    bool _firstIdle = true;
    // (gdb)
    void onDebuggerIdle() {
        Log.d("GDB idle");
        if (_firstIdle) {
            _firstIdle = false;
            return;
        }
    }

	override protected void onDebuggerStdoutLine(string gdbLine) {
		//Log.d("GDB stdout: '", line, "'");
        string line = gdbLine;
        if (line.empty)
            return;
        // parse token (sequence of digits at the beginning of message)
        uint tokenId = 0;
        int tokenLen = 0;
        while (tokenLen < line.length && line[tokenLen] >= '0' && line[tokenLen] <= '9')
            tokenLen++;
        if (tokenLen > 0) {
            tokenId = to!uint(line[0..tokenLen]);
            line = line[tokenLen .. $];
        }
        if (line.length == 0)
            return; // token only, no message!
        char firstChar = line[0];
        string restLine = line.length > 1 ? line[1..$] : "";
        if (firstChar == '~') {
            handleStreamLineCLI(restLine);
            return;
        } else if (firstChar == '@') {
            handleStreamLineProgram(restLine);
            return;
        } else if (firstChar == '&') {
            handleStreamLineGDBDebug(restLine);
            return;
        } else if (firstChar == '*') {
            handleExecAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '+') {
            handleStatusAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '=') {
            handleNotifyAsyncMessage(tokenId, restLine);
            return;
        } else if (firstChar == '^') {
            handleResultMessage(tokenId, restLine);
            return;
        } else if (line.startsWith("(gdb)")) {
            onDebuggerIdle();
            return;
        } else {
            Log.d("GDB unprocessed: ", gdbLine);
        }
    }

}

string parseIdent(ref string s) {
    string res = null;
    int len = 0;
    for(; len < s.length; len++) {
        char ch = s[len];
        if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '-'))
            break;
    }
    if (len > 0) {
        res = s[0..len];
        s = s[len .. $];
    }
    return res;
}

bool skipComma(ref string s) {
    if (s.length > 0 && s[0] == ',') {
        s = s[1 .. $];
        return true;
    }
    return false;
}

string parseIdentAndSkipComma(ref string s) {
    string res = parseIdent(s);
    skipComma(s);
    return res;
}

ResultClass resultByName(string s) {
    if (s.equal("done")) return ResultClass.done;
    if (s.equal("running")) return ResultClass.running;
    if (s.equal("connected")) return ResultClass.connected;
    if (s.equal("error")) return ResultClass.error;
    if (s.equal("exit")) return ResultClass.exit;
    return ResultClass.other;
}

enum ResultClass {
    done,
    running,
    connected,
    error,
    exit,
    other
}

AsyncClass asyncByName(string s) {
    if (s.equal("stopped")) return AsyncClass.stopped;
    if (s.equal("running")) return AsyncClass.running;
    if (s.equal("library-loaded")) return AsyncClass.library_loaded;
    if (s.equal("library-unloaded")) return AsyncClass.library_unloaded;
    if (s.equal("thread-group-added")) return AsyncClass.thread_group_added;
    if (s.equal("thread-group-started")) return AsyncClass.thread_group_started;
    if (s.equal("thread-group-exited")) return AsyncClass.thread_group_exited;
    if (s.equal("thread-created")) return AsyncClass.thread_created;
    if (s.equal("thread-exited")) return AsyncClass.thread_exited;
    return AsyncClass.other;
}

enum AsyncClass {
    running,
    stopped,
    library_loaded,
    library_unloaded,
    thread_group_added,
    thread_group_started,
    thread_group_exited,
    thread_created,
    thread_exited,
    other
}

enum MITokenType {
    str,
}

struct MIToken {
}
