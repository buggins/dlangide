module dlangide.tools.d.dparser;

import std.d.lexer;
import std.d.parser;
import std.d.ast;
import std.algorithm;
import std.string;
import std.path;
import std.file;
import std.conv;

class DParsedModule {
    protected string _moduleName;
    protected string _moduleFile;
    protected StringCache* _cache;
    protected Module _ast;
    const(Token)[] _tokens;
    LexerConfig _lexerConfig;

    @property string filename() {
        return _moduleFile;
    }

    this(StringCache* cache, string filename) {
        _cache = cache;
        _moduleFile = filename;
    }

    void parse(ubyte[] sourceCode) {
        _tokens = getTokensForParser(sourceCode, _lexerConfig, _cache);
        _ast = parseModule(_tokens, _moduleFile);
    }
}

/// D source code parsing service
class DParsingService {

    protected static __gshared DParsingService _instance;
    /// singleton
    static @property DParsingService instance() {
        if (!_instance) {
            _instance = new DParsingService();
        }
        return _instance;
    }
    /// destroy singleton
    static void shutdown() {
        destroy(_instance);
        _instance = null;
    }

    protected StringCache _cache;
    protected string[] _importPaths;
    protected DParsedModule[] _modules;
    protected DParsedModule[string] _moduleByName;
    protected DParsedModule[string] _moduleByFile;
    protected bool[string] _notFoundModules;

    this() {
        _cache = StringCache(16);
    }

    DParsedModule scan(ubyte[] sourceCode, string filename) {
        destroy(_notFoundModules);
        DParsedModule res = new DParsedModule(&_cache, filename);
        res.parse(sourceCode);
        return res;
    }

    /// converts some.module.name to some/module/name.d
    string moduleNameToPackagePath(string moduleName) {
        string[] pathSegments = moduleName.split(".");
        string normalized = buildNormalizedPath(pathSegments);
        return normalized ~ ".d";
    }

    string findModuleFile(string moduleName) {
        string packagePath = moduleNameToPackagePath(moduleName);
        foreach(ip; _importPaths) {
            string path = buildNormalizedPath(ip, packagePath);
            if (path.exists && path.isFile)
                return path;
        }
        return null;
    }

    DParsedModule getOrParseModule(string moduleName) {
        if (auto m = moduleName in _moduleByName) {
            return *m;
        }
        if (moduleName in _notFoundModules)
            return null; // already listed as not found
        string filename = findModuleFile(moduleName);
        if (!filename) {
            _notFoundModules[moduleName] = true;
            return null;
        }
        try {
            DParsedModule res = new DParsedModule(&_cache, filename);
            ubyte[] sourceCode = cast(ubyte[])read(filename);
            res.parse(sourceCode);
            _moduleByName[moduleName] = res;
            _moduleByFile[filename] = res;
            return res;
        } catch (Exception e) {
            _notFoundModules[moduleName] = true;
            return null;
        }
    }

    void addImportPaths(string[] paths) {
        foreach(p; paths) {
            string ap = absolutePath(buildNormalizedPath(p));
            bool found = false;
            foreach(ip; _importPaths)
                if (ip.equal(ap)) {
                    found = true;
                    break;
                }
            if (!found)
                _importPaths ~= ap;
        }
    }
}
