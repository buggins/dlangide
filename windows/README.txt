DlangIDE {VERSION} for Windows ({ARCH})
==============================================

DlangIDE is an IDE for the D programming language, built on DlangUI.
https://github.com/buggins/dlangide

Getting started
---------------

- Unpack the folder anywhere and run dlangide.exe.
- Install a D compiler with DUB: DMD (https://dlang.org/download.html) or
  LDC (https://github.com/ldc-developers/ldc/releases). DlangIDE finds
  dmd, ldc2 and dub on the PATH; their paths can also be set in
  Edit / Preferences.
- Open a project: File / Open project or workspace (dub.json, dub.sdl or
  a .dlangidews workspace), or pass a file or a folder on the command line:
      dlangide.exe C:\path\to\project

Requirements
------------

- Windows 10 version 1809 or later to run programs in the Output panel;
  on older Windows they run in a console window.
- LDC needs the Visual Studio Build Tools (or LDC's MinGW-based
  libraries) to link programs; DMD needs nothing else.

Debugging
---------

The mago-mi debugger is included. Programs are debugged when built with
debug information (DUB "debug" build, the default).
{DEBUGGER}

Settings are kept in %APPDATA%\.dlangide

Licenses
--------

dlangide.exe combines DlangIDE (Boost Software License 1.0, LICENSE.txt)
with DCD, the D Completion Daemon (GNU GPL v3), so the program as a whole is
distributed under the GNU General Public License v3, GPL-3.0.txt.
THIRD-PARTY.txt lists all included components with their licenses and where
to get the corresponding source code.

- mago debugger: Apache License 2.0, mago-LICENSE.txt, mago-NOTICE.txt
- udis86 disassembler: BSD, udis86-LICENSE.txt
- msdia140.dll: Microsoft Debug Interface Access, Visual Studio
  distributable code
{FREETYPE_LICENSE}
