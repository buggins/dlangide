module ddebug.common.debugger;

import core.thread;
import dlangui.core.logger;

interface Debugger {
	/// start debugging
	void startDebugging(string executable, string[] args, string workingDir);
}

interface DebuggerCallback {
}

class DebuggerBase : Thread {
	private bool _stopRequested;
	private bool _finished;

	this() {
		super(&run);
	}

	private void run() {
		Log.i("Debugger thread started");
		Log.i("Debugger thread finished");
		_finished = true;
	}
}
