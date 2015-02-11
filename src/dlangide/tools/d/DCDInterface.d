module dlangide.tools.d.DCDInterface;

import dlangide.builders.extprocess;

//Interface to DCD
//TODO: Check if server is running, start server if needed etc.
class DCDInterface {
	ExternalProcess dcdProcess;
	this() {
		dcdProcess = new ExternalProcess();
	}
	bool execute(char[][] arguments ,ref dstring output) {
		ProtectedTextStorage stdoutTarget = new ProtectedTextStorage();
		ExternalProcess dcdProcess = new ExternalProcess();
		//TODO: Working Directory, where is that?
		dcdProcess.run("dcd-client".dup, arguments, "/usr/bin".dup, stdoutTarget);
		while(dcdProcess.poll() == ExternalProcessState.Running){ }
		output = stdoutTarget.readText();
		return true;
	}

}