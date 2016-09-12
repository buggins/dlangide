module dlangide.builders.extprocess;

import dlangui.core.logger;

import std.process;
import std.stdio;
import std.utf;
import std.stdio;
import core.thread;
import core.sync.mutex;
import dlangui.core.files;

/// interface to forward process output to
interface TextWriter {
    /// log lines
    void writeText(dstring text);
}

/// interface to read text
interface TextReader {
    /// log lines
    dstring readText();
}

/// protected text storage box to read and write text from different threads
class ProtectedTextStorage : TextReader, TextWriter {

    private Mutex _mutex;
    private shared bool _closed;
    private dchar[] _buffer;

    this() {
        _mutex = new Mutex();
    }

    @property bool closed() { return _closed; }

    void close() {
        if (_closed)
            return;
        _closed = true;
        _buffer = null;
    }

    /// log lines
    override void writeText(dstring text) {
        if (!_closed) {
            // if not closed
            _mutex.lock();
            scope(exit) _mutex.unlock();
            // append text
            _buffer ~= text;
        }
    }

    /// log lines
    override dstring readText() {
        if (!_closed) {
            // if not closed
            _mutex.lock();
            scope(exit) _mutex.unlock();
            if (!_buffer.length)
                return null;
            dstring res = _buffer.dup;
            _buffer = null;
            return res;
        } else {
            // reading from closed
            return null;
        }
    }
}

enum ExternalProcessState : uint {
    /// not initialized
    None,
    /// running
    Running,
    /// stop is requested
    Stopping,
    /// stopped
    Stopped,
    /// error occured, e.g. cannot run process
    Error
}

/// base class for text reading from std.stdio.File in background thread
class BackgroundReaderBase : Thread {
    private std.stdio.File _file;
    private shared bool _finished;
    private ubyte[1] _byteBuffer;
    private ubyte[] _bytes;
    dchar[] _textbuffer;
    private int _len;
    private bool _utfError;

    this(std.stdio.File f) {
        super(&run);
        assert(f.isOpen());
        _file = f;
        _len = 0;
        _finished = false;
    }

    @property bool finished() {
        return _finished;
    }

    ubyte prevchar;
    void addByte(ubyte data) {
        if (_bytes.length < _len + 1)
            _bytes.length = _bytes.length ? _bytes.length * 2 : 1024;
        bool eolchar = (data == '\r' || data == '\n');
        bool preveol = (prevchar == '\r' || prevchar == '\n');
        _bytes[_len++] = data;
        if (data == '\n')
            flush();
        //if ((eolchar && !preveol) || (!eolchar && preveol) || data == '\n') {
        //    //Log.d("Flushing for prevChar=", prevchar, " newChar=", data);
        //    flush();
        //}
        prevchar = data;
    }
    void flush() {
        if (!_len)
            return;
        if (_textbuffer.length < _len)
            _textbuffer.length = _len + 256;
        size_t count = 0;
        for(size_t i = 0; i < _len;) {
            dchar ch = 0;
            if (_utfError) {
                ch = _bytes[i++];
            } else {
                try {
                    ch = decode(cast(string)_bytes, i);
                } catch (UTFException e) {
                    _utfError = true;
                    ch = _bytes[i++];
                    Log.d("non-unicode characters found in output of process");
                }
            }
            _textbuffer[count++] = ch;
        }
        _len = 0;

        if (!count)
            return;

        // fix line endings - must be '\n'
        count = convertLineEndings(_textbuffer[0..count]);

        // data is ready to send
        if (count)
            sendResult(_textbuffer[0..count].dup);
    }
    /// inplace convert line endings to unix format (\n)
    size_t convertLineEndings(dchar[] text) {
        size_t src = 0;
        size_t dst = 0;
        for(;src < text.length;) {
            dchar ch = text[src++];
            dchar nextch = src < text.length ? text[src] : 0;
            if (ch == '\n') {
                if (nextch == '\r')
                    src++;
                text[dst++] = '\n';
            } else if (ch == '\r') {
                if (nextch == '\n')
                    src++;
                text[dst++] = '\n';
            } else {
                text[dst++] = ch;
            }
        }
        return dst;
    }
    protected void sendResult(dstring text) {
        // override to deal with ready data
    }

    protected void handleFinish() {
        // override to do something when thread is finishing
    }

    private void run() {
        //Log.d("BackgroundReaderBase run() enter");
        // read file by bytes
        try {
            version (Windows) {
                import core.sys.windows.windows;
                // separate version for windows as workaround for hanging rawRead
                HANDLE h = _file.windowsHandle;
                DWORD bytesRead = 0;
                DWORD err;
                for (;;) {
                    BOOL res = ReadFile(h, _byteBuffer.ptr, 1, &bytesRead, null);
                    if (res) {
                        if (bytesRead == 1)
                            addByte(_byteBuffer[0]);
                    } else {
                        err = GetLastError();
                        if (err == ERROR_MORE_DATA) {
                            if (bytesRead == 1)
                                addByte(_byteBuffer[0]);
                            continue;
                        }
                        //if (err == ERROR_BROKEN_PIPE || err = ERROR_INVALID_HANDLE)
                        break;
                    }
                }
            } else {
                for (;;) {
                    //Log.d("BackgroundReaderBase run() reading file");
                    if (_file.eof)
                        break;
                    ubyte[] r = _file.rawRead(_byteBuffer);
                    if (!r.length)
                        break;
                    //Log.d("BackgroundReaderBase run() read byte: ", r[0]);
                    addByte(r[0]);
                }
            }
            _file.close();
            flush();
            //Log.d("BackgroundReaderBase run() closing file");
            //Log.d("BackgroundReaderBase run() file closed");
        } catch (Exception e) {
            //Log.e("Exception occured while reading stream: ", e);
        }
        handleFinish();
        _finished = true;
        //Log.d("BackgroundReaderBase run() exit");
    }

    void waitForFinish() {
        static if (false) {
            while (isRunning && !_finished)
                Thread.sleep( dur!("msecs")( 10 ) );
        } else {
            join(false);
        }
    }

}

/// reader which sends output text to TextWriter (warning: call will be made from background thread)
class BackgroundReader : BackgroundReaderBase {
    protected TextWriter _destination;
    this(std.stdio.File f, TextWriter destination) {
        super(f);
        assert(destination);
        _destination = destination;
    }
    override protected void sendResult(dstring text) {
        // override to deal with ready data
        _destination.writeText(text);
    }
    override protected void handleFinish() {
        // remove link to destination to help GC
        _destination = null;
    }
}

/// runs external process, catches output, allows to stop
class ExternalProcess {

    protected char[][] _args;
    protected char[] _workDir;
    protected char[] _program;
    protected string[string] _env;
    protected TextWriter _stdout;
    protected TextWriter _stderr;
    protected BackgroundReader _stdoutReader;
    protected BackgroundReader _stderrReader;
    protected ProcessPipes _pipes;
    protected ExternalProcessState _state;

    protected int _result;

    @property ExternalProcessState state() { return _state; }
    /// returns process result for stopped process
    @property int result() { return _result; }

    this() {
    }

    ExternalProcessState run(string program, string[]args, string dir, TextWriter stdoutTarget, TextWriter stderrTarget = null) {
        char[][] arguments;
        foreach(a; args)
            arguments ~= a.dup;
        return run(program.dup, arguments, dir.dup, stdoutTarget, stderrTarget);
    }
    ExternalProcessState run(char[] program, char[][]args, char[] dir, TextWriter stdoutTarget, TextWriter stderrTarget = null) {
        Log.d("ExternalProcess.run ", program, " ", args);
        _state = ExternalProcessState.None;
        _program = findExecutablePath(cast(string)program).dup;
        if (!_program) {
            _state = ExternalProcessState.Error;
            Log.e("Executable not found for ", program);
            return _state;
        }
        _args = args;
        _workDir = dir;
        _stdout = stdoutTarget;
        _stderr = stderrTarget;
        _result = 0;
        assert(_stdout);
        Redirect redirect;
        char[][] params;
        params ~= _program;
        params ~= _args;
        if (!_stderr)
            redirect = Redirect.stdout | Redirect.stderrToStdout | Redirect.stdin;
        else
            redirect = Redirect.all;
        Log.i("Trying to run program ", _program, " with args ", _args);
        try {
            _pipes = pipeProcess(params, redirect, _env, Config.suppressConsole, _workDir);
            _state = ExternalProcessState.Running;
            // start readers
            _stdoutReader = new BackgroundReader(_pipes.stdout, _stdout);
            _stdoutReader.start();
            if (_stderr) {
                _stderrReader = new BackgroundReader(_pipes.stderr, _stderr);
                _stderrReader.start();
            }
        } catch (ProcessException e) {
            Log.e("Cannot run program ", _program, " ", e);
        } catch (std.stdio.StdioException e) {
            Log.e("Cannot redirect streams for program ", _program, " ", e);
        } catch (Throwable e) {
            Log.e("Exception while trying to run program ", _program, " ", e);
        }
        return _state;
    }

    protected void waitForReadingCompletion() {
        try {
            if (_stdoutReader && !_stdoutReader.finished) {
                _pipes.stdout.detach();
                //Log.d("waitForReadingCompletion - waiting for stdout");
                _stdoutReader.waitForFinish();
                //Log.d("waitForReadingCompletion - joined stdout");
            }
            _stdoutReader = null;
        } catch (Exception e) {
            Log.e("Exception while waiting for stdout reading completion for ", _program, " ", e);
        }
        try {
            if (_stderrReader && !_stderrReader.finished) {
                _pipes.stderr.detach();
                //Log.d("waitForReadingCompletion - waiting for stderr");
                _stderrReader.waitForFinish();
                _stderrReader = null;
                //Log.d("waitForReadingCompletion - joined stderr");
            }
        } catch (Exception e) {
            Log.e("Exception while waiting for stderr reading completion for ", _program, " ", e);
        }
        //Log.d("waitForReadingCompletion - done");
    }

    /// polls all available output from process streams
    ExternalProcessState poll() {
        //Log.d("ExternalProcess.poll state = ", _state);
        bool res = true;
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        // check for process finishing
        try {
            auto pstate = std.process.tryWait(_pipes.pid);
            if (pstate.terminated) {
                _state = ExternalProcessState.Stopped;
                _result = pstate.status;
                waitForReadingCompletion();
            }
        } catch (Exception e) {
            Log.e("Exception while waiting for process ", _program);
            _state = ExternalProcessState.Error;
        }
        return _state;
    }

    /// waits until termination
    ExternalProcessState wait() {
        Log.d("ExternalProcess.wait");
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        try {
            _result = std.process.wait(_pipes.pid);
            _state = ExternalProcessState.Stopped;
            Log.d("ExternalProcess.wait : waitForReadingCompletion");
            waitForReadingCompletion();
        } catch (Exception e) {
            Log.e("Exception while waiting for process ", _program);
            _state = ExternalProcessState.Error;
        }
        return _state;
    }

    /// request process stop
    ExternalProcessState kill() {
        Log.d("ExternalProcess.kill");
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        if (_state == ExternalProcessState.Running) {
            std.process.kill(_pipes.pid);
            _state = ExternalProcessState.Stopping;
        }
        return _state;
    }

    bool write(string data) {
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped) {
            return false;
        } else {
            //Log.d("writing ", data.length, " characters to stdin");
            _pipes.stdin.write("", data);
            _pipes.stdin.flush();
            //_pipes.stdin.close();
            return true;
        }
    }
}
