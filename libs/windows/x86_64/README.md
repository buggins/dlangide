# mago-mi debugger for Windows (x64)

DlangIDE uses `mago-mi.exe` on Windows to debug D programs: it speaks the GDB/MI protocol that DlangIDE's debugger client uses. These files are copied next to `dlangide.exe` when building on Windows (`copyFiles-windows` in `dub.json`).

| File | What | Source | License |
| --- | --- | --- | --- |
| `mago-mi.exe` | mago debugger with the GDB/MI front end, 64-bit | [rainers/mago](https://github.com/rainers/mago) master 4ef834a + [rainers/mago#41](https://github.com/rainers/mago/pull/41) | Apache 2.0, `mago-LICENSE.txt`, `mago-NOTICE.txt` |
| `udis86.dll` | x86/x64 disassembler used by mago | same build | BSD, `udis86-LICENSE.txt` |
| `msdia140.dll` | Microsoft Debug Interface Access (DIA) 14.51.36256.0, x64: reads PDB debug info | Visual Studio 2026, `DIA SDK\bin\amd64` | Microsoft distributable code ([Visual Studio 2026 redistribution list](https://learn.microsoft.com/en-us/visualstudio/releases/2026/redistribution)) |

mago loads `msdia140.dll` from its own folder, so no COM registration is needed.

## Supported programs

- 64-bit programs built with `-g` by DMD (x64) or LDC (x64): breakpoints, stepping, call stack, threads, locals and parameters with D-formatted values.
- 32-bit programs (DMD `-m32`) are not supported by the 64-bit mago-mi: it stops on unhandled WOW64 breakpoint exceptions. Upstream's 32-bit `mago-mi.exe` with the 64-bit `MagoRemote.exe` agent handles both.

## Building

Built 2026-11-11 with Visual Studio 2026 (toolset v145) and the "Visual Studio extension development" workload (Visual Studio SDK), as upstream's CI does:

```
msbuild "/p:Configuration=Release StaticDE;Platform=x64;PlatformToolset=v145" /target:MagoMI\mago-mi MagoDbg_2010.sln
```

The output is `bin\x64\Release\mago-mi.exe` and `udis86.dll`. mago-mi writes `mago-mi-debug.log` next to itself.
