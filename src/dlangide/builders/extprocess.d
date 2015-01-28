module dlangide.builders.extprocess;

import dlangui.core.logger;

import std.process;
import std.file;
import std.utf;

/// interface to forward process output to
interface ProcessOutputTarget {
    /// log lines
    void onText(dstring text);
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

/// runs external process, catches output, allows to stop
class ExternalProcess {

    protected char[][] _args;
    protected char[] _workDir;
    protected char[] _program;
    protected string[string] _env;
    protected ProcessOutputTarget _stdout;
    protected ProcessOutputTarget _stderr;
    protected ProcessPipes _pipes;
    protected ExternalProcessState _state;

    protected int _result;

    @property ExternalProcessState state() { return _state; }
    /// returns process result for stopped process
    @property int result() { return _result; }

    this() {
    }

    ExternalProcessState run(char[] program, char[][]args, char[] dir, ProcessOutputTarget stdoutTarget, ProcessOutputTarget stderrTarget = null) {
        _state = ExternalProcessState.None;
        _program = program;
        _args = args;
        _workDir = dir;
        _stdout = stdoutTarget;
        _stdoutBuffer.clear();
        _stderrBuffer.clear();
        _result = 0;
        assert(_stdout);
        _stderr = stderrTarget;
        Redirect redirect;
        char[][] params;
        params ~= _program;
        params ~= _args;
        if (!_stderr)
            redirect = Redirect.stdin | Redirect.stderrToStdout;
        else
            redirect = Redirect.all;
        Log.i("Trying to run program ", _program, " with args ", _args);
        try {
            _pipes = pipeProcess(params, redirect, _env, Config.none, _workDir);
            _state = ExternalProcessState.Running;
            _stdoutBuffer.init();
            if (_stderr)
                _stderrBuffer.init();
        } catch (ProcessException e) {
            Log.e("Cannot run program ", _program, " ", e);
        } catch (std.stdio.StdioException e) {
            Log.e("Cannot redirect streams for program ", _program, " ", e);
        }
        return _state;
    }

    static immutable READ_BUFFER_SIZE = 4096;
    static class Buffer {
        ubyte[] buffer;
        ubyte[] bytes;
        dchar[] textbuffer;
        bool utfError;
        size_t len;
        void init() {
            buffer = new ubyte[READ_BUFFER_SIZE];
            bytes = new ubyte[READ_BUFFER_SIZE * 2];
            textbuffer = new dchar[textbuffer.length];
            utfError = false;
            len = 0;
        }
        void addBytes(ubyte[] data) {
            if (bytes.length < len + data.length)
                bytes.length = bytes.length * 2 + len + data.length;
            for(size_t i = 0; i < data.length; i++)
                bytes[len++] = data[i];
        }
        size_t read(std.file.File file) {
            size_t bytesRead = 0;
            for (;;) {
                ubyte[] readData = file.rawRead(buffer);
                if (!readData.length)
                    break;
                bytesRead += readData.length;
                addBytes(readData);
                bytes ~= readData;
            }
            return bytesRead;
        }
        /// inplace convert line endings to unix format (\n)
        size_t convertLineEndings(dchar[] text) {
            size_t src = 0;
            size_t dst = 0;
            for(;src < text.length;) {
                dchar ch = text[src++];
                if (ch == '\n') {
                    if (src < text.length && text[src] == '\r')
                        src++;
                    text[dst++] = ch;
                } else if (ch == '\r') {
                    if (src < text.length && text[src] == '\n')
                        src++;
                    text[dst++] = '\n';
                } else {
                    text[dst++] = ch;
                }
            }
            return dst;
        }
        dstring text() {
            if (textbuffer.length < len)
                textbuffer.length = len;
            size_t count = 0;
            for(size_t i = 0; i < len;) {
                dchar ch = 0;
                if (utfError) {
                    ch = bytes[i++];
                } else {
                    try {
                        ch = decode(cast(string)bytes, i);
                    } catch (UTFException e) {
                        utfError = true;
                        ch = bytes[i++];
                        Log.d("non-unicode characters found in output of process");
                    }
                }
                textbuffer[count++] = ch;
            }
            len = 0;
            if (!count)
                return null;
            count = convertLineEndings(textbuffer[0..count]);
            return textbuffer[0 .. count].dup;
        }
        void clear() {
            buffer = null;
            bytes = null;
            textbuffer = null;
            len = 0;
        }
    }

    
    protected Buffer _stdoutBuffer;
    protected Buffer _stderrBuffer;

    protected bool poll(ProcessOutputTarget dst, std.file.File src, ref Buffer buffer) {
        if (src.isOpen) {
            buffer.read(src);
            dstring s = buffer.text;
            if (s)
                dst.onText(s);
            return true;
        } else {
            return false;
        }
    }

    protected bool pollStreams() {
        bool res = true;
        try {
            res = poll(_stdout, _pipes.stdout, _stdoutBuffer) && res;
            if (_stderr)
                res = poll(_stderr, _pipes.stderr, _stderrBuffer) && res;
        } catch (Error e) {
            Log.e("error occued while trying to poll streams for process ", _program);
            res = false;
        }
        return res;
    }

    /// polls all available output from process streams
    ExternalProcessState poll() {
        bool res = true;
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        if (_state == ExternalProcessState.Running) {
            res = pollStreams();
        }
        // check for process finishing
        try {
            auto pstate = tryWait(_pipes.pid);
            if (pstate.terminated) {
                pollStreams();
                _state = ExternalProcessState.Stopped;
                _result = pstate.status;
            }
        } catch (Exception e) {
            Log.e("Exception while waiting for process ", _program);
            _state = ExternalProcessState.Error;
        }
        return _state;
    }

    /// waits until termination
    ExternalProcessState wait() {
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        try {
            _result = wait(_pipes.pid);
            _state = ExternalProcessState.Stopped;
        } catch (Exception e) {
            Log.e("Exception while waiting for process ", _program);
            _state = ExternalProcessState.Error;
        }
        return _state;
    }

    /// request process stop
    ExternalProcessState kill() {
        if (_state == ExternalProcessState.Error || _state == ExternalProcessState.None || _state == ExternalProcessState.Stopped)
            return _state;
        if (_state == ExternalProcessState.Stopping) {
            kill(_pipes.pid);
        }
        return _state;
    }
}
