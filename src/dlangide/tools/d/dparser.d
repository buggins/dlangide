module dlangide.tools.d.dparser;

import dlangui.core.logger;

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
    protected string[] _imports;
    const(Token)[] _tokens;
    LexerConfig _lexerConfig;

    @property string filename() { return _moduleFile; }
    /// module name, e.g. "std.stdio"
    @property string moduleName() { return _moduleName; }

    this(StringCache* cache, string filename) {
        _cache = cache;
        _moduleFile = filename;
    }

    private static string importDeclToModuleName(IdentifierChain chain) {
        char[] buf;
        foreach(token; chain.identifiers) {
            if (buf.length)
                buf ~= '.';
            buf ~= token.text;
        }
        return buf.dup;
    }

    void scanImports(Declaration[] declarations) {
        foreach(d; declarations) {
            if (d.importDeclaration) {
                foreach(imp; d.importDeclaration.singleImports) {
                    addImport(importDeclToModuleName(imp.identifierChain));
                }
            } else if (d.declarations) {
                scanImports(d.declarations);
            }
       }
    }

    static void msgFunction(string fn, size_t line, size_t col, string msg, bool isError) {
        debug(DParseErrors) Log.d("parser error: ", fn, "(", line, ":", col, ") : ", isError ? "Error: ": "Warning: ", msg);
    }

    void parse(ubyte[] sourceCode) {
        _tokens = getTokensForParser(sourceCode, _lexerConfig, _cache);
        uint errorCount;
        uint warningCount;
        _ast = parseModule(_tokens, _moduleFile, null, &msgFunction, &errorCount, &warningCount);
        _moduleName = importDeclToModuleName(_ast.moduleDeclaration.moduleName);
        scanImports(_ast.declarations);

    }

    private void addImport(string m) {
        foreach(imp; _imports)
            if (imp.equal(m))
                return;
        _imports ~= m;
    }

    @property string[] imports() {
        return _imports;
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
    protected DParsedModule _currentModule; // current module

    this() {
        _cache = StringCache(16);
    }

    void scanDeps(DParsedModule m, ref DParsedModule[string]scanned) {
        foreach(imp; m.imports) {
            if (imp !in scanned) {
                DParsedModule impModule = getOrParseModule(imp);
                scanned[imp] = impModule;
                if (impModule)
                    scanDeps(impModule, scanned);
            }
        }
    }

    DParsedModule scan(ubyte[] sourceCode, string filename) {
        Log.d("scanning ", filename);
        destroy(_notFoundModules);
        DParsedModule res = new DParsedModule(&_cache, filename);
        res.parse(sourceCode);
        _currentModule = res;
        Log.d("moduleName: ", res.moduleName, " imports: ", res.imports);
        Log.d("deps:");
        DParsedModule[string] scanned;
        scanned[res.moduleName] = res;
        scanDeps(res, scanned);
        foreach(key, value; scanned) {
            Log.d("     module ", key, " : ", value ? value.filename : "NOT FOUND");
        }
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
            //Log.d("packagePath: ", packagePath, " importPath: ", ip);
            string path = buildNormalizedPath(ip, packagePath);
            if (path.exists && path.isFile) {
                //Log.d("found ", path);
                return path;
            }
            string pathImports = path ~ "i";
            if (pathImports.exists && pathImports.isFile) {
                //Log.d("found ", pathImports);
                return pathImports;
            }
        }
        return null;
    }

    DParsedModule getOrParseModule(string moduleName) {
        if (_currentModule) {
            if (moduleName.equal(_currentModule.moduleName))
                return _currentModule; // module being scanned
        }
        if (auto m = moduleName in _moduleByName) {
            return *m;
        }
        if (moduleName in _notFoundModules) {
            Log.d("module is in not found: ", moduleName);
            return null; // already listed as not found
        }
        string filename = findModuleFile(moduleName);
        if (!filename) {
            Log.d("module not found: ", moduleName);
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
            Log.d("exception while parsing: ", moduleName, " : ", e);
            _notFoundModules[moduleName] = true;
            return null;
        }
    }

    void addImportPaths(in string[] paths) {
        Log.d("addImportPaths: ", paths);
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
