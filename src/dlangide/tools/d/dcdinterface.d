module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;

import dlangide.builders.extprocess;

import std.typecons;
import std.conv;
import std.string;

const DCD_SERVER_PORT_FOR_DLANGIDE = 9167;
const DCD_DEFAULT_PORT = 9166;

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

    private int _port;
    //ExternalProcess dcdProcess;
    //ProtectedTextStorage stdoutTarget;
    this(int port = DCD_SERVER_PORT_FOR_DLANGIDE) {
        _port = port;
        //dcdProcess = new ExternalProcess();
        //stdoutTarget = new ProtectedTextStorage();
    }

    protected string dumpContext(string content, int pos) {
        if (pos >= 0 && pos <= content.length) {
            int start = pos;
            int end = pos;
            for (int i = 0; start > 0 && content[start - 1] != '\n' && i < 10; i++)
                start--;
            for (int i = 0; end < content.length - 1 && content[end] != '\n' && i < 10; i++)
                end++;
            return content[start .. pos] ~ "|" ~ content[pos .. end];
        }
        return "";
    }

    protected dstring[] invokeDcd(string[] arguments, string content, out bool success) {
        success = false;
        ExternalProcess dcdProcess = new ExternalProcess();

        ProtectedTextStorage stdoutTarget = new ProtectedTextStorage();

        version(Windows) {
            string dcd_client_name = "dcd-client.exe";
            string dcd_client_dir = null;
        } else {
            string dcd_client_name = "dcd-client";
            string dcd_client_dir = "/usr/bin";
        }
        dcdProcess.run(dcd_client_name, arguments, dcd_client_dir, stdoutTarget);
        
        dcdProcess.write(content);
        dcdProcess.wait();

        dstring[] output =  stdoutTarget.readText.splitLines();

        if(dcdProcess.poll() == ExternalProcessState.Stopped) {
            success = true;
        }
        return output;
    }

    ResultSet goToDefinition(in string[] importPaths, in string filename, in string content, int index) {
        ResultSet result;

        version(USE_LIBDPARSE) {
            import dlangide.tools.d.dparser;
            DParsingService.instance.addImportPaths(importPaths);
            DParsedModule m = DParsingService.instance.findDeclaration(cast(ubyte[])content, filename, index);
        }
        
        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));

        string[] arguments = ["-l", "-c"];
        arguments ~= [to!string(index)];

        foreach(p; importPaths) {
            arguments ~= "-I" ~ p;
        }
        if (_port != DCD_DEFAULT_PORT)
            arguments ~= "-p" ~ to!string(_port);

        bool success = false;
        dstring[] output =  invokeDcd(arguments, content, success);

        if (success) {
            result.result = DCDResult.SUCCESS;
        } else {
            result.result = DCDResult.FAIL;
            return result;
        }

        debug(DCD) Log.d("DCD output:\n", output);

        if(output.length > 0) {
            dstring firstLine = output[0];
            if(firstLine.startsWith("Not Found") || firstLine.startsWith("Not found")) {
                result.result = DCDResult.NO_RESULT;
                return result;
            }
            auto split = firstLine.indexOf("\t");
            if(split == -1) {
                Log.d("DCD output format error.");
                result.result = DCDResult.FAIL;
                return result;
            }

            result.output ~= output[0][0 .. split];
            result.output ~= output[0][split+1 .. $];
        } else {
            result.result = DCDResult.NO_RESULT;
            //result.result = DCDResult.FAIL;
        }

        return result;
    }

    ResultSet getCompletions(in string[] importPaths, in string filename, in string content, int index) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));

        ResultSet result;

        string[] arguments = ["-c"];
        arguments ~= [to!string(index)];

        foreach(p; importPaths) {
            arguments ~= "-I" ~ p;
        }
        if (_port != DCD_DEFAULT_PORT)
            arguments ~= "-p" ~ to!string(_port);

        bool success = false;
        dstring[] output =  invokeDcd(arguments, content, success);

        if (success) {
            result.result = DCDResult.SUCCESS;
        } else {
            result.result = DCDResult.FAIL;
            return result;
        }
        debug(DCD) Log.d("DCD output:\n", output);

        if (output.length == 0) {
            result.result = DCDResult.NO_RESULT;
            return result;
        }

        enum State : int {None = 0, Identifiers, Calltips}
        State state = State.None;
        foreach(dstring outputLine ; output) {
            if(outputLine == "identifiers") {
                state = State.Identifiers;
            }
            else if(outputLine == "calltips") {
                state = State.Calltips;
            }
            else {
                auto split = outputLine.indexOf("\t");
                if(split < 0) {
                    break;
                }
                if(state == State.Identifiers) {
                    result.output ~= outputLine[0 .. split];
                }
            }
        }
        return result;
    }
}
