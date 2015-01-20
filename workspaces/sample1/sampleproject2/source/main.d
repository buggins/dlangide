#!/usr/bin/env rdmd
// Computes average line length for standard input.
import std.stdio;
import exlib.logger;
import exlib.files;
import exlib.i18n;

void main()
{
    ulong lines = 0;
    double sumLength = 0;
    foreach (line; stdin.byLine())
    {
        ++lines;
        sumLength += line.length;
    }
    writeln("Average line length: ",
        lines ? sumLength / lines : 0);
}
