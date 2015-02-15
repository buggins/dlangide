module dlangide.tools.d.DCDInterface;

import dlangui.core.logger;

import dlangide.builders.extprocess;

import std.typecons;
import std.conv;
import std.string;

enum DCDResult : int {
	DCD_NOT_RUNNING = 0,
	SUCCESS,
	NO_RESULT,
	FAIL,
}
alias ResultSet = Tuple!(DCDResult, "result", dstring[], "output");

//Interface to DCD
//TODO: Check if server is running, start server if needed etc.
class DCDInterface {
	ExternalProcess dcdProcess;
	ProtectedTextStorage stdoutTarget;
	this() {
		dcdProcess = new ExternalProcess();
		stdoutTarget = new ProtectedTextStorage();
	}

	ResultSet goToDefinition(in dstring content, int index) {
		ExternalProcess dcdProcess = new ExternalProcess();

		ResultSet result;
		if(dcdProcess.state != ExternalProcessState.None) {
			result.result = DCDResult.FAIL;
			return result;
		}

		char[][] arguments = ["-l".dup, "-c".dup];
		arguments ~= [to!(char[])(index)];
		ProtectedTextStorage stdoutTarget = new ProtectedTextStorage();

		dcdProcess.run("dcd-client".dup, arguments, "/usr/bin".dup, stdoutTarget);
		dcdProcess.write(content);
		dcdProcess.wait();

		dstring[] output =  stdoutTarget.readText.splitLines();

		if(dcdProcess.poll() == ExternalProcessState.Stopped) {
			result.result = DCDResult.SUCCESS;
		}
		else {
			result.result = DCDResult.FAIL;
			return result;
		}

		if(output.length > 0) {
			if(output[0].indexOf("Not Found".dup) == 0) {
				result.result = DCDResult.NO_RESULT;
				return result;
			}
		}

		auto split = output[0].indexOf("\t");
        if(split == -1) {
        	Log.d("DCD output format error.");
        	result.result = DCDResult.FAIL;
        	return result;
        }

        result.output ~= output[0][0 .. split];
        result.output ~= output[0][split+1 .. $];
		return result;
	}

	bool execute(char[][] arguments ,ref dstring output, dstring input) {
		//TODO: Working Directory, where is that?
		//TODO: Inform user when dcd-client is not available.
		dcdProcess.run("dcd-client".dup, arguments, "/usr/bin".dup, stdoutTarget);
		dcdProcess.write(input);
		
		while(dcdProcess.poll() == ExternalProcessState.Running){ }		

		output = stdoutTarget.readText();
		return true;
	}

}