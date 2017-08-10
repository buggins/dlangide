module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;
import dlangui.platforms.common.platform;
import ddebug.common.queue;
import dsymbol.string_interning : internString;

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
alias CompletionResultSet = Tuple!(DCDResult, "result", dstring[], "output", char[], "completionKinds");

import server.autocomplete;
import common.messages;

class DCDTask {
    protected bool _cancelled;
    protected CustomEventTarget _guiExecutor;
    protected string[] _importPaths;
    protected string _filename;
    protected string _content;
    protected int _index;
    protected AutocompleteRequest request;
    this(CustomEventTarget guiExecutor, string[] importPaths, in string filename, in string content, int index) {
        _guiExecutor = guiExecutor;
        _importPaths = importPaths;
        _filename = filename;
        _content = content;
        _index = index;
    }
    @property bool cancelled() { return _cancelled; }
    void cancel() {
        synchronized(this) {
            _cancelled = true;
        }
    }
    void createRequest() {
        request.sourceCode = cast(ubyte[])_content;
        request.fileName = internString(_filename);
        request.cursorPosition = _index;
        request.importPaths = _importPaths;
    }
    void performRequest() {
        // override
    }
    void postResults() {
        // override
    }
    void execute() {
        if (_cancelled)
            return;
        createRequest();
        performRequest();
        synchronized(this) {
            if (_cancelled)
                return;
            _guiExecutor.executeInUiThread(&postResults);
        }
    }
}

string[] internStrings(in string[] src) {
    if (!src)
        return null;
    string[] res;
    foreach(s; src)
        res ~= internString(s);
    return res;
}

class ModuleCacheAccessor {
    import dsymbol.modulecache;
    //protected ASTAllocator _astAllocator;
    protected ModuleCache _moduleCache;
    this(in string[] importPaths) {
        _moduleCache = ModuleCache(new ASTAllocator);
        _moduleCache.addImportPaths(internStrings(importPaths));
    }
    protected ModuleCache * getModuleCache(in string[] importPaths) {
        _moduleCache.addImportPaths(internStrings(importPaths));
        return &_moduleCache;
    }
}

/// Async interface to DCD
class DCDInterface : Thread {

    import dsymbol.modulecache;
    //protected ASTAllocator _astAllocator;
    //protected ModuleCache * _moduleCache;
    ModuleCacheAccessor _moduleCache;
    protected BlockingQueue!DCDTask _queue;

    this() {
        super(&threadFunc);
        _queue = new BlockingQueue!DCDTask();
        name = "DCDthread";
        start();
    }

    ~this() {
        _queue.close();
        join();
        destroy(_queue);
        _queue = null;
        if (_moduleCache) {
            destroyModuleCache();
        }
    }

    protected void destroyModuleCache() {
        if (_moduleCache) {
            Log.d("DCD: destroying module cache");
            destroy(_moduleCache);
            _moduleCache = null;
            /*
            if (_astAllocator) {
                _astAllocator.deallocateAll();
                destroy(_astAllocator);
                _astAllocator = null;
            }
            */
        }
    }

    protected ModuleCache * getModuleCache(in string[] importPaths) {
        // TODO: clear cache if import paths removed or changed
        // hold several module cache instances - make cache of caches
        //destroyModuleCache();
        //if (!_astAllocator)
        //    _astAllocator = new ASTAllocator;
        if (!_moduleCache) {
            _moduleCache = new ModuleCacheAccessor(importPaths);
        }
        return _moduleCache.getModuleCache(importPaths);
        //return _moduleCache;
    }

    void threadFunc() {
        Log.d("Starting DCD tasks thread");
        while (!_queue.closed()) {
            DCDTask task;
            if (!_queue.get(task))
                break;
            if (task && !task.cancelled) {
                import std.file : getcwd;
                Log.d("Execute DCD task; current dir=", getcwd);
                task.execute();
                Log.d("DCD task execution finished");
            }
        }
        Log.d("Exiting DCD tasks thread");
    }

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

    /// DCD doc comments task
    class DocCommentsTask : DCDTask {

        protected void delegate(DocCommentsResultSet output) _callback;
        protected DocCommentsResultSet result;

        this(CustomEventTarget guiExecutor, string[] importPaths, in string filename, in string content, int index, void delegate(DocCommentsResultSet output) callback) {
            super(guiExecutor, importPaths, filename, content, index);
            _callback = callback;
        }

        override void performRequest() {
            AutocompleteResponse response = getDoc(request, *getModuleCache(_importPaths));

            result.docComments = response.docComments.dup;
            result.result = DCDResult.SUCCESS;

            debug(DCD) Log.d("DCD doc comments:\n", result.docComments);

            if (result.docComments is null) {
                result.result = DCDResult.NO_RESULT;
            }
        }
        override void postResults() {
            _callback(result);
        }
    }

    DCDTask getDocComments(CustomEventTarget guiExecutor, string[] importPaths, string filename, string content, int index, void delegate(DocCommentsResultSet output) callback) {
        debug(DCD) Log.d("getDocComments: ", dumpContext(content, index));
        DocCommentsTask task = new DocCommentsTask(guiExecutor, importPaths, filename, content, index, callback);
        _queue.put(task);
        return task;
    }

    /// DCD go to definition task
    class GoToDefinitionTask : DCDTask {

        protected void delegate(FindDeclarationResultSet output) _callback;
        protected FindDeclarationResultSet result;

        this(CustomEventTarget guiExecutor, string[] importPaths, in string filename, in string content, int index, void delegate(FindDeclarationResultSet output) callback) {
            super(guiExecutor, importPaths, filename, content, index);
            _callback = callback;
        }

        override void performRequest() {
            AutocompleteResponse response = findDeclaration(request, *getModuleCache(_importPaths));

            result.fileName = response.symbolFilePath.dup;
            result.offset = response.symbolLocation;
            result.result = DCDResult.SUCCESS;

            debug(DCD) Log.d("DCD fileName:\n", result.fileName);

            if (result.fileName is null) {
                result.result = DCDResult.NO_RESULT;
            }
        }
        override void postResults() {
            _callback(result);
        }
    }

    DCDTask goToDefinition(CustomEventTarget guiExecutor, string[] importPaths, in string filename, in string content, int index, void delegate(FindDeclarationResultSet res) callback) {

        debug(DCD) Log.d("DCD GoToDefinition task Context: ", dumpContext(content, index), " importPaths:", importPaths);
        GoToDefinitionTask task = new GoToDefinitionTask(guiExecutor, importPaths, filename, content, index, callback);
        _queue.put(task);
        return task;
    }

    /// DCD get code completions task
    class GetCompletionsTask : DCDTask {

        protected void delegate(CompletionResultSet output) _callback;
        protected CompletionResultSet result;

        this(CustomEventTarget guiExecutor, string[] importPaths, in string filename, in string content, int index, void delegate(CompletionResultSet output) callback) {
            super(guiExecutor, importPaths, filename, content, index);
            _callback = callback;
        }

        override void performRequest() {
            AutocompleteResponse response = complete(request, *getModuleCache(_importPaths));
            if(response.completions is null || response.completions.length == 0){
                result.result = DCDResult.NO_RESULT;
                return;
            }

            result.result = DCDResult.SUCCESS;
            result.output.length = response.completions.length;
            result.completionKinds.length = response.completions.length;
            int i=0;
            foreach(s;response.completions) {
                char type = 0;
                if (i < response.completionKinds.length)
                    type = response.completionKinds[i];
                result.completionKinds[i] = type;
                result.output[i++] = to!dstring(s);
            }
            debug(DCD) Log.d("DCD output:\n", response.completions);
        }
        override void postResults() {
            _callback(result);
        }
    }

    DCDTask getCompletions(CustomEventTarget guiExecutor, string[] importPaths, string filename, string content, int index, void delegate(CompletionResultSet output) callback) {

        debug(DCD) Log.d("DCD Context: ", dumpContext(content, index));
        GetCompletionsTask task = new GetCompletionsTask(guiExecutor, importPaths, filename, content, index, callback);
        _queue.put(task);
        return task;
    }

}
