module ddebug.gdb.gdbmiparser;

import dlangui.core.logger;
import std.utf;
import std.conv : to;
import std.array : empty;
import std.algorithm : startsWith, equal;
import std.string : format;
import ddebug.common.debugger;

/// result class
enum ResultClass {
    done,
    running,
    connected,
    error,
    exit,
    other
}

/// async message class
enum AsyncClass {
    running,
    stopped,
    library_loaded,
    library_unloaded,
    thread_group_added,
    thread_group_started,
    thread_group_exited,
    thread_created,
    thread_exited,
    other
}

/// Parse GDB MI output string
MIValue parseMI(string s) {
    string src = s;
    try {
        bool err = false;
        //Log.e("Tokenizing MI output: " ~ src);
        MIToken[] tokens = tokenizeMI(s, err);
        if (err) {
            // tokenizer error
            Log.e("Cannot tokenize MI output `" ~ src ~ "`");
            return null;
        }
        //Log.v("Parsing tokens " ~ tokens.dumpTokens);
        MIValue[] items = parseMIList(tokens);
        //Log.v("Found " ~ to!string(items.length) ~ " values in list");
        return new MIList(items);
    } catch (Exception e) {
        Log.e("Cannot parse MI output `" ~ src ~ "`", e.msg);
        return null;
    }
}

string demangleFunctionName(string mangledName) {
    import std.ascii;
    if (!mangledName)
        return mangledName;
    string fn = mangledName;
    if (!fn.startsWith("_D")) {
        // trying to fix strange corrupted mangling under OSX/dmd/lldb
    	if (fn.length < 3 || fn[0]!='D' || !isDigit(fn[1]))
        	return mangledName;
        fn = "_" ~ mangledName;
    }
    import std.demangle;
    import std.ascii;
    //import core.demangle : Demangle;
    uint i = 0;
    for(; i < fn.length && (fn[i] == '_' || isAlphaNum(fn[i])); i++) {
        // next
    }
    string rest = i < fn.length ? fn[i .. $] : null;
    try {
        return demangle(fn[0..i]) ~ rest;
    } catch (Exception e) {
        // cannot demangle
        Log.v("Failed to demangle " ~ fn[0..i]);
        return mangledName;
    }
}

/*
    frame = {
            addr = "0x00000000004015b2",
            func = "D main",
            args = [],
            file = "source\app.d",
            fullname = "D:\projects\d\dlangide\workspaces\helloworld\helloworld/source\app.d",
            line = "8"
    },
*/
DebugFrame parseFrame(MIValue frame) {
    import std.path;
    if (!frame)
        return null;
    DebugFrame location = new DebugFrame();
    location.file = baseName(toNativeDelimiters(frame.getString("file")));
    location.projectFilePath = toNativeDelimiters(frame.getString("file"));
    location.fullFilePath = toNativeDelimiters(frame.getString("fullname"));
    location.line = frame.getInt("line");
    location.func = demangleFunctionName(frame.getString("func"));
    location.address = frame.getUlong("addr");
    location.from = toNativeDelimiters(frame.getString("from"));
    location.level = frame.getInt("level");
    return location;
}

DebugVariableList parseVariableList(MIValue params, string paramName = "variables") {
    if (!params)
        return null;
    DebugVariableList res = new DebugVariableList();
    MIValue list = params[paramName];
    if (list && list.isList) {
        for(int i = 0; i < list.length; i++) {
            if (DebugVariable t = parseVariable(list[i]))
                res.variables ~= t;
        }
    }
    return res;
}

DebugVariable parseVariable(MIValue params) {
    if (!params)
        return null;
    DebugVariable res = new DebugVariable();
    res.name = params.getString("name");
    res.value = params.getString("value");
    res.type = params.getString("type");
    return res;
}

DebugThreadList parseThreadList(MIValue params) {
    if (!params)
        return null;
    DebugThreadList res = new DebugThreadList();
    res.currentThreadId = params.getUlong("current-thread-id");
    MIValue threads = params["threads"];
    if (threads && threads.isList) {
        for(int i = 0; i < threads.length; i++) {
            if (DebugThread t = parseThread(threads[i]))
                res.threads ~= t;
        }
    }
    return res;
}

DebugThread parseThread(MIValue params) {
    if (!params)
        return null;
    DebugThread res = new DebugThread();
    res.id = params.getUlong("id");
    res.name = params.getString("target-id");
    if (res.name.empty)
        res.name = "Thread%d".format(res.id);
    string stateName = params.getString("state");
    if (stateName == "stopped")
        res.state = DebuggingState.paused;
    else if (stateName == "running")
        res.state = DebuggingState.running;
    else
        res.state = DebuggingState.stopped;
    res.frame = parseFrame(params["frame"]);
    return res;
}

DebugStack parseStack(MIValue params) {
    if (!params)
        return null;
    MIValue stack = params["stack"];
    if (!stack)
        return null;
    DebugStack res = new DebugStack();
    for (int i = 0; i < stack.length; i++) {
        MIValue item = stack[i];
        if (item && item.isKeyValue && item.key.equal("frame")) {
            DebugFrame location = parseFrame(item.value);
            if (location) {
                res.frames ~= location;
            }
        }
    }
    return res;
}

string toNativeDelimiters(string s) {
    version(Windows) {
        char[] buf;
        foreach(ch; s) {
            if (ch == '/')
                buf ~= '\\';
            else
                buf ~= ch;
        }
        return buf.dup;
    } else {
        return s;
    }
}

string parseIdent(ref string s) {
    string res = null;
    int len = 0;
    for(; len < s.length; len++) {
        char ch = s[len];
        if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '-'))
            break;
    }
    if (len > 0) {
        res = s[0..len];
        s = s[len .. $];
    }
    return res;
}

bool skipComma(ref string s) {
    if (s.length > 0 && s[0] == ',') {
        s = s[1 .. $];
        return true;
    }
    return false;
}

string parseIdentAndSkipComma(ref string s) {
    string res = parseIdent(s);
    skipComma(s);
    return res;
}

ResultClass resultByName(string s) {
    if (s.equal("done")) return ResultClass.done;
    if (s.equal("running")) return ResultClass.running;
    if (s.equal("connected")) return ResultClass.connected;
    if (s.equal("error")) return ResultClass.error;
    if (s.equal("exit")) return ResultClass.exit;
    return ResultClass.other;
}

AsyncClass asyncByName(string s) {
    if (s.equal("stopped")) return AsyncClass.stopped;
    if (s.equal("running")) return AsyncClass.running;
    if (s.equal("library-loaded")) return AsyncClass.library_loaded;
    if (s.equal("library-unloaded")) return AsyncClass.library_unloaded;
    if (s.equal("thread-group-added")) return AsyncClass.thread_group_added;
    if (s.equal("thread-group-started")) return AsyncClass.thread_group_started;
    if (s.equal("thread-group-exited")) return AsyncClass.thread_group_exited;
    if (s.equal("thread-created")) return AsyncClass.thread_created;
    if (s.equal("thread-exited")) return AsyncClass.thread_exited;
    return AsyncClass.other;
}

enum MITokenType {
    /// end of line
    eol,
    /// error
    error,
    /// identifier
    ident,
    /// C string
    str,
    /// = sign
    eq,
    /// , sign
    comma,
    /// { brace
    curlyOpen,
    /// } brace
    curlyClose,
    /// [ brace
    squareOpen,
    /// ] brace
    squareClose,
}

struct MIToken {
    MITokenType type;
    string str;
    this(MITokenType type, string str = null) {
        this.type = type;
        this.str = str;
    }
    string toString() {
        //return type == MITokenType.str ? to!string(type) ~ ":\"" ~ str ~ "\"": to!string(type) ~ ":" ~ str;
        return (type == MITokenType.str) ? "\"" ~ str ~ "\"" : str;
    }
}

MIToken parseMIToken(ref string s) {
    if (s.empty)
        return MIToken(MITokenType.eol);
    char ch = s[0];
    if (ch == ',') {
        s = s[1..$];
        return MIToken(MITokenType.comma, ",");
    }
    if (ch == '=') {
        s = s[1..$];
        return MIToken(MITokenType.eq, "=");
    }
    if (ch == '{') {
        s = s[1..$];
        return MIToken(MITokenType.curlyOpen, "{");
    }
    if (ch == '}') {
        s = s[1..$];
        return MIToken(MITokenType.curlyClose, "}");
    }
    if (ch == '[') {
        s = s[1..$];
        return MIToken(MITokenType.squareOpen, "[");
    }
    if (ch == ']') {
        s = s[1..$];
        return MIToken(MITokenType.squareClose, "]");
    }
    // C string
    if (ch == '\"') {
        string str = parseCString(s);
        if (!str.ptr) {
            return MIToken(MITokenType.error);
        }
        return MIToken(MITokenType.str, str);
    }
    // identifier
    string str = parseIdent(s);
    if (!str.empty)
        return MIToken(MITokenType.ident, str);
    return MIToken(MITokenType.error);
}

/// tokenize GDB MI output into array of tokens
MIToken[] tokenizeMI(string s, out bool error) {
    error = false;
    string src = s;
    MIToken[] res;
    for(;;) {
        MIToken token = parseMIToken(s);
        if (token.type == MITokenType.eol)
            break;
        if (token.type == MITokenType.error) {
            error = true;
            Log.e("Error while tokenizing GDB output ", src, " near ", s);
            break;
        }
        res ~= token;
    }
    return res;
}

string dumpTokens(MIToken[] tokens, int maxTokens = 40, int maxChars = 80) {
    char[] buf;
    for (int i = 0; i < maxTokens && i < tokens.length && buf.length < maxChars; i++) {
        buf ~= tokens[i].toString;
        buf ~= ' ';
    }
    return buf.dup;
}

MIValue parseMIValue(ref MIToken[] tokens) {
    MIToken[] srctokens;
    if (tokens.length == 0)
        throw new Exception("parseMIValue: Unexpected end of line when value is expected");
    MITokenType tokenType = tokens.length > 0 ? tokens[0].type : MITokenType.eol;
    MITokenType nextTokenType = tokens.length > 1 ? tokens[1].type : MITokenType.eol;
    if (tokenType == MITokenType.ident) {
        string ident = tokens[0].str;
        if (nextTokenType == MITokenType.eol || nextTokenType == MITokenType.comma) {
            MIValue res = new MIIdent(ident);
            tokens = tokens[1..$];
            return res;
        } else if (nextTokenType == MITokenType.eq) {
            tokens = tokens[1..$]; // skip ident
            tokens = tokens[1..$]; // skip =
            MIValue value = parseMIValue(tokens);
            //tokens = tokens[1..$]; // skip value
            MIValue res = new MIKeyValue(ident, value);
            return res;
        }
        throw new Exception("parseMIValue: Unexpected token " ~ tokens[0].toString ~ " near " ~ srctokens.dumpTokens);
    } else if (tokenType == MITokenType.str) {
        string str = tokens[0].str;
        tokens = tokens[1..$];
        return new MIString(str);
    } else if (tokenType == MITokenType.curlyOpen) {
        tokens = tokens[1..$];
        MIValue[] list = parseMIList(tokens, MITokenType.curlyClose);
        return new MIMap(list);
    } else if (tokenType == MITokenType.squareOpen) {
        tokens = tokens[1..$];
        MIValue[] list = parseMIList(tokens, MITokenType.squareClose);
        return new MIList(list);
    }
    throw new Exception("parseMIValue: unexpected token " ~ tokens[0].toString ~ " near " ~ srctokens.dumpTokens);
}

private MIValue[] parseMIList(ref MIToken[] tokens, MITokenType closingToken = MITokenType.eol) {
    //Log.v("parseMIList: " ~ tokens.dumpTokens);
    MIValue[] res;
    if (!tokens.length)
        return res;
    for (;;) {
        MITokenType tokenType = tokens.length > 0 ? tokens[0].type : MITokenType.eol;
        if (tokenType == closingToken) {
            if (tokenType != MITokenType.eol)
                tokens = tokens[1..$];
            return res;
        }
        if (tokenType == MITokenType.eol)
            throw new Exception("parseMIList: Unexpected eol in list");
        if (res.length > 0) {
            // comma required
            if (tokenType != MITokenType.comma)
                throw new Exception("parseMIList: comma expected, found " ~ tokens[0].toString ~ " near " ~ tokens.dumpTokens);
            tokens = tokens[1..$];
        }
        MIValue value = parseMIValue(tokens);
        res ~= value;
    }
}

enum MIValueType {
    /// ident
    empty,
    /// ident
    ident,
    /// c-string
    str,
    /// key=value pair
    keyValue,
    /// list []
    list,
    /// map {key=value, ...}
    map,
}

private void dumpLevel(ref char[] buf, int level) {
    for (int i = 0; i < level; i++)
        buf ~= "    ";
}

class MIValue {
    MIValueType type;
    this(MIValueType type) {
        this.type = type;
    }
    @property string str() { return null; }
    @property int length() { return 0; }
    MIValue opIndex(int index) { return null; }
    MIValue opIndex(string key) { return null; }
    @property bool isIdent() { return type == MIValueType.list; }
    @property bool isString() { return type == MIValueType.str; }
    @property bool isKeyValue() { return type == MIValueType.keyValue; }
    @property bool isMap() { return type == MIValueType.map; }
    @property bool isList() { return type == MIValueType.list; }
    @property string key() { return str; }
    @property MIValue value() { return this; }

    string getString(string name) {
        MIValue v = opIndex(name);
        if (!v)
            return null;
        return v.str;
    }

    int getInt(string name, int defValue = 0) {
        MIValue v = opIndex(name);
        if (!v)
            return defValue;
        string s = v.str;
        if (s.empty)
            return defValue;
        return cast(int)decodeNumber(s, defValue);
    }

    ulong getUlong(string name, ulong defValue = 0) {
        MIValue v = opIndex(name);
        if (!v)
            return defValue;
        string s = v.str;
        if (s.empty)
            return defValue;
        return decodeNumber(s, defValue);
    }

    string getString(int index) {
        MIValue v = opIndex(index);
        if (!v)
            return null;
        return v.str;
    }

    void dump(ref char[] buf, int level) {
        //dumpLevel(buf, level);
        buf ~= str;
    }
    override string toString() {
        char[] buf;
        dump(buf, 0);
        return buf.dup;
    }
}

class MIKeyValue : MIValue {
    private string _key;
    private MIValue _value;
    this(string key, MIValue value) {
        super(MIValueType.keyValue);
        _key = key;
        _value = value;
    }
    override @property string key() { return _key; }
    override @property MIValue value() { return _value; }
    override @property string str() { return _key; }
    override void dump(ref char[] buf, int level) {
        //dumpLevel(buf, level);
        buf ~= _key;
        buf ~= " = ";
        if (!value)
            buf ~= "null";
        else
            _value.dump(buf, level + 1);
    }
}

class MIIdent : MIValue {
    private string _ident;
    this(string ident) {
        super(MIValueType.ident);
        _ident = ident;
    }
    override @property string str() { return _ident; }
}

class MIString : MIValue {
    private string _str;
    this(string str) {
        super(MIValueType.str);
        _str = str;
    }
    override @property string str() { return _str; }
    override void dump(ref char[] buf, int level) {
        //dumpLevel(buf, level);
        buf ~= '\"';
        buf ~= str;
        buf ~= '\"';
    }
}

class MIList : MIValue {
    private MIValue[] _items;
    private MIValue[string] _map;
    
    override @property int length() { return cast(int)_items.length; }
    override MIValue opIndex(int index) { 
        if (index < 0 || index >= _items.length)
            return null;
        return _items[index];
    }
    
    override MIValue opIndex(string key) {
        if (key in _map) {
            MIValue res = _map[key];
            return res;
        }
        return null; 
    }
    
    this(MIValue[] items) {
        super(MIValueType.list);
        _items = items;
        // fill map
        foreach(item; _items) {
            if (item.type == MIValueType.keyValue) {
                if (!item.str.empty)
                    _map[item.str] = (cast(MIKeyValue)item).value;
            }
        }
    }
    override void dump(ref char[] buf, int level) {
        buf ~= (type == MIValueType.map) ? "{" : "[";
        if (length) {
            buf ~= "\n";
            for (int i = 0; i < length; i++) {
                dumpLevel(buf, level + 1);
                _items[i].dump(buf, level + 1);
                if (i < length - 1)
                    buf ~= ",";
                buf ~= "\n";
            }
            //buf ~= "\n";
            dumpLevel(buf, level - 1);
        }
        buf ~= (type == MIValueType.map) ? "}" : "]";
    }
}

class MIMap : MIList {
    this(MIValue[] items) {
        super(items);
        type = MIValueType.map;
    }
}

private char nextChar(ref string s) {
    if (s.empty)
        return 0;
    char ch = s[0];
    s = s[1 .. $];
    return ch;
}

string parseCString(ref string s) {
    char[] res;
    // skip opening "
    char ch = nextChar(s);
    if (!ch)
        return null;
    if (ch != '\"')
        return null;
    for (;;) {
        if (s.empty) {
            // unexpected end of string
            return null;
        }
        ch = nextChar(s);
        if (ch == '\"')
            break;
        if (ch == '\\') {
            // escape sequence
            ch = nextChar(s);
            if (ch >= '0' && ch <= '7') {
                // octal
                int number = (ch - '0');
                char ch2 = nextChar(s);
                char ch3 = nextChar(s);
                if (ch2 < '0' || ch2 > '7')
                    return null;
                if (ch3 < '0' || ch3 > '7')
                    return null;
                number = number * 8 + (ch2 - '0');
                number = number * 8 + (ch3 - '0');
                if (number > 255)
                    return null; // invalid octal number
                res ~= cast(char)number;
            } else {
                switch (ch) {
                    case 'n':
                        res ~= '\n';
                        break;
                    case 'r':
                        res ~= '\r';
                        break;
                    case 't':
                        res ~= '\t';
                        break;
                    case 'a':
                        res ~= '\a';
                        break;
                    case 'b':
                        res ~= '\b';
                        break;
                    case 'f':
                        res ~= '\f';
                        break;
                    case 'v':
                        res ~= '\v';
                        break;
                    case 'x': {
                        // 2 digit hex number
                        uint ch2 = decodeHexDigit(nextChar(s));
                        uint ch3 = decodeHexDigit(nextChar(s));
                        if (ch2 > 15 || ch3 > 15)
                            return null;
                        res ~= cast(char)((ch2 << 4) | ch3);
                        break;
                    }
                    default:
                        res ~= ch;
                        break;
                }
            }
        } else {
            res ~= ch;
        }
    }
    if (!res.length)
        return "";
    return res.dup;
}

/// decodes hex digit (0..9, a..f, A..F), returns uint.max if invalid
private uint decodeHexDigit(T)(T ch) {
    if (ch >= '0' && ch <= '9')
        return ch - '0';
    else if (ch >= 'a' && ch <= 'f')
        return ch - 'a' + 10;
    else if (ch >= 'A' && ch <= 'F')
        return ch - 'A' + 10;
    return uint.max;
}

private ulong decodeNumber(string s, ulong defValue) {
    if (s.empty)
        return defValue;
    if (s.length > 2 && s.startsWith("0x")) {
        s = s[2..$];
        ulong res = 0;
        foreach(ch; s) {
            uint digit = decodeHexDigit(ch);
            if (digit > 15)
                return defValue;
            res = res * 16 + digit;
        }
        return res;
    } else {
        return to!ulong(s);
    }
}
