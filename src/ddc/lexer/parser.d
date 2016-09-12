module ddc.lexer.parser;

import ddc.lexer.tokenizer;
import ddc.lexer.ast;
import dlangui.core.textsource;
import dlangui.core.logger;

class Parser {
    SourceLines _lines;
    SourceFile _file;
    Token[] _tokens;
    int[] _pairedBracket;
    int[] _bracketLevel;
    void init(SourceLines lines, SourceFile file) {
        _lines = lines;
        _file = file;
    }
    void init(dstring text, SourceFile file) {
        import std.array;
        ArraySourceLines lines = new ArraySourceLines();
        dstring[] src = text.split('\n');
        lines.initialize(src, file, 0);
        init(lines, file);
    }
    void init(dstring src, string filename) {
        init(src, new SourceFile(filename));
    }
    bool findBracketPairs() {
        bool res = true;
        _pairedBracket.length = _tokens.length;
        _pairedBracket[0 .. $] = -1;
        _bracketLevel.length = _tokens.length;
        _bracketLevel[0 .. $] = -1;
        return res;
    }
    bool tokenize() {
        bool res = false;
        Tokenizer tokenizer = new Tokenizer(_lines);
        //tokenizer.errorTolerant = true;
        try {
            _tokens = tokenizer.allTokens();
            Log.v("tokens: ", _tokens);
            findBracketPairs();
            res = true;
        } catch (Exception e) {
            // error
            Log.e("Tokenizer exception", e);
        }
        return res;
    }
}

ASTNode parseSource(dstring text, SourceFile file) {
    ASTNode res;
    Parser parser = new Parser();
    parser.init(text, file);
    parser.tokenize();
    return res;
}

ASTNode parseSource(dstring text, string filename) {
    return parseSource(text, new SourceFile(filename));
}

debug(TestParser):

void testParser(dstring source) {
    Log.setLogLevel(LogLevel.Trace);
    Log.d("Trying to parse\n", source);
    ASTNode res = parseSource(source, "main.d");
}

void runParserTests() {
    testParser(q{
        // testing parser
        import std.stdio;
        int main(string[]) {
        }
    });
}
