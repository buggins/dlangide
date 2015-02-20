// Computes average line length for standard input.
//changed
class foo(T) {
private:
    static if (1) {
        int n() {
            T b;
            return 25; 
        }
    }
    string n;
}

struct bar(X: foo) {
    int n() { return 13; }
    debug long n;
    void func(T)(T param) {
        T a = param;
    }
}

void main(string[] args)
{
    int n;
    foo fooinst = new foo();
    n = 19 + foo.n;
    args[0] = "asd";
}

