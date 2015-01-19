module ddc.lexer.exceptions;

import std.conv;

class ParserException : Exception {
    string _msg;
    string _filename;
    size_t _line;
    size_t _pos;

    public @property size_t line() { return _line; }

    this(string msg, string filename, size_t line, size_t pos) {
        super(msg ~ " at " ~ filename ~ " line " ~ to!string(line) ~ " column " ~ to!string(pos));
        _msg = msg;
        _filename = filename;
        _line = line;
        _pos = pos;
    }
}

class LexerException : ParserException {
    this(string msg, string filename, size_t line, size_t pos) {
        super(msg, filename, line, pos);
    }
}

class SourceEncodingException : LexerException {
    this(string msg, string filename, size_t line, size_t pos) {
        super(msg, filename, line, pos);
    }
}
