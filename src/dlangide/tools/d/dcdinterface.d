module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;

import std.typecons;
import std.conv;
import std.string;

enum DCDResult : int {
    SUCCESS,
    NO_RESULT,
    FAIL,
}

alias DocCommentsResultSet = Tuple!(DCDResult, "result", string[], "docComments");
alias FindDeclarationResultSet = Tuple!(DCDResult, "result", string, "fileName", ulong, "offset");
alias ResultSet = Tuple!(DCDResult, "result", dstring[], "output");


//Interface to DCD
class DCDInterface {
    import server.autocomplete;
    import common.messages;

    import dsymbol.modulecache;

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

    DocCommentsResultSet getDocComments(in string[] importPaths, in string filename, in string content, int index, ref ModuleCache moduleCache) {
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 

        AutocompleteResponse response = getDoc(request,moduleCache);

        DocCommentsResultSet result;
        result.docComments = response.docComments;
        result.result = DCDResult.SUCCESS;

        debug(DCD) Log.d("DCD doc comments:\n", result.docComments);

        if (result.docComments is null) {
            result.result = DCDResult.NO_RESULT;
        }
        return result;
    }

    FindDeclarationResultSet goToDefinition(in string[] importPaths, in string filename, in string content, int index, ref ModuleCache moduleCache) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));
	
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 

        AutocompleteResponse response = findDeclaration(request,moduleCache);
        
        FindDeclarationResultSet result;
        result.fileName = response.symbolFilePath;
        result.offset = response.symbolLocation;
        result.result = DCDResult.SUCCESS;

        debug(DCD) Log.d("DCD fileName:\n", result.fileName);

        if (result.fileName is null) {
            result.result = DCDResult.NO_RESULT;
        }
        return result;
    }

    ResultSet getCompletions(in string[] importPaths, in string filename, in string content, int index, ref ModuleCache moduleCache) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));

        ResultSet result;
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 
        
        AutocompleteResponse response = complete(request,moduleCache);
        if(response.completions is null || response.completions.length == 0){
            result.result = DCDResult.NO_RESULT;
            return result;
        }

        result.result = DCDResult.SUCCESS;
        result.output.length = response.completions.length;
        int i=0;
        foreach(s;response.completions){
            result.output[i++]=to!dstring(s);            
        }
        debug(DCD) Log.d("DCD output:\n", response.completions);

        return result;
    }
}
