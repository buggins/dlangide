import std.stdio;
import for_rdmd_test;

void main()
{
    writeln("test!");
    debug writeln("I am in debug mode");
    writeln(inc(10));
}

int f(int x)
{
    return x*x;
}

unittest {
    writeln("unittest!");
    assert(f(0) == 0);
    assert(f(5) == 25);
    assert(f(-5) == 25);
}

