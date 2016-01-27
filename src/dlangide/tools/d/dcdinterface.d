module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;
import ddebug.common.queue;

import core.thread;

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

class DCDTask {
    protected bool _cancelled;
    protected string[] _importPaths;
    protected string _filename;
    protected string _content;
    protected int _index;
    this(string[] importPaths, in string filename, in string content, int index) {
        _importPaths = importPaths;
        _filename = filename;
        _content = content;
        _index = index;
    }
    @property bool cancelled() { return _cancelled; }
    void cancel() {
        _cancelled = true;
    }
    void execute() {
        // override
    }
}

/// Interface to DCD
class DCDInterface : Thread {

    import dsymbol.modulecache;
    protected ModuleCache _moduleCache = ModuleCache(new ASTAllocator);
    protected BlockingQueue!DCDTask _queue;

    this() {
        super(&threadFunc);
        _queue = new BlockingQueue!DCDTask();
        start();
    }

    ~this() {
        _queue.close();
        join();
        destroy(_queue);
        _queue = null;
    }

    void threadFunc() {
        Log.d("Starting DCD tasks thread");
        while (!_queue.closed()) {
            DCDTask task;
            if (!_queue.get(task))
                break;
            if (task && !task.cancelled)
                task.execute();
        }
        Log.d("Exiting DCD tasks thread");
    }

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

    DocCommentsResultSet getDocComments(in string[] importPaths, in string filename, in string content, int index) {
        debug(DCD) Log.d("getDocComments: ", dumpContext(content, index));
        _moduleCache.addImportPaths(importPaths);
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 

        AutocompleteResponse response = getDoc(request, _moduleCache);

        DocCommentsResultSet result;
        result.docComments = response.docComments;
        result.result = DCDResult.SUCCESS;

        debug(DCD) Log.d("DCD doc comments:\n", result.docComments);

        if (result.docComments is null) {
            result.result = DCDResult.NO_RESULT;
        }
        return result;
    }

    FindDeclarationResultSet goToDefinition(in string[] importPaths, in string filename, in string content, int index) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));
        _moduleCache.addImportPaths(importPaths);
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 

        AutocompleteResponse response = findDeclaration(request, _moduleCache);
        
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

    ResultSet getCompletions(in string[] importPaths, in string filename, in string content, int index) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));
        _moduleCache.addImportPaths(importPaths);
        ResultSet result;
        AutocompleteRequest request;
        request.sourceCode = cast(ubyte[])content;
        request.fileName = filename;
        request.cursorPosition = index; 

        AutocompleteResponse response = complete(request, _moduleCache);
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


    /// DCD doc comments task
    class DocCommentsTask : DCDTask {
        this(string[] importPaths, in string filename, in string content, int index) {
            super(importPaths, filename, content, index);
        }
        override void execute() {
            if (_cancelled)
                return;
            _moduleCache.addImportPaths(_importPaths);
            AutocompleteRequest request;
            request.sourceCode = cast(ubyte[])_content;
            request.fileName = _filename;
            request.cursorPosition = _index; 

            AutocompleteResponse response = getDoc(request, _moduleCache);

            DocCommentsResultSet result;
            result.docComments = response.docComments;
            result.result = DCDResult.SUCCESS;

            debug(DCD) Log.d("DCD doc comments:\n", result.docComments);

            if (result.docComments is null) {
                result.result = DCDResult.NO_RESULT;
            }
        }
    }
}
