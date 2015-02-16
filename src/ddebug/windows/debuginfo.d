module ddebug.windows.debuginfo;

version(Windows):
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
        Log.d("section rva=", rva, " sz=", sz);
        if (!sz)
            return null;
        enforce(pos + sz <= buf.length, new FileFormatException("sectionAt: index is outside file range"));
        return buf[rva .. rva + sz];
    }
    string stringzAt(uint pos, uint maxSize) {
        char[] res;
        for (uint p = pos; maxSize == 0 || p < pos + maxSize; p++) {
            ubyte ch = ubyteAt(p);
            if (!ch)
                break;
            res ~= ch;
        }
        return cast(string)res;
    }
    ubyte[] rangeAt(uint pos, uint size) {
        Log.d("rangeAt: pos=", pos, " size=", size, " pos+size=", pos+size, " buf.len=", buf.length);
        uint endp = pos + size;
        //if (endp > buf.length)
        //    endp = cast(uint)buf.length;
        enforce(pos <= endp, new FileFormatException("rangeAt: index is outside file range"));
        return buf[pos .. endp];
    }
}

struct Section {
    string name;
    uint vsize;
    uint rva;
    uint sz;
    uint offset;
    uint flags;
    this(ref Buffer buf, uint pos) {
        name = buf.stringzAt(pos, 8);
        vsize = buf.uintAt(pos + 0x08);
        rva = buf.uintAt(pos + 0x0C);
        sz = buf.uintAt(pos + 0x10);
        offset = buf.uintAt(pos + 0x14);
        flags = buf.uintAt(pos + 0x28);
    }
}

class OMFDebugInfo {
    Buffer data;
    uint peoffset;
    bool load(string filename) {
        try {
            data.buf = cast(ubyte[])std.file.read(filename);
            data.check(0, ['M', 'Z']);
            peoffset = data.uintAt(0x3c);
            Buffer pe;
            pe.buf = data.buf[peoffset .. $];
            //data.skip(peoffset);
            pe.check(0, ['P', 'E', 0, 0]);
            ushort objectCount = pe.ushortAt(0x06);
            ushort flags = pe.ushortAt(0x16); 
            ushort subsystem = pe.ushortAt(0x5c); 
            uint coffRva = pe.uintAt(0x0c);
            uint coffSize = pe.uintAt(0x10);
            Log.d("subsystem: ", subsystem, " flags: ", flags, " coffRva:", coffRva, " coffSize:", coffSize);
            //ubyte[] debugInfo = data.sectionAt(peoffset + 0xA8);
            //ubyte[] exportInfo = data.sectionAt(peoffset + 0x78);
            //ubyte[] importInfo = data.sectionAt(peoffset + 0x7c);
            //ubyte[] resInfo = data.sectionAt(peoffset + 0x88);
            //Buffer debugHeader;
            //debugHeader.buf = debugInfo;
            //uint debugType = debugHeader.uintAt(0x0C);
            //uint debugSize = debugHeader.uintAt(0x10);
            //uint debugRva = debugHeader.uintAt(0x14);
            //uint debugSeek = debugHeader.uintAt(0x18);
            //Log.d("debugInfo[", debugInfo.length, "] type=", debugType, " debugSize=", debugSize, " rva=", debugRva, " seek=", debugSeek, "  seek-rva=");
            //ubyte[] debugRaw = data.rangeAt(debugSeek, debugSize);
            //Log.d("debugRaw: ", debugRaw);
            ubyte[] debugData;
            for (int i = 0; i < objectCount; i++) {
                Section section = Section(data, peoffset + 0xF8 + i * 0x28);
                Log.d("section ", section.name, " rva=", section.rva, " sz=", section.sz, " offset=", section.offset);
                if (section.name.equal(".debug"))
                    debugData = data.rangeAt(section.offset, section.sz);
            }
            if (debugData) {
                string debugName = cast(string)debugData[1.. debugData[0] + 1];
                Log.d("Found debug data: name=", debugName, " sz=", debugData.length);
            }
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
