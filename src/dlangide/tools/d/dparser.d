module dlangide.tools.d.dparser;

version(USE_LIBDPARSE):

import dlangui.core.logger;

import std.d.lexer;
import std.d.parser;
import std.d.ast;
import std.algorithm;
import std.string;
import std.path;
import std.file;
import std.conv;

string importDeclToModuleName(const IdentifierChain chain) {
    char[] buf;
    foreach(token; chain.identifiers) {
        if (buf.length)
            buf ~= '.';
        buf ~= token.text;
    }
    return buf.dup;
}

class DParsedModule {
    protected string _moduleName;
    protected string _moduleFile;
    protected StringCache* _cache;
    protected Module _ast;
    protected string[] _imports;
    protected const(Token)[] _tokens;
    protected LexerConfig _lexerConfig;
    protected ubyte[] _sourceCode;

    @property string filename() { return _moduleFile; }
    /// module name, e.g. "std.stdio"
    @property string moduleName() { return _moduleName; }

    this(StringCache* cache, string filename) {
        _cache = cache;
        _moduleFile = filename;
    }

    static void msgFunction(string fn, size_t line, size_t col, string msg, bool isError) {
        debug(DParseErrors) Log.d("parser error: ", fn, "(", line, ":", col, ") : ", isError ? "Error: ": "Warning: ", msg);
    }

    static class ImportListIterator : ASTVisitor {
        string[] _imports;
        @property string[] imports() {
            return _imports;
        }
        private void addImport(string m) {
            foreach(imp; _imports)
                if (imp.equal(m))
                    return;
            _imports ~= m;
        }

        alias visit = ASTVisitor.visit;
        //override void visit(const Module module_) { 
        //    super.visit(module_); 
        //}
        override void visit(const ImportDeclaration importDeclaration) { 
            foreach(imp; importDeclaration.singleImports) {
                addImport(importDeclToModuleName(imp.identifierChain));
            }
        }

        void run(Module ast) {
            _imports.length = 0;
            visit(ast);
        }
    }
    private ImportListIterator _importIterator;
    void scanImports() {
        if (!_importIterator)
            _importIterator = new ImportListIterator();
        _importIterator.run(_ast);
        _imports = _importIterator.imports;
    }



    private IdentPositionIterator _identPositionIterator;
    IdentDefinitionLookupResult findTokenNode(const(Token)* tokenToFindPositionFor, const(Token)* tokenToFindReferencesFor) {
        if (!_identPositionIterator)
            _identPositionIterator = new IdentPositionIterator();
        auto foundNode = _identPositionIterator.run(this, _ast, tokenToFindPositionFor, tokenToFindReferencesFor);
        return foundNode;
    }


    void findDeclaration(int bytePosition, DParsedModule[string] scanned) {
        const(Token) * token = findIdentTokenByBytePosition(bytePosition);
        if (!token)
            return;

        Log.d("Identifier token found by position: ", token.text);
        IdentDefinitionLookupResult res = findTokenNode(token, token);
        if (!res.found)
            return;
        Log.d("Found in node:");
        res.found.dump();
    }

    const(Token) * findIdentTokenByBytePosition(int bytePosition) {
        const(Token) * res = null;
        for(int i = 0; i < _tokens.length; i++) {
            auto t = &_tokens[i];
            if (t.index >= bytePosition) {
                if (res && *res == tok!"identifier")
                    return res; // return this or previous identifier token
                if (t.index == bytePosition && (*t) == tok!"identifier")
                    return t; // return next identifier token
            }
            res = t;
        }
        return res;
    }

    void parse(ubyte[] sourceCode) {
        _sourceCode = sourceCode;
        _tokens = getTokensForParser(sourceCode, _lexerConfig, _cache);
        uint errorCount;
        uint warningCount;
        _ast = parseModule(_tokens, _moduleFile, null, &msgFunction, &errorCount, &warningCount);
        _moduleName = _ast.moduleDeclaration ? importDeclToModuleName(_ast.moduleDeclaration.moduleName) : null;
        scanImports();
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

    DParsedModule scan(ubyte[] sourceCode, string filename, ref DParsedModule[string] scanned) {
        Log.d("scanning ", filename);
        destroy(_notFoundModules);
        DParsedModule res = new DParsedModule(&_cache, filename);
        res.parse(sourceCode);
        _currentModule = res;
        Log.d("moduleName: ", res.moduleName, " imports: ", res.imports);
        Log.d("deps:");
        scanned[res.moduleName] = res;
        scanDeps(res, scanned);
        foreach(key, value; scanned) {
            Log.d("     module ", key, " : ", value ? value.filename : "NOT FOUND");
        }
        return res;
    }

    DParsedModule findDeclaration(ubyte[] sourceCode, string filename, int bytePosition) {
        DParsedModule[string] scanned;
        DParsedModule m = scan(sourceCode, filename, scanned);
        m.findDeclaration(bytePosition, scanned);
        return m;
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


static class ImportInfo {
    string moduleName;
    const ImportDeclaration decl;
    this(const ImportDeclaration decl, string moduleName) {
        this.decl = decl;
        this.moduleName = moduleName;
    }
}
enum DeclarationType {
    none,
    classVariableDeclaration,
    structVariableDeclaration,
    variableDeclaration,
    classDeclaration, // class declaration
    structDeclaration, // struct declaration
    classFunctionDeclaration, // function inside class
    structFunctionDeclaration, // function inside struct
    functionDeclaration, // just function
    functionParameter, // function parameter
    functionTemplateTypeParameter,
    classTemplateTypeParameter,
    structTemplateTypeParameter,
    templateTypeParameter,
}
static class IdentContext {
    DParsedModule mod;
    Token token;
    ImportInfo[] imports;
    const(ASTNode)[] stack;
    ASTNode declarationNode;
    ASTNode baseDeclarationNode;
    DeclarationType declarationType = DeclarationType.none;
    this(DParsedModule mod, const Token token, ImportInfo[] imports, const(ASTNode)[] stack) {
        this.mod = mod;
        this.token = token;
        this.imports = imports;
        this.stack = stack;
        initDeclarationType();
    }
    /// returns true if context ident token is the same as t
    bool sametok(const Token t) {
        return t.text.ptr is token.text.ptr;
    }
    /// casts top object on stack with specified offset to specified type and returns result
    T match(T)(int offset = 0) {
        if (offset < 0 || offset >= stack.length)
            return null;
        return cast(T)stack[$ - 1 - offset];
    }
    /// returns true if top object on stack is T1 and second is T2
    bool match(T1, T2)() {
        if (stack.length < 2)
            return false;
        return cast(T1)stack[$ - 1] !is null && cast(T2)stack[$ - 2] !is null;
    }
    /// returns true if top object on stack is T1 and second is T2
    bool match(T1, T2, T3)() {
        if (stack.length < 3)
            return false;
        return cast(T1)stack[$ - 1] !is null && cast(T2)stack[$ - 2] !is null && cast(T3)stack[$ - 3] !is null;
    }
    bool initDeclarationType() {
        if (match!(Declarator, VariableDeclaration) && sametok(match!Declarator.name)) {
            if (match!StructBody(2) && match!ClassDeclaration(3)) {
                declarationType = DeclarationType.classVariableDeclaration;
                declarationNode = match!VariableDeclaration(1);
                baseDeclarationNode = match!ClassDeclaration(3);
            } else if (match!StructBody(2) && match!StructDeclaration(3)) {
                declarationType = DeclarationType.structVariableDeclaration;
                declarationNode = match!VariableDeclaration(1);
                baseDeclarationNode = match!StructDeclaration(3);
            } else {
                declarationType = DeclarationType.variableDeclaration;
                declarationNode = match!VariableDeclaration(1);
            }
            return true;
        } else if (match!ClassDeclaration && sametok(match!ClassDeclaration.name)) {
            declarationType = DeclarationType.classDeclaration;
            declarationNode = match!ClassDeclaration;
            return true;
        } else if (match!StructDeclaration && sametok(match!StructDeclaration.name)) {
            declarationType = DeclarationType.structDeclaration;
            declarationNode = match!StructDeclaration;
            return true;
        } else if (match!FunctionDeclaration && sametok(match!FunctionDeclaration.name)) {
            if (match!StructBody(1) && match!ClassDeclaration(2)) {
                declarationType = DeclarationType.classFunctionDeclaration;
                declarationNode = match!FunctionDeclaration;
                baseDeclarationNode = match!ClassDeclaration(2);
            } else if (match!StructBody(1) && match!StructDeclaration(2)) {
                declarationType = DeclarationType.structFunctionDeclaration;
                declarationNode = match!FunctionDeclaration;
                baseDeclarationNode = match!StructDeclaration(2);
            } else {
                declarationType = DeclarationType.functionDeclaration;
                declarationNode = match!FunctionDeclaration;
            }
            return true;
        } else if (match!Parameter && sametok(match!Parameter.name) && match!Parameters(1)) {
            if (match!FunctionDeclaration(2)) {
                declarationType = DeclarationType.functionParameter;
                declarationNode = match!Parameter;
                baseDeclarationNode = match!FunctionDeclaration(2);
                return true;
            }
        } else if (match!TemplateTypeParameter && sametok(match!TemplateTypeParameter.identifier) && match!TemplateParameter(1) && match!TemplateParameterList(2) && match!TemplateParameters(3)) {
            if (match!FunctionDeclaration(4)) {
                declarationType = DeclarationType.functionTemplateTypeParameter;
                declarationNode = match!TemplateTypeParameter;
                baseDeclarationNode = match!FunctionDeclaration(4);
                return true;
            } else if (match!ClassDeclaration(4)) {
                declarationType = DeclarationType.classTemplateTypeParameter;
                declarationNode = match!TemplateTypeParameter;
                baseDeclarationNode = match!ClassDeclaration(4);
                return true;
            } else if (match!StructDeclaration(4)) {
                declarationType = DeclarationType.structTemplateTypeParameter;
                declarationNode = match!TemplateTypeParameter;
                baseDeclarationNode = match!StructDeclaration(4);
                return true;
            }
            declarationType = DeclarationType.templateTypeParameter;
            declarationNode = match!TemplateTypeParameter;
            return true;
        }
        return false;
    }
    void dump() {
        Log.d("module: ", mod.moduleName, 
              "\n\ttoken: ", token.text, "    [", token.line, ":", token.column, "-", token.index, "]   declType: ", declarationType, 
              " declNode: ", declarationNode, " baseDeclNode: ", baseDeclarationNode, 
              "\n\timports: ", imports, "\n\tcontext: ", stack);
    }   
}

static class IdentDefinitionLookupResult {
    DParsedModule mod;
    const(Token) tokenToFind;
    const(Token) tokenToFindReferences;
    IdentContext found;
    IdentContext[] references;
    this(DParsedModule mod, const(Token) * tokenToFind, const(Token) * tokenToFindReferences, IdentContext found, IdentContext[] references) {
        this.mod = mod;
        this.tokenToFind = *tokenToFind;
        this.tokenToFindReferences = *tokenToFindReferences;
        this.found = found;
        this.references = references;
    }
}

static class IdentPositionIterator : ASTVisitor {

    private const(Token) * _tokenToFind;
    private const(Token) * _tokenToFindReferences;
    private ImportInfo[] _scopedImportList;
    private const(ASTNode)[] _stack;
    private IdentContext _found;
    private IdentContext[] _references;
    private DParsedModule _mod;


    private void addImport(const ImportDeclaration decl, string m) {
        foreach(imp; _scopedImportList)
            if (imp.moduleName.equal(m))
                return;
        _scopedImportList ~= new ImportInfo(decl, m);
    }

    private void push(const ASTNode node) {
        _stack ~= node;
    }

    private const(ASTNode)pop() {
        assert(_stack.length > 0);
        auto res = _stack[$ - 1];
        _stack.length--;
        return res;
    }

    IdentDefinitionLookupResult run(DParsedModule mod, Module ast, const(Token) * tokenToFind, const(Token) * tokenToFindReferences) {
        _mod = mod;
        _stack.length = 0;
        _references.length = 0;
        _found = null;
        _tokenToFind = tokenToFind;
        _tokenToFindReferences = tokenToFindReferences;
        visit(ast);
        if (_references.length > 0) {
            Log.d("References to the same ident found: ");
            foreach(r; _references)
                r.dump();
        }
        return new IdentDefinitionLookupResult(_mod, _tokenToFind, _tokenToFindReferences, _found, _references);
    }

    //alias visit = ASTVisitor.visit;
    static string def(string param) {
        return "push(" ~ param ~ "); super.visit(" ~ param ~ "); pop();";
    }
    /// for objects which contain token not covered by visit()
    static string deftoken(string param, string tokenField) {
        return "push(" ~ param ~ "); visit(" ~ param ~ '.' ~ tokenField ~ "); super.visit(" ~ param ~ "); pop();";
    }
    /// for objects which can affect scope - save imports list, and restore after visiting
    static string defblock(string param) {
        return "size_t importPos = _scopedImportList.length; push(" ~ param ~ "); super.visit(" ~ param ~ "); pop(); _scopedImportList.length = importPos;";
    }

    @property private const(ASTNode)[] copyStack() {
        const(ASTNode)[] res;
        foreach(n; _stack)
            res ~= n;
        return res;
    }

    @property private ImportInfo[] copyImports() {
        ImportInfo[]res;
        foreach(imp; _scopedImportList)
            res ~= imp;
        return res;
    }

    override void visit(const Token t) {
        if (_tokenToFind && t.index == _tokenToFind.index) {
            _found = new IdentContext(_mod, t, copyImports, copyStack);
        } else if (_tokenToFindReferences && t.text.ptr is _tokenToFindReferences.text.ptr) {
            _references ~= new IdentContext(_mod, t, copyImports, copyStack);
        }
    }

    override void visit(const ExpressionNode n) { 
        //mixin(def("n")); 
        super.visit(n);
    }
    override void visit(const AddExpression addExpression) { mixin(def("addExpression")); }
    override void visit(const AliasDeclaration aliasDeclaration) {  mixin(def("aliasDeclaration")); }
    override void visit(const AliasInitializer aliasInitializer) { mixin(def("aliasInitializer")); }
    override void visit(const AliasThisDeclaration aliasThisDeclaration) { mixin(def("aliasThisDeclaration")); }
    override void visit(const AlignAttribute alignAttribute) { mixin(def("alignAttribute")); }
    override void visit(const AndAndExpression andAndExpression) { mixin(def("andAndExpression")); }
    override void visit(const AndExpression andExpression) { mixin(def("andExpression")); }
    override void visit(const AnonymousEnumDeclaration anonymousEnumDeclaration) { mixin(def("anonymousEnumDeclaration")); }
    override void visit(const AnonymousEnumMember anonymousEnumMember) { mixin(def("anonymousEnumMember")); }
    override void visit(const ArgumentList argumentList) { mixin(def("argumentList")); }
    override void visit(const Arguments arguments) { mixin(def("arguments")); }
    override void visit(const ArrayInitializer arrayInitializer) { mixin(def("arrayInitializer")); }
    override void visit(const ArrayLiteral arrayLiteral) { mixin(def("arrayLiteral")); }
    override void visit(const ArrayMemberInitialization arrayMemberInitialization) { mixin(def("arrayMemberInitialization")); }
    override void visit(const AsmAddExp asmAddExp) { mixin(def("asmAddExp")); }
    override void visit(const AsmAndExp asmAndExp) { mixin(def("asmAndExp")); }
    override void visit(const AsmBrExp asmBrExp) { mixin(def("asmBrExp")); }
    override void visit(const AsmEqualExp asmEqualExp) { mixin(def("asmEqualExp")); }
    override void visit(const AsmExp asmExp) { mixin(def("asmExp")); }
    override void visit(const AsmInstruction asmInstruction) { mixin(def("asmInstruction")); }
    override void visit(const AsmLogAndExp asmLogAndExp) { mixin(def("asmLogAndExp")); }
    override void visit(const AsmLogOrExp asmLogOrExp) { mixin(def("asmLogOrExp")); }
    override void visit(const AsmMulExp asmMulExp) { mixin(def("asmMulExp")); }
    override void visit(const AsmOrExp asmOrExp) { mixin(def("asmOrExp")); }
    override void visit(const AsmPrimaryExp asmPrimaryExp) { mixin(def("asmPrimaryExp")); }
    override void visit(const AsmRelExp asmRelExp) { mixin(def("asmRelExp")); }
    override void visit(const AsmShiftExp asmShiftExp) { mixin(def("asmShiftExp")); }
    override void visit(const AsmStatement asmStatement) { mixin(def("asmStatement")); }
    override void visit(const AsmTypePrefix asmTypePrefix) { mixin(def("asmTypePrefix")); }
    override void visit(const AsmUnaExp asmUnaExp) { mixin(def("asmUnaExp")); }
    override void visit(const AsmXorExp asmXorExp) { mixin(def("asmXorExp")); }
    override void visit(const AssertExpression assertExpression) { mixin(def("assertExpression")); }
    override void visit(const AssignExpression assignExpression) { mixin(def("assignExpression")); }
    override void visit(const AssocArrayLiteral assocArrayLiteral) { mixin(def("assocArrayLiteral")); }
    override void visit(const AtAttribute atAttribute) { 
        mixin(deftoken("atAttribute", "identifier")); 
    }
    override void visit(const Attribute attribute) { 
        mixin(deftoken("attribute", "attribute")); 
    }
    override void visit(const AttributeDeclaration attributeDeclaration) { mixin(def("attributeDeclaration")); }
    override void visit(const AutoDeclaration autoDeclaration) { mixin(def("autoDeclaration")); }
    override void visit(const BlockStatement blockStatement) { 
        mixin(defblock("blockStatement"));
    }
    override void visit(const BodyStatement bodyStatement) { mixin(def("bodyStatement")); }
    override void visit(const BreakStatement breakStatement) { mixin(def("breakStatement")); }
    override void visit(const BaseClass baseClass) { mixin(def("baseClass")); }
    override void visit(const BaseClassList baseClassList) { mixin(def("baseClassList")); }
    override void visit(const CaseRangeStatement caseRangeStatement) { mixin(def("caseRangeStatement")); }
    override void visit(const CaseStatement caseStatement) { mixin(def("caseStatement")); }
    override void visit(const CastExpression castExpression) { mixin(def("castExpression")); }
    override void visit(const CastQualifier castQualifier) { mixin(def("castQualifier")); }
    override void visit(const Catch catch_) { mixin(def("catch_")); }
    override void visit(const Catches catches) { mixin(def("catches")); }
    override void visit(const ClassDeclaration classDeclaration) { 
        mixin(deftoken("classDeclaration", "name")); 
    }
    override void visit(const CmpExpression cmpExpression) { mixin(def("cmpExpression")); }
    override void visit(const CompileCondition compileCondition) { mixin(def("compileCondition")); }
    override void visit(const ConditionalDeclaration conditionalDeclaration) { 
        super.visit(conditionalDeclaration);
        // Don't put conditional decl into stack
        // TODO: check conditional compilation conditions
        //mixin(def("conditionalDeclaration")); 
    }
    override void visit(const ConditionalStatement conditionalStatement) { mixin(def("conditionalStatement")); }
    override void visit(const Constraint constraint) { mixin(def("constraint")); }
    override void visit(const Constructor constructor) { mixin(def("constructor")); }
    override void visit(const ContinueStatement continueStatement) { mixin(def("continueStatement")); }
    override void visit(const DebugCondition debugCondition) { mixin(def("debugCondition")); }
    override void visit(const DebugSpecification debugSpecification) { mixin(def("debugSpecification")); }
    override void visit(const Declaration declaration) { 
        super.visit(declaration);
        //mixin(def("declaration")); 
    }
    override void visit(const DeclarationOrStatement declarationsOrStatement) { 
        super.visit(declarationsOrStatement);
        //mixin(def("declarationsOrStatement")); 
    }
    override void visit(const DeclarationsAndStatements declarationsAndStatements) { mixin(def("declarationsAndStatements")); }
    override void visit(const Declarator declarator) { 
        mixin(deftoken("declarator", "name"));
    }
    override void visit(const DefaultStatement defaultStatement) { mixin(def("defaultStatement")); }
    override void visit(const DeleteExpression deleteExpression) { mixin(def("deleteExpression")); }
    override void visit(const DeleteStatement deleteStatement) { mixin(def("deleteStatement")); }
    override void visit(const Deprecated deprecated_) { mixin(def("deprecated_")); }
    override void visit(const Destructor destructor) { mixin(def("destructor")); }
    override void visit(const DoStatement doStatement) { mixin(def("doStatement")); }
    override void visit(const EnumBody enumBody) { mixin(def("enumBody")); }
    override void visit(const EnumDeclaration enumDeclaration) { 
        mixin(deftoken("enumDeclaration", "name")); 
    }
    override void visit(const EnumMember enumMember) { mixin(def("enumMember")); }
    override void visit(const EponymousTemplateDeclaration eponymousTemplateDeclaration) { mixin(def("eponymousTemplateDeclaration")); }
    override void visit(const EqualExpression equalExpression) { mixin(def("equalExpression")); }
    override void visit(const Expression expression) { mixin(def("expression")); }
    override void visit(const ExpressionStatement expressionStatement) { mixin(def("expressionStatement")); }
    override void visit(const FinalSwitchStatement finalSwitchStatement) { mixin(def("finalSwitchStatement")); }
    override void visit(const Finally finally_) { mixin(def("finally_")); }
    override void visit(const ForStatement forStatement) { mixin(def("forStatement")); }
    override void visit(const ForeachStatement foreachStatement) { mixin(def("foreachStatement")); }
    override void visit(const ForeachType foreachType) { mixin(def("foreachType")); }
    override void visit(const ForeachTypeList foreachTypeList) { mixin(def("foreachTypeList")); }
    override void visit(const FunctionAttribute functionAttribute) { mixin(def("functionAttribute")); }
    override void visit(const FunctionBody functionBody) {
        mixin(defblock("functionBody"));
    }
    override void visit(const FunctionCallExpression functionCallExpression) { mixin(def("functionCallExpression")); }
    override void visit(const FunctionDeclaration functionDeclaration) { 
        mixin(deftoken("functionDeclaration", "name")); 
    }
    override void visit(const FunctionLiteralExpression functionLiteralExpression) { mixin(def("functionLiteralExpression")); }
    override void visit(const GotoStatement gotoStatement) { mixin(def("gotoStatement")); }
    override void visit(const IdentifierChain identifierChain) { mixin(def("identifierChain")); }
    override void visit(const IdentifierList identifierList) { mixin(def("identifierList")); }
    override void visit(const IdentifierOrTemplateChain identifierOrTemplateChain) { mixin(def("identifierOrTemplateChain")); }
    override void visit(const IdentifierOrTemplateInstance identifierOrTemplateInstance) { mixin(def("identifierOrTemplateInstance")); }
    override void visit(const IdentityExpression identityExpression) { mixin(def("identityExpression")); }
    override void visit(const IfStatement ifStatement) { mixin(def("ifStatement")); }
    override void visit(const ImportBind importBind) { mixin(def("importBind")); }
    override void visit(const ImportBindings importBindings) { mixin(def("importBindings")); }
    override void visit(const ImportDeclaration importDeclaration) {
        foreach(imp; importDeclaration.singleImports) {
            addImport(importDeclaration, importDeclToModuleName(imp.identifierChain));
        }
        mixin(def("importDeclaration")); 
    }
    override void visit(const ImportExpression importExpression) { mixin(def("importExpression")); }
    override void visit(const IndexExpression indexExpression) { mixin(def("indexExpression")); }
    override void visit(const InExpression inExpression) { mixin(def("inExpression")); }
    override void visit(const InStatement inStatement) { mixin(def("inStatement")); }
    override void visit(const Initialize initialize) { mixin(def("initialize")); }
    override void visit(const Initializer initializer) { mixin(def("initializer")); }
    override void visit(const InterfaceDeclaration interfaceDeclaration) { 
        mixin(deftoken("interfaceDeclaration", "name")); 
    }
    override void visit(const Invariant invariant_) { mixin(def("invariant_")); }
    override void visit(const IsExpression isExpression) { mixin(def("isExpression")); }
    override void visit(const KeyValuePair keyValuePair) { mixin(def("keyValuePair")); }
    override void visit(const KeyValuePairs keyValuePairs) { mixin(def("keyValuePairs")); }
    override void visit(const LabeledStatement labeledStatement) { mixin(def("labeledStatement")); }
    override void visit(const LambdaExpression lambdaExpression) { mixin(def("lambdaExpression")); }
    override void visit(const LastCatch lastCatch) { mixin(def("lastCatch")); }
    override void visit(const LinkageAttribute linkageAttribute) { mixin(def("linkageAttribute")); }
    override void visit(const MemberFunctionAttribute memberFunctionAttribute) { mixin(def("memberFunctionAttribute")); }
    override void visit(const MixinDeclaration mixinDeclaration) { mixin(def("mixinDeclaration")); }
    override void visit(const MixinExpression mixinExpression) { mixin(def("mixinExpression")); }
    override void visit(const MixinTemplateDeclaration mixinTemplateDeclaration) { mixin(def("mixinTemplateDeclaration")); }
    override void visit(const MixinTemplateName mixinTemplateName) { mixin(def("mixinTemplateName")); }
    override void visit(const Module module_) { mixin(def("module_")); }
    override void visit(const ModuleDeclaration moduleDeclaration) { mixin(def("moduleDeclaration")); }
    override void visit(const MulExpression mulExpression) { mixin(def("mulExpression")); }
    override void visit(const NewAnonClassExpression newAnonClassExpression) { mixin(def("newAnonClassExpression")); }
    override void visit(const NewExpression newExpression) { mixin(def("newExpression")); }
    override void visit(const NonVoidInitializer nonVoidInitializer) { mixin(def("nonVoidInitializer")); }
    override void visit(const Operands operands) { mixin(def("operands")); }
    override void visit(const OrExpression orExpression) { mixin(def("orExpression")); }
    override void visit(const OrOrExpression orOrExpression) { mixin(def("orOrExpression")); }
    override void visit(const OutStatement outStatement) { mixin(def("outStatement")); }
    override void visit(const Parameter parameter) { mixin(def("parameter")); }
    override void visit(const Parameters parameters) { mixin(def("parameters")); }
    override void visit(const Postblit postblit) { mixin(def("postblit")); }
    override void visit(const PowExpression powExpression) { mixin(def("powExpression")); }
    override void visit(const PragmaDeclaration pragmaDeclaration) { mixin(def("pragmaDeclaration")); }
    override void visit(const PragmaExpression pragmaExpression) { mixin(def("pragmaExpression")); }
    override void visit(const PrimaryExpression primaryExpression) { mixin(def("primaryExpression")); }
    override void visit(const Register register) { mixin(def("register")); }
    override void visit(const RelExpression relExpression) { mixin(def("relExpression")); }
    override void visit(const ReturnStatement returnStatement) { mixin(def("returnStatement")); }
    override void visit(const ScopeGuardStatement scopeGuardStatement) { mixin(def("scopeGuardStatement")); }
    override void visit(const SharedStaticConstructor sharedStaticConstructor) { mixin(def("sharedStaticConstructor")); }
    override void visit(const SharedStaticDestructor sharedStaticDestructor) { mixin(def("sharedStaticDestructor")); }
    override void visit(const ShiftExpression shiftExpression) { mixin(def("shiftExpression")); }
    override void visit(const SingleImport singleImport) { mixin(def("singleImport")); }
    override void visit(const SliceExpression sliceExpression) { mixin(def("sliceExpression")); }
    override void visit(const Statement statement) { 
        //mixin(def("statement")); 
        super.visit(statement);
    }
    override void visit(const StatementNoCaseNoDefault statementNoCaseNoDefault) { 
        super.visit(statementNoCaseNoDefault);
        //mixin(def("statementNoCaseNoDefault")); 
    }
    override void visit(const StaticAssertDeclaration staticAssertDeclaration) { mixin(def("staticAssertDeclaration")); }
    override void visit(const StaticAssertStatement staticAssertStatement) { mixin(def("staticAssertStatement")); }
    override void visit(const StaticConstructor staticConstructor) { mixin(def("staticConstructor")); }
    override void visit(const StaticDestructor staticDestructor) { mixin(def("staticDestructor")); }
    override void visit(const StaticIfCondition staticIfCondition) { mixin(def("staticIfCondition")); }
    override void visit(const StorageClass storageClass) { mixin(def("storageClass")); }
    override void visit(const StructBody structBody) { mixin(def("structBody")); }
    override void visit(const StructDeclaration structDeclaration) { 
        mixin(deftoken("structDeclaration", "name")); 
    }
    override void visit(const StructInitializer structInitializer) { mixin(def("structInitializer")); }
    override void visit(const StructMemberInitializer structMemberInitializer) { mixin(def("structMemberInitializer")); }
    override void visit(const StructMemberInitializers structMemberInitializers) { mixin(def("structMemberInitializers")); }
    override void visit(const SwitchStatement switchStatement) { mixin(def("switchStatement")); }
    override void visit(const Symbol symbol) { mixin(def("symbol")); }
    override void visit(const SynchronizedStatement synchronizedStatement) { mixin(def("synchronizedStatement")); }
    override void visit(const TemplateAliasParameter templateAliasParameter) { mixin(def("templateAliasParameter")); }
    override void visit(const TemplateArgument templateArgument) { mixin(def("templateArgument")); }
    override void visit(const TemplateArgumentList templateArgumentList) { mixin(def("templateArgumentList")); }
    override void visit(const TemplateArguments templateArguments) { mixin(def("templateArguments")); }
    override void visit(const TemplateDeclaration templateDeclaration) { mixin(def("templateDeclaration")); }
    override void visit(const TemplateInstance templateInstance) { mixin(def("templateInstance")); }
    override void visit(const TemplateMixinExpression templateMixinExpression) { mixin(def("templateMixinExpression")); }
    override void visit(const TemplateParameter templateParameter) { mixin(def("templateParameter")); }
    override void visit(const TemplateParameterList templateParameterList) { mixin(def("templateParameterList")); }
    override void visit(const TemplateParameters templateParameters) { mixin(def("templateParameters")); }
    override void visit(const TemplateSingleArgument templateSingleArgument) { mixin(def("templateSingleArgument")); }
    override void visit(const TemplateThisParameter templateThisParameter) { mixin(def("templateThisParameter")); }
    override void visit(const TemplateTupleParameter templateTupleParameter) { mixin(def("templateTupleParameter")); }
    override void visit(const TemplateTypeParameter templateTypeParameter) { mixin(def("templateTypeParameter")); }
    override void visit(const TemplateValueParameter templateValueParameter) { mixin(def("templateValueParameter")); }
    override void visit(const TemplateValueParameterDefault templateValueParameterDefault) { mixin(def("templateValueParameterDefault")); }
    override void visit(const TernaryExpression ternaryExpression) { mixin(def("ternaryExpression")); }
    override void visit(const ThrowStatement throwStatement) { mixin(def("throwStatement")); }
    override void visit(const TraitsExpression traitsExpression) { mixin(def("traitsExpression")); }
    override void visit(const TryStatement tryStatement) { mixin(def("tryStatement")); }
    override void visit(const Type type) { mixin(def("type")); }
    override void visit(const Type2 type2) { mixin(def("type2")); }
    override void visit(const TypeSpecialization typeSpecialization) { mixin(def("typeSpecialization")); }
    override void visit(const TypeSuffix typeSuffix) { mixin(def("typeSuffix")); }
    override void visit(const TypeidExpression typeidExpression) { mixin(def("typeidExpression")); }
    override void visit(const TypeofExpression typeofExpression) { mixin(def("typeofExpression")); }
    override void visit(const UnaryExpression unaryExpression) { 
        super.visit(unaryExpression);
        //mixin(def("unaryExpression")); 
    }
    override void visit(const UnionDeclaration unionDeclaration) { mixin(def("unionDeclaration")); }
    override void visit(const Unittest unittest_) { mixin(def("unittest_")); }
    override void visit(const VariableDeclaration variableDeclaration) { 
        mixin(def("variableDeclaration")); 
    }
    override void visit(const Vector vector) { mixin(def("vector")); }
    override void visit(const VersionCondition versionCondition) { mixin(def("versionCondition")); }
    override void visit(const VersionSpecification versionSpecification) { mixin(def("versionSpecification")); }
    override void visit(const WhileStatement whileStatement) { mixin(def("whileStatement")); }
    override void visit(const WithStatement withStatement) { mixin(def("withStatement")); }
    override void visit(const XorExpression xorExpression) { mixin(def("xorExpression")); }
}
