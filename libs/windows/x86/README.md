# mago-mi debugger for Windows (x86)

The 32-bit counterpart of [`../x86_64`](../x86_64/README.md), copied next to `dlangide.exe` when DlangIDE is built for x86 (`copyFiles-windows-x86` in `dub.json`).

| File | What | Source | License |
| --- | --- | --- | --- |
| `mago-mi.exe` | mago debugger with the GDB/MI front end, 32-bit | [rainers/mago](https://github.com/rainers/mago) master 4ef834a + [rainers/mago#41](https://github.com/rainers/mago/pull/41) | Apache 2.0, `mago-LICENSE.txt`, `mago-NOTICE.txt`; udis86 (linked in): BSD, `udis86-LICENSE.txt` |
| `MagoRemote.exe` | 64-bit agent: the 32-bit mago-mi debugs 64-bit programs through it | same build, x64 | same |
| `msdia140.dll` | Microsoft Debug Interface Access (DIA) 14.51.36256.0, x86: reads PDB debug info | Visual Studio 2026, `DIA SDK\bin` | Microsoft distributable code ([Visual Studio 2026 redistribution list](https://learn.microsoft.com/en-us/visualstudio/releases/2026/redistribution)) |

mago-mi loads `msdia140.dll` from its own folder and finds `MagoRemote.exe` next to itself; no registration or registry setting is needed.

## Supported programs

32-bit (DMD `-m32`) and 64-bit programs built with `-g` by DMD or LDC: breakpoints, stepping, call stack, threads, locals and parameters with D-formatted values. 64-bit programs run under the `MagoRemote.exe` agent.

## Building

Built 2026-11-11 with Visual Studio 2026 (toolset v145) and the Visual Studio SDK, as upstream's CI does:

```
msbuild "/p:Configuration=Release StaticDE;Platform=Win32;PlatformToolset=v145" /target:MagoMI\mago-mi MagoDbg_2010.sln
msbuild "/p:Configuration=Release;Platform=x64;PlatformToolset=v145" /target:DebugEngine\MagoRemote MagoDbg_2010.sln
```

mago-mi writes `mago-mi-debug.log` next to itself.
