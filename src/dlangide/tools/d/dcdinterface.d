module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;
import dlangui.platforms.common.platform;
import ddebug.common.queue;

import core.thread;

import std.typecons;
import std.conv;
import std.string;

import std.experimental.allocator;
import std.experimental.allocator.mallocator;
import std.experimental.allocator.gc_allocator;

import dcd.server.autocomplete;
import dcd.common.messages;
import dsymbol.modulecache;

//alias SharedASTAllocator = CAllocatorImpl!(Mallocator);
//alias SharedASTAllocator = CAllocatorImpl!(Mallocator);
//alias SharedASTAllocator = CSharedAllocatorImpl!(Mallocator);
alias SharedASTAllocator = ASTAllocator;

enum DCDResult : int {
    SUCCESS,
    NO_RESULT,
    FAIL,
}

struct CompletionSymbol {
    dstring name;
    char kind;
}

import dlangide.tools.editortool : CompletionTypes;

alias DocCommentsResultSet = Tuple!(DCDResult, "result", string[], "docComments");
alias FindDeclarationResultSet = Tuple!(DCDResult, "result", string, "fileName", ulong, "offset");
alias CompletionResultSet = Tuple!(DCDResult, "result", CompletionSymbol[], "output", CompletionTypes, "type");


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
        request.fileName = _filename;
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
        if (_cancelled)
            return;
        performRequest();
        synchronized(this) {
            if (_cancelled)
                return;
            if (_guiExecutor)
                _guiExecutor.executeInUiThread(&postResults);
        }
    }
}

class ModuleCacheAccessor {
    import dsymbol.modulecache;
    //protected ASTAllocator _astAllocator;
    protected ModuleCache _moduleCache;
    this(in string[] importPaths) {
        _moduleCache = ModuleCache(new SharedASTAllocator);
        _moduleCache.addImportPaths(importPaths);
    }
    protected ModuleCache * getModuleCache(in string[] importPaths) {
        _moduleCache.addImportPaths(importPaths);
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
        _moduleCache = new ModuleCacheAccessor(null);
        getModuleCache(null);
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
        destroyModuleCache();
    }

    import dsymbol.modulecache;

    protected string dumpContext(string content, int pos) {
        if (pos >= 0 && pos <= content.length) {
            int start = pos;
            int end = pos;
            for (int i = 0; start > 0 && content[start - 1] != '\n' && i < 10; i++)
                start--;
            // correct utf8 codepoint bounds
            while(start + 1 < content.length && ((content[start] & 0xC0) == 0x80)) {
                start++;
            }
            for (int i = 0; end < content.length - 1 && content[end] != '\n' && i < 10; i++)
                end++;
            // correct utf8 codepoint bounds
            while(end + 1 < content.length && ((content[end] & 0xC0) == 0x80)) {
                end++;
            }
            return content[start .. pos] ~ "|" ~ content[pos .. end];
        }
        return "";
    }

    /// DCD doc comments task
    class ModuleCacheWarmupTask : DCDTask {

        this(CustomEventTarget guiExecutor, string[] importPaths) {
            super(guiExecutor, importPaths, null, null, 0);
        }

        override void performRequest() {
            debug(DCD) Log.d("DCD - warm up module cache with import paths ", _importPaths);
            getModuleCache(_importPaths);
            debug(DCD) Log.d("DCD - module cache warm up finished");
        }
        override void postResults() {
        }
    }

    DCDTask warmUp(string[] importPaths) {
        debug(DCD) Log.d("DCD warmUp: ", importPaths);
        ModuleCacheWarmupTask task = new ModuleCacheWarmupTask(null, importPaths);
        _queue.put(task);
        return task;
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
            int i=0;
            foreach(s;response.completions) {
                char type = 0;
                if (i < response.completionKinds.length)
                    type = response.completionKinds[i];
                result.output[i].kind = type;
                result.output[i].name = to!dstring(s);
                i++;
            }
            if (response.completionType == "calltips") {
                result.type = CompletionTypes.CallTips;
            } else {
                result.type = CompletionTypes.IdentifierList;
                postProcessCompletions(result.output);
            }
            debug(DCD) Log.d("DCD response:\n", response, "\nCompletion result:\n", result.output);
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

int completionTypePriority(char t) {
    switch(t) {
        case 'c': // - class name
            return 10;
        case 'i': // - interface name
            return 10;
        case 's': // - struct name
            return 10;
        case 'u': // - union name
            return 10;
        case 'v': // - variable name
            return 5;
        case 'm': // - member variable name
            return 3;
        case 'k': // - keyword, built-in version, scope statement
            return 20;
        case 'f': // - function or method
            return 2;
        case 'g': // - enum name
            return 9;
        case 'e': // - enum member
            return 8;
        case 'P': // - package name
            return 30;
        case 'M': // - module name
            return 20;
        case 'a': // - array
            return 15;
        case 'A': // - associative array
            return 15;
        case 'l': // - alias name
            return 15;
        case 't': // - template name
            return 14;
        case 'T': // - mixin template name
            return 14;
        default:
            return 50;
    }
}

int compareCompletionSymbol(ref CompletionSymbol v1, ref CompletionSymbol v2) {
    import std.algorithm : cmp;
    int p1 = v1.kind.completionTypePriority;
    int p2 = v2.kind.completionTypePriority;
    if (p1 < p2)
        return -1;
    if (p1 > p2)
        return 1;
    return v1.name.cmp(v2.name);
}

bool lessCompletionSymbol(ref CompletionSymbol v1, ref CompletionSymbol v2) {
    return compareCompletionSymbol(v1, v2) < 0;
}

void postProcessCompletions(ref CompletionSymbol[] completions) {
    import std.algorithm.sorting : sort;
    completions.sort!(lessCompletionSymbol);
    CompletionSymbol[] res;
    bool hasKeywords = false;
    bool hasNonKeywords = false;
    bool[dstring] found;
    foreach(s; completions) {
        if (s.kind == 'k')
            hasKeywords = true;
        else
            hasNonKeywords = true;
    }
    // remove duplicates; remove keywords if non-keyword items are found
    foreach(s; completions) {
        if (!(s.name in found)) {
            found[s.name] = true;
            if (s.kind != 'k' || !hasNonKeywords) {
                res ~= s;
            }
        }
    }
    completions = res;
}


/// to test broken DCD after DUB invocation
/// run it after DCD ModuleCache is instantiated
void testDCDFailAfterThreadCreation() {
    import core.thread;

    Log.d("testDCDFailAfterThreadCreation");
    Thread thread = new Thread(delegate() {
        Thread.sleep(dur!"msecs"(2000));
    });
    thread.start();
    thread.join();
    Log.d("testDCDFailAfterThreadCreation finished");
}

