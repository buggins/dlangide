#!/usr/bin/env dub
/+ dub.sdl:
    name "makeicon"
    dependency "dlangui" version="~>0.22.0"
    subConfiguration "dlangui" "minimal"
+/
/**
Makes the Windows icon files of DlangIDE from its SVG logo (#560):

$(UL
    $(LI windows/dlangide.ico: the icon of the installer, the shortcuts and the file types)
    $(LI windows/dlangide.res: the icon resource linked into dlangide.exe (dub.json, sourceFiles-windows))
)

Both hold the logo rendered at the sizes Windows uses: 32-bit bitmaps with alpha up to 64 px, PNG at 256 px.
Run from the repository root after changing views/res/dlangide-logo.32x32.svg: `dub run --single windows/makeicon.d`
*/
module makeicon;

import dlangui.graphics.images : renderSvgToSize;
import dlangui.graphics.drawbuf : ColorDrawBuf;
import std.bitmanip : nativeToBigEndian, nativeToLittleEndian;
import std.file : read, write;
import std.zlib : compress, crc32;

immutable int[] SIZES = [16, 20, 24, 32, 40, 48, 64, 256];
enum SVG = "views/res/dlangide-logo.32x32.svg";

ubyte[] le(T)(T v) { return nativeToLittleEndian(v).dup; }
ubyte[] be(T)(T v) { return nativeToBigEndian(v).dup; }

/// RGBA pixels of the logo at size x size (straight alpha; DlangUI's alpha is inverted)
ubyte[] renderRgba(const(ubyte)[] svg, int size) {
    ColorDrawBuf buf = renderSvgToSize(svg, size);
    scope (exit) destroy(buf);
    assert(buf.width == size && buf.height == size);
    ubyte[] res;
    foreach (y; 0 .. size)
        foreach (x; 0 .. size) {
            uint p = buf.scanLine(y)[x];
            res ~= [cast(ubyte)(p >> 16), cast(ubyte)(p >> 8), cast(ubyte)p, cast(ubyte)(255 - (p >> 24))];
        }
    return res;
}

/// a 32-bit DIB as ICO and RT_ICON use it: BITMAPINFOHEADER with double height, bottom-up BGRA rows, AND mask
ubyte[] dib(const(ubyte)[] rgba, int size) {
    int maskRow = ((size + 31) / 32) * 4;
    ubyte[] res = le!uint(40) ~ le!int(size) ~ le!int(size * 2) ~ le!ushort(1) ~ le!ushort(32) ~ le!uint(0)
        ~ le!uint(cast(uint)(size * size * 4 + maskRow * size)) ~ le!int(0) ~ le!int(0) ~ le!uint(0) ~ le!uint(0);
    foreach_reverse (y; 0 .. size)
        foreach (x; 0 .. size) {
            const(ubyte)[] p = rgba[(y * size + x) * 4 .. (y * size + x) * 4 + 4];
            res ~= [p[2], p[1], p[0], p[3]];
        }
    res ~= new ubyte[maskRow * size]; // all zero: the alpha channel decides
    return res;
}

/// a PNG file (RGBA)
ubyte[] png(const(ubyte)[] rgba, int size) {
    ubyte[] chunk(string type, const(ubyte)[] data) {
        ubyte[] td = cast(ubyte[])type.dup ~ data;
        return be!uint(cast(uint)data.length) ~ td ~ be!uint(crc32(0, td));
    }
    ubyte[] raw;
    foreach (y; 0 .. size)
        raw ~= cast(ubyte)0 ~ rgba[y * size * 4 .. (y + 1) * size * 4];
    ubyte[] ihdr = be!uint(size) ~ be!uint(size) ~ cast(ubyte[])[8, 6, 0, 0, 0];
    return cast(ubyte[])"\x89PNG\r\n\x1a\n".dup ~ chunk("IHDR", ihdr) ~ chunk("IDAT", cast(ubyte[])compress(raw))
        ~ chunk("IEND", null);
}

/// one resource of a .res file, with ordinal type and name
ubyte[] resEntry(ushort type, ushort name, ushort flags, const(ubyte)[] data, ushort language = 0x0409) {
    ubyte[] res = le!uint(cast(uint)data.length) ~ le!uint(32) ~ le!ushort(0xFFFF) ~ le!ushort(type)
        ~ le!ushort(0xFFFF) ~ le!ushort(name) ~ le!uint(0) ~ le!ushort(flags) ~ le!ushort(language) ~ le!uint(0)
        ~ le!uint(0) ~ data;
    while (res.length % 4)
        res ~= 0;
    return res;
}

void main() {
    const(ubyte)[] svg = cast(const(ubyte)[])read(SVG);
    ubyte[][] images;
    foreach (size; SIZES) {
        ubyte[] rgba = renderRgba(svg, size);
        images ~= size >= 256 ? png(rgba, size) : dib(rgba, size);
    }
    ubyte dim(int size) { return size >= 256 ? 0 : cast(ubyte)size; }
    // .ico: ICONDIR, ICONDIRENTRYs, images
    ubyte[] ico = le!ushort(0) ~ le!ushort(1) ~ le!ushort(cast(ushort)SIZES.length);
    uint offset = cast(uint)(6 + 16 * SIZES.length);
    foreach (i, size; SIZES) {
        ico ~= cast(ubyte[])[dim(size), dim(size), 0, 0] ~ le!ushort(1) ~ le!ushort(32) ~ le!uint(cast(uint)images[i].length)
            ~ le!uint(offset);
        offset += images[i].length;
    }
    foreach (img; images)
        ico ~= img;
    write("windows/dlangide.ico", ico);
    // .res: the empty first entry, RT_ICON 1..n, RT_GROUP_ICON 1 (GRPICONDIR with resource ids)
    enum ushort RT_ICON = 3, RT_GROUP_ICON = 14;
    ubyte[] res = resEntry(0, 0, 0, null, 0);
    ubyte[] group = le!ushort(0) ~ le!ushort(1) ~ le!ushort(cast(ushort)SIZES.length);
    foreach (i, size; SIZES) {
        res ~= resEntry(RT_ICON, cast(ushort)(i + 1), 0x1010, images[i]);
        group ~= cast(ubyte[])[dim(size), dim(size), 0, 0] ~ le!ushort(1) ~ le!ushort(32) ~ le!uint(cast(uint)images[i].length)
            ~ le!ushort(cast(ushort)(i + 1));
    }
    res ~= resEntry(RT_GROUP_ICON, 1, 0x1030, group);
    write("windows/dlangide.res", res);
}
