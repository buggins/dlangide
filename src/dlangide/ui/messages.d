/// Translated messages with named placeholders, for the Output panel and similar texts (#600)
module dlangide.ui.messages;

import dlangui.core.i18n : UIString;
import std.array : replace;
import std.conv : to;

/**
    The translation of the string resource `id` with its `{name}` placeholders replaced. The arguments after the id
    are name/value pairs; values can be strings or numbers.

    Example: `trMsg("MSG_PROGRAM_EXIT_CODE", "file", exe, "code", exitCode)` for
    `MSG_PROGRAM_EXIT_CODE=Program {file} finished with exit code {code}`.
*/
dstring trMsg(Args...)(string id, Args args) {
    return fillPlaceholders(UIString.fromId(id).value, args);
}

/// `text` with its `{name}` placeholders replaced; the arguments are name/value pairs. The text is scanned once:
/// placeholder names inside inserted values (e.g. a path with "{code}" in it) are not replaced.
dstring fillPlaceholders(Args...)(dstring text, Args args) {
    static assert(Args.length % 2 == 0, "name/value pairs expected");
    static if (Args.length == 0) {
        return text;
    } else {
        dstring[dstring] values;
        static foreach (i; 0 .. Args.length / 2)
            values[to!dstring(args[2 * i])] = to!dstring(args[2 * i + 1]);
        dstring res;
        size_t pos = 0;
        while (pos < text.length) {
            if (text[pos] == '{') {
                size_t end = pos + 1;
                while (end < text.length && text[end] != '}' && text[end] != '{')
                    end++;
                if (end < text.length && text[end] == '}') {
                    if (auto value = text[pos + 1 .. end] in values) {
                        res ~= *value;
                        pos = end + 1;
                        continue;
                    }
                }
            }
            res ~= text[pos];
            pos++;
        }
        return res;
    }
}

unittest {
    assert(fillPlaceholders("Program {file} finished with exit code {code}"d, "file", "app.exe", "code", 3)
        == "Program app.exe finished with exit code 3"d);
    // dstring values, a placeholder used twice, one without a value stays as it is
    assert(fillPlaceholders("{a}-{a} {b}"d, "a", "x"d) == "x-x {b}"d);
    assert(fillPlaceholders("no placeholders"d) == "no placeholders"d);
    // values are inserted as they are, also when they contain placeholder names
    assert(fillPlaceholders("Program {file} finished with exit code {code}"d, "file", "/home/u/{code}/app", "code", 1)
        == "Program /home/u/{code}/app finished with exit code 1"d);
    // braces that are not placeholders
    assert(fillPlaceholders("{ {x} }{"d, "x", 1) == "{ 1 }{"d);
}

/// every message id used with trMsg in the sources is in en.ini, ru.ini and de.ini: a missing one would show
/// "UNTRANSLATED: <id>" in the Output panel (#600)
unittest {
    import std.file : dirEntries, SpanMode, readText, exists;
    import std.regex : matchAll, regex;
    import std.string : splitLines, indexOf, strip;
    import std.algorithm : sort, uniq;
    import std.array : array;
    // dub test runs in the package root; skip elsewhere
    if (!exists("src/dlangide/ui/messages.d") || !exists("views/res/i18n/en.ini"))
        return;
    string[] ids;
    foreach (entry; dirEntries("src", "*.d", SpanMode.depth))
        foreach (m; matchAll(readText(entry.name), regex(`trMsg\("([A-Z0-9_]+)"`)))
            ids ~= m[1];
    ids = ids.sort().uniq().array;
    assert(ids.length > 30, "trMsg ids not found in the sources");
    foreach (lang; ["en", "ru", "de"]) {
        bool[string] keys;
        foreach (line; readText("views/res/i18n/" ~ lang ~ ".ini").splitLines()) {
            auto eq = line.indexOf('=');
            if (eq > 0)
                keys[line[0 .. eq].strip] = true;
        }
        foreach (id; ids)
            assert(id in keys, "message " ~ id ~ " is missing in " ~ lang ~ ".ini");
    }
}
