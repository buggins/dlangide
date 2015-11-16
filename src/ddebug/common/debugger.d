module ddebug.common.debugger;

import core.thread;
import dlangui.core.logger;
import ddebug.common.queue;

enum ResponseCode : int {
	/// Operation finished successfully
	Ok = 0,

	// more success codes here

	/// General purpose failure code
	Fail = 1000,
	/// method is not implemented
	NotImplemented,
	/// error running debugger
	CannotRunDebugger,

	// more error codes here
}

alias Runnable = void delegate();
alias DebuggerResponse = void delegate(ResponseCode code, string msg);

interface Debugger {
	/// start debugging
	void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response);
}



/// proxy for debugger interface implementing async calls
class DebuggerProxy : Debugger {
	private DebuggerBase _debugger;
	private void delegate(Runnable runnable) _callbackDelegate;

	this(DebuggerBase debugger, void delegate(Runnable runnable) callbackDelegate) {
		_debugger = debugger;
		_callbackDelegate = callbackDelegate;
	}

	void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response) {
		_debugger.postRequest(delegate() {
				_debugger.startDebugging(debuggerExecutable, executable, args, workingDir,
					delegate(ResponseCode code, string msg) {
						_callbackDelegate( delegate() { response(code, msg); } );
					}
				);
		});
	}

}

class DebuggerBase : Thread, Debugger {
	private bool _stopRequested;
	private bool _finished;
	protected string _debuggerExecutable;
	protected BlockingQueue!Runnable _queue;

	void postRequest(Runnable request) {
		_queue.put(request);
	}

	this() {
		super(&run);
		_queue = new BlockingQueue!Runnable();
	}

	~this() {
		stop();
		destroy(_queue);
		_queue = null;
	}

	void stop() {
		Log.i("Debugger.stop()");
		_stopRequested = true;
		_queue.close();
	}

	protected void onDebuggerThreadStarted() {
	}

	protected void onDebuggerThreadFinished() {
	}
	
	/// thread func: execute all tasks from queue
	private void run() {
		onDebuggerThreadStarted();
		Log.i("Debugger thread started");
		while (!_stopRequested) {
			Runnable task;
			if (_queue.get(task, 0)) {
				task();
			}
		}
		Log.i("Debugger thread finished");
		_finished = true;
		onDebuggerThreadFinished();
	}

	void startDebugging(string debuggerExecutable, string executable, string[] args, string workingDir, DebuggerResponse response) {
		response(ResponseCode.NotImplemented, "Not Implemented");
	}

}
