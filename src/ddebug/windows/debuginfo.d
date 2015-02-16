module ddebug.windows.debuginfo;

import dlangui.core.logger;
import std.file;
import std.algorithm;
import std.conv;
import std.exception;

class FileFormatException : Exception {
    this(string msg, Exception baseException = null, string file = __FILE__, size_t line = __LINE__) {
        super(msg, baseException, file, line);
    }
    this(Exception baseException = null, string file = __FILE__, size_t line = __LINE__) {
        super("", baseException, file, line);
    }
    //this(string file = __FILE__, size_t line = __LINE__) {
    //    super("Exception while parsing file format", file, line);
    //}
}


struct Buffer {
    ubyte[] buf;
    void skip(uint bytes) {
        enforce(bytes <= buf.length, new FileFormatException("skip: index is outside file range"));
        buf = buf[bytes .. $];
    }
    uint uintAt(uint pos) {
        enforce(pos + 4 <= buf.length, new FileFormatException("uintAt: index is outside file range"));
        return cast(uint)buf[pos] | (cast(uint)buf[pos + 1] << 8) | (cast(uint)buf[pos + 2] << 16) | (cast(uint)buf[pos + 3] << 24);
    }
    ushort ushortAt(uint pos) {
        enforce(pos + 2 <= buf.length, new FileFormatException("ushortAt: index is outside file range"));
        return cast(ushort)buf[pos] | (cast(ushort)buf[pos + 1] << 8);
    }
    ubyte ubyteAt(uint pos) {
        enforce(pos + 1 <= buf.length, new FileFormatException("ubyteAt: index is outside file range"));
        return buf[pos];
    }
    //void check(uint pos, string data) {
    //    enforce(pos + data.length <= buf.length, new FileFormatException("check: index is outside file range"));
    //    enforce(equal(buf[pos..pos + data.length], cast(ubyte[])data), new FileFormatException("pattern does not match"));
    //}
    void check(uint pos, ubyte[] data) {
        enforce(pos + data.length <= buf.length, new FileFormatException("check: index is outside file range"));
        enforce(equal(buf[pos..pos + data.length], data), new FileFormatException("pattern does not match"));
    }

    ubyte[] sectionAt(uint pos) {
        uint rva = uintAt(pos);
        uint sz = uintAt(pos + 4);
        enforce(pos + sz <= buf.length, new FileFormatException("sectionAt: index is outside file range"));
        return buf[rva .. rva + sz];
    }
}

struct Section {

}

class OMFDebugInfo {
    Buffer data;
    uint peoffset;
    bool load(string filename) {
        try {
            data.buf = cast(ubyte[])std.file.read(filename);
            data.check(0, ['M', 'Z']);
            peoffset = data.uintAt(0x3c);
            data.skip(peoffset);
            data.check(0, ['P', 'E', 0, 0]);
            ushort objectCount = data.ushortAt(0x06);
            ushort flags = data.ushortAt(0x16); 
            ushort subsystem = data.ushortAt(0x5c); 
            return true;
        } catch (Exception e) {
            throw new FileFormatException(e);
        }
    }
}

debug(DebugInfo) {
    void debugInfoTest(string filename) {
        OMFDebugInfo omf = new OMFDebugInfo();
        Log.d("Loading debug info from file ", filename);
        try {
            if (omf.load(filename)) {
                Log.d("Loaded ok");
            } else {
                Log.d("Failed");
            }
        } catch (FileFormatException e) {
            Log.e("FileFormatException: ", e);
        }

    }

}
