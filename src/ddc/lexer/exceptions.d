module ddc.lexer.exceptions;

import std.conv;

import ddc.lexer.textsource;

class ParserException : Exception {
    protected string _msg;
    protected SourceFile _file;
    protected int _line;
    protected int _pos;

    @property SourceFile file() { return _file; }
    @property string msg() { return _msg; }
    @property int line() { return _line; }
    @property int pos() { return _pos; }

    this(string msg, SourceFile file, int line, int pos) {
        super(msg ~ " at " ~ file.toString ~ " line " ~ to!string(line) ~ " column " ~ to!string(pos));
        _msg = msg;
        _file = file;
        _line = line;
        _pos = pos;
    }
}

class LexerException : ParserException {
    this(string msg, SourceFile file, int line, int pos) {
        super(msg, file, line, pos);
    }
}

class SourceEncodingException : LexerException {
    this(string msg, SourceFile file, int line, int pos) {
        super(msg, file, line, pos);
    }
}
