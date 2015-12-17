module ddebug.gdb.gdbinterface;

public import ddebug.common.debugger;
import ddebug.common.execution;
import dlangui.core.logger;
import ddebug.common.queue;
import dlangide.builders.extprocess;
import ddebug.gdb.gdbmiparser;
import std.utf;
import std.conv : to;
import std.array : empty;
import std.algorithm : startsWith, endsWith, equal;
import core.thread;

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
        ExternalProcessState state = _debuggerProcess.poll();
        if (state != ExternalProcessState.Running) {
            _stopRequested = true;
            return 0;
        }
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
            Thread.sleep(dur!"seconds"(1));
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
        if (_stopRequested) {
            Log.w("GDBInterface.stop() - _stopRequested flag already set");
            return;
        }
        _stopRequested = true;
        Log.d("GDBInterface.stop()");
        postRequest(delegate() {
            Log.d("GDBInterface.stop() processing in queue");
            execStop();
        });
        Thread.sleep(dur!"msecs"(200));
        postRequest(delegate() {
        });
        _queue.close();
        if (!_threadJoined) {
            _threadJoined = true;
            if (_threadStarted) {
                try {
                    join();
                } catch (Exception e) {
                    Log.e("Exception while trying to join debugger thread");
                }
            }
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
    /// restart
    int _restartRequestId;
    void execRestart() {
        //_restartRequestId = sendCommand("-exec-restart");
    }

    private GDBBreakpoint[] _breakpoints;
    private static class GDBBreakpoint {
        Breakpoint bp;
        string number;
        int createRequestId;
    }
    private GDBBreakpoint findBreakpoint(Breakpoint bp) {
        foreach(gdbbp; _breakpoints) {
            if (gdbbp.bp.id == bp.id)
                return gdbbp;
        }
        return null;
    }
    private GDBBreakpoint findBreakpointByRequestToken(int token) {
        if (token == 0)
            return null;
        foreach(gdbbp; _breakpoints) {
            if (gdbbp.createRequestId == token)
                return gdbbp;
        }
        return null;
    }
    private GDBBreakpoint findBreakpointByNumber(string number) {
        if (number.empty)
            return null;
        foreach(gdbbp; _breakpoints) {
            if (gdbbp.number.equal(number))
                return gdbbp;
        }
        return null;
    }
    void handleBreakpointRequestResult(GDBBreakpoint gdbbp, ResultClass resType, MIValue params) {
        if (resType == ResultClass.done) {
            if (MIValue bkpt = params["bkpt"]) {
                string number = bkpt.getString("number");
                gdbbp.number = number;
                Log.d("GDB number for breakpoint " ~ gdbbp.bp.id.to!string ~ " assigned is " ~ number);
            }
        }
    }

    private void addBreakpoint(Breakpoint bp) {
        GDBBreakpoint gdbbp = new GDBBreakpoint();
        gdbbp.bp = bp;
        char[] cmd;
        cmd ~= "-break-insert ";
        if (!bp.enabled)
            cmd ~= "-d "; // create disabled
        cmd ~= bp.fullFilePath;
        cmd ~= ":";
        cmd ~= to!string(bp.line);
        gdbbp.createRequestId = sendCommand(cmd.dup);
        _breakpoints ~= gdbbp;
    }

    /// update list of breakpoints
    void setBreakpoints(Breakpoint[] breakpoints) {
        char[] breakpointsToDelete;
        char[] breakpointsToEnable;
        char[] breakpointsToDisable;
        // checking for removed breakpoints
        for (int i = cast(int)_breakpoints.length - 1; i >= 0; i--) {
            bool found = false;
            foreach(bp; breakpoints)
                if (bp.id == _breakpoints[i].bp.id) {
                    found = true;
                    break;
                }
            if (!found) {
                for (int j = i; j < _breakpoints.length - 1; j++)
                    _breakpoints[j] = _breakpoints[j + 1];
                _breakpoints.length = _breakpoints.length - 1;
                if (breakpointsToDelete.length)
                    breakpointsToDelete ~= ",";
                breakpointsToDelete ~= _breakpoints[i].number;
            }
        }
        // checking for added or updated breakpoints
        foreach(bp; breakpoints) {
            GDBBreakpoint existing = findBreakpoint(bp);
            if (!existing) {
                addBreakpoint(bp);
            } else {
                if (bp.enabled && !existing.bp.enabled) {
                    if (breakpointsToEnable.length)
                        breakpointsToEnable ~= ",";
                    breakpointsToEnable ~= existing.number;
                    existing.bp.enabled = true;
                } else if (!bp.enabled && existing.bp.enabled) {
                    if (breakpointsToDisable.length)
                        breakpointsToDisable ~= ",";
                    breakpointsToDisable ~= existing.number;
                    existing.bp.enabled = false;
                }
            }
        }
        if (breakpointsToDelete.length) {
            Log.d("Deleting breakpoints: " ~ breakpointsToDelete);
            sendCommand(("-break-delete " ~ breakpointsToDelete).dup);
        }
        if (breakpointsToEnable.length) {
            Log.d("Enabling breakpoints: " ~ breakpointsToEnable);
            sendCommand(("-break-enable " ~ breakpointsToEnable).dup);
        }
        if (breakpointsToDisable.length) {
            Log.d("Disabling breakpoints: " ~ breakpointsToDisable);
            sendCommand(("-break-disable " ~ breakpointsToDisable).dup);
        }
    }


    // ~message
    void handleStreamLineCLI(string s) {
        Log.d("GDB CLI: ", s);
        if (s.length >= 2 && s.startsWith('\"') && s.endsWith('\"'))
            s = parseCString(s);
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
        MIValue params = parseMI(s);
        if (!params) {
            Log.e("Failed to parse exec state params");
            return;
        }
        Log.v("GDB async *[", token, "] ", msgType, " params: ", params.toString);
        string reason = params.getString("reason");
        if (msgId == AsyncClass.running) {
            _callback.onDebugState(DebuggingState.running, StateChangeReason.unknown, null, null);
        } else if (msgId == AsyncClass.stopped) {
            StateChangeReason reasonId = StateChangeReason.unknown;
            DebugLocation location = parseFrame(params["frame"]);
            string threadId = params.getString("thread-id");
            string stoppedThreads = params.getString("all");
            Breakpoint bp = null;
            if (reason.equal("end-stepping-range")) {
                _callback.onDebugState(DebuggingState.paused, StateChangeReason.endSteppingRange, location, bp);
            } else if (reason.equal("breakpoint-hit")) {
                if (GDBBreakpoint gdbbp = findBreakpointByNumber(params.getString("bkptno"))) {
                    bp = gdbbp.bp;
                    if (!location && bp) {
                        location = new DebugLocation();
                        location.fillMissingFields(bp);
                    }
                }
                _callback.onDebugState(DebuggingState.paused, StateChangeReason.breakpointHit, location, bp);
            } else {
                _callback.onDebugState(DebuggingState.stopped, StateChangeReason.exited, null, null);
            }
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
        Log.v("GDB result ^[", token, "] ", s);
        string msgType = parseIdentAndSkipComma(s);
        ResultClass msgId = resultByName(msgType);
        if (msgId == ResultClass.other)
            Log.d("GDB WARN unknown result class type: ", msgType);
        MIValue params = parseMI(s);
        Log.v("GDB result ^[", token, "] ", msgType, " params: ", (params ? params.toString : "unparsed: " ~ s));
        if (GDBBreakpoint gdbbp = findBreakpointByRequestToken(token)) {
            // result of breakpoint creation operation
            handleBreakpointRequestResult(gdbbp, msgId, params);
            return;
        }
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

