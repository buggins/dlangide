/**
    Windows pseudo console (ConPTY, Windows 10 1809+): runs a console program with a real console whose screen
    is sent as a VT sequence stream over a pipe, like a pty on posix (#507).

    The IDE terminal (`dlangide.ui.terminal.TerminalDevice`) registers itself as a `PseudoConsoleHost` under its
    device name; `ProgramExecutionNoDebug` looks the host up by the tty name it is given and starts the program in it.
*/
module ddebug.common.conpty;

version (Windows):

import core.sys.windows.windows;
import core.sync.mutex;
import core.thread;
import dlangui.core.logger;

/// prefix of terminal device names served by a pseudo console host
enum CONPTY_DEVICE_PREFIX = "conpty:";

/// returns true if the device name is served by a pseudo console host
bool isPseudoConsoleDevice(string name) {
    import std.algorithm : startsWith;
    return name.startsWith(CONPTY_DEVICE_PREFIX);
}

/// a terminal that can run a program in a pseudo console
interface PseudoConsoleHost {
    /**
        Starts a program in a new pseudo console whose output goes to this host.
        Returns a process handle owned by the caller (close it with CloseHandle), or null with an error message.
    */
    HANDLE startProcess(string[] args, string workingDir, out string error);
}

private __gshared PseudoConsoleHost[string] _hosts;
private __gshared Mutex _hostsLock;

shared static this() {
    _hostsLock = new Mutex();
}

/// register terminal device by its name
void registerPseudoConsoleHost(string name, PseudoConsoleHost host) {
    synchronized (_hostsLock)
        _hosts[name] = host;
}

/// unregister terminal device
void unregisterPseudoConsoleHost(string name) {
    synchronized (_hostsLock)
        _hosts.remove(name);
}

/// find terminal device by name, null if not found
PseudoConsoleHost findPseudoConsoleHost(string name) {
    synchronized (_hostsLock) {
        if (auto p = name in _hosts)
            return *p;
    }
    return null;
}

// ConPTY API, loaded dynamically: kernel32 of Windows before 10 1809 doesn't have it
alias HPCON = void*;
private extern (Windows) nothrow @nogc {
    alias PFN_CreatePseudoConsole = HRESULT function(COORD size, HANDLE hInput, HANDLE hOutput, DWORD dwFlags, HPCON* phPC);
    alias PFN_ResizePseudoConsole = HRESULT function(HPCON hPC, COORD size);
    alias PFN_ClosePseudoConsole = void function(HPCON hPC);
    alias PFN_InitializeProcThreadAttributeList = BOOL function(void* lpAttributeList, DWORD dwAttributeCount, DWORD dwFlags, SIZE_T* lpSize);
    alias PFN_UpdateProcThreadAttribute = BOOL function(void* lpAttributeList, DWORD dwFlags, size_t Attribute,
        void* lpValue, SIZE_T cbSize, void* lpPreviousValue, SIZE_T* lpReturnSize);
    alias PFN_DeleteProcThreadAttributeList = void function(void* lpAttributeList);
}
private __gshared {
    PFN_CreatePseudoConsole pCreatePseudoConsole;
    PFN_ResizePseudoConsole pResizePseudoConsole;
    PFN_ClosePseudoConsole pClosePseudoConsole;
    PFN_InitializeProcThreadAttributeList pInitializeProcThreadAttributeList;
    PFN_UpdateProcThreadAttribute pUpdateProcThreadAttribute;
    PFN_DeleteProcThreadAttributeList pDeleteProcThreadAttributeList;
    bool _apiLoaded;
    bool _apiAvailable;
}

/// returns true if the pseudo console API is available (Windows 10 1809 or later)
bool pseudoConsoleAvailable() {
    if (!_apiLoaded) {
        _apiLoaded = true;
        HMODULE k32 = GetModuleHandleA("kernel32.dll");
        if (k32) {
            pCreatePseudoConsole = cast(PFN_CreatePseudoConsole)GetProcAddress(k32, "CreatePseudoConsole");
            pResizePseudoConsole = cast(PFN_ResizePseudoConsole)GetProcAddress(k32, "ResizePseudoConsole");
            pClosePseudoConsole = cast(PFN_ClosePseudoConsole)GetProcAddress(k32, "ClosePseudoConsole");
            pInitializeProcThreadAttributeList = cast(PFN_InitializeProcThreadAttributeList)GetProcAddress(k32, "InitializeProcThreadAttributeList");
            pUpdateProcThreadAttribute = cast(PFN_UpdateProcThreadAttribute)GetProcAddress(k32, "UpdateProcThreadAttribute");
            pDeleteProcThreadAttributeList = cast(PFN_DeleteProcThreadAttributeList)GetProcAddress(k32, "DeleteProcThreadAttributeList");
        }
        _apiAvailable = pCreatePseudoConsole && pResizePseudoConsole && pClosePseudoConsole
            && pInitializeProcThreadAttributeList && pUpdateProcThreadAttribute && pDeleteProcThreadAttributeList;
        if (!_apiAvailable)
            Log.w("ConPTY (CreatePseudoConsole) is not available: Windows 10 1809 or later is needed for the internal terminal");
    }
    return _apiAvailable;
}

private struct STARTUPINFOEXW {
    STARTUPINFOW StartupInfo;
    void* lpAttributeList;
}
private enum PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = 0x00020016;
private enum EXTENDED_STARTUPINFO_PRESENT = 0x00080000;

/// command line for CreateProcess from argument list, quoted as the Microsoft C runtime parses it
string windowsCommandLine(string[] args) {
    import std.process : escapeWindowsArgument;
    string res;
    foreach (i, a; args) {
        if (i)
            res ~= " ";
        res ~= escapeWindowsArgument(a);
    }
    return res;
}

/**
    One program run in a pseudo console: the console, its pipes, the process, and two threads.
    The reader thread delivers the VT output until the pipe is closed; the waiter thread closes the console
    when the process exits. Output keeps being read meanwhile: ClosePseudoConsole can block until it is drained.
*/
class PseudoConsoleSession {
    private HPCON _hpc;
    private HANDLE _inWrite;   // input written by the IDE
    private HANDLE _outRead;   // VT output read by the IDE
    private HANDLE _process;
    private Thread _reader;
    private Thread _waiter;
    private void delegate(string data) _onOutput;
    private shared bool _consoleClosed;

    /// output callback is called from the reader thread
    this(void delegate(string data) onOutput) {
        _onOutput = onOutput;
    }

    /// start a program; returns a duplicate process handle for the caller, or null with an error message
    HANDLE start(string[] args, string workingDir, short cols, short rows, out string error) {
        import std.utf : toUTF16z;
        if (!pseudoConsoleAvailable()) {
            error = "pseudo console is not available";
            return null;
        }
        HANDLE inRead, outWrite;
        if (!CreatePipe(&inRead, &_inWrite, null, 0) || !CreatePipe(&_outRead, &outWrite, null, 0)) {
            error = "cannot create pipes for the pseudo console";
            return null;
        }
        HRESULT hr = pCreatePseudoConsole(COORD(cols, rows), inRead, outWrite, 0, &_hpc);
        // the console has its own copies now
        CloseHandle(inRead);
        CloseHandle(outWrite);
        if (hr != S_OK) {
            import std.format : format;
            error = format("CreatePseudoConsole failed, hr=0x%08x", hr);
            closeHandles();
            return null;
        }
        _reader = new Thread(&readerProc);
        _reader.isDaemon = true;
        _reader.start();

        SIZE_T size = 0;
        pInitializeProcThreadAttributeList(null, 1, 0, &size);
        auto attrList = new ubyte[size];
        if (!pInitializeProcThreadAttributeList(attrList.ptr, 1, 0, &size)
                || !pUpdateProcThreadAttribute(attrList.ptr, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, _hpc, HPCON.sizeof, null, null)) {
            error = "cannot set up the pseudo console attribute";
            closeConsole();
            return null;
        }
        scope(exit) pDeleteProcThreadAttributeList(attrList.ptr);
        STARTUPINFOEXW si;
        si.StartupInfo.cb = si.sizeof;
        si.lpAttributeList = attrList.ptr;
        // null standard handles: the program uses the pseudo console even if the IDE's own handles are redirected
        si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
        PROCESS_INFORMATION pi;
        wchar[] cmdline = (windowsCommandLine(args) ~ "\0").dup.to16;
        const(wchar)* dir = workingDir.length ? workingDir.toUTF16z : null;
        if (!CreateProcessW(null, cmdline.ptr, null, null, FALSE, EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
                null, dir, &si.StartupInfo, &pi)) {
            import std.format : format;
            error = format("cannot start %s (error %d)", args.length ? args[0] : "", GetLastError());
            closeConsole();
            return null;
        }
        CloseHandle(pi.hThread);
        _process = pi.hProcess;
        HANDLE dup;
        DuplicateHandle(GetCurrentProcess(), _process, GetCurrentProcess(), &dup, 0, FALSE, DUPLICATE_SAME_ACCESS);
        _waiter = new Thread(&waiterProc);
        _waiter.isDaemon = true;
        _waiter.start();
        return dup;
    }

    /// send keyboard input (UTF-8, VT key sequences) to the program
    void write(string data) {
        if (!_inWrite || _consoleClosed)
            return;
        while (data.length) {
            DWORD written = 0;
            if (!WriteFile(_inWrite, data.ptr, cast(DWORD)data.length, &written, null) || !written)
                break;
            data = data[written .. $];
        }
    }

    /// change console size in character cells
    void resize(short cols, short rows) {
        if (_hpc && !_consoleClosed)
            pResizePseudoConsole(_hpc, COORD(cols, rows));
    }

    /// true while the program runs
    @property bool running() {
        return _process && WaitForSingleObject(_process, 0) == WAIT_TIMEOUT;
    }

    /// stop the program if it runs, close the console and wait for the output to be read
    void close() {
        if (_process && running)
            TerminateProcess(_process, 1);
        if (_waiter)
            _waiter.join(false);
        else
            closeConsole();
        if (_reader)
            _reader.join(false);
        closeHandles();
    }

    private void readerProc() {
        char[4096] buf;
        for (;;) {
            DWORD n = 0;
            if (!ReadFile(_outRead, buf.ptr, cast(DWORD)buf.length, &n, null) || n == 0)
                break; // console closed
            if (_onOutput)
                _onOutput(buf[0 .. n].idup);
        }
    }

    private void waiterProc() {
        WaitForSingleObject(_process, INFINITE);
        // the program's last output is drained by the reader thread while the console closes
        closeConsole();
    }

    private void closeConsole() {
        import core.atomic : cas;
        if (!cas(&_consoleClosed, false, true))
            return;
        if (_hpc) {
            pClosePseudoConsole(_hpc);
            _hpc = null;
        }
        if (_inWrite) {
            CloseHandle(_inWrite);
            _inWrite = null;
        }
    }

    private void closeHandles() {
        closeConsole();
        if (_outRead) {
            CloseHandle(_outRead);
            _outRead = null;
        }
        if (_process) {
            CloseHandle(_process);
            _process = null;
        }
    }
}

private wchar[] to16(char[] s) {
    import std.utf : toUTF16;
    return toUTF16(s).dup;
}
