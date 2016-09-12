module ddc.lexer.parser;

import ddc.lexer.tokenizer;
import ddc.lexer.ast;
import dlangui.core.textsource;
import dlangui.core.logger;

ASTNode parseSource(dstring text, SourceFile file) {
    ASTNode res;
    import std.array;
    ArraySourceLines lines = new ArraySourceLines();
    dstring[] src = text.split('\n');
    lines.initialize(src, file, 0);
    Tokenizer tokenizer = new Tokenizer(lines);
    //tokenizer.errorTolerant = true;
    try {
        Token[] tokens = tokenizer.allTokens();
        ulong len = tokens.length;
        Log.v("tokens: ", tokens);
    } catch (Exception e) {
        // error
        Log.e("Tokenizer exception");
    }
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
