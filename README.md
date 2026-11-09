[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/buggins/dlangide?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)  [![CI](https://github.com/buggins/dlangide/actions/workflows/ci.yml/badge.svg)](https://github.com/buggins/dlangide/actions/workflows/ci.yml) [![PayPayl donate button](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=H2ADZV8S6TDHQ "Donate once-off to this project using Paypal")

Dlang IDE
=========

Cross platform D language IDE written in D using the [DlangUI](https://github.com/buggins/dlangui) library.
It works on Windows, Linux and macOS, and can also run in a text console.

Features
--------

* Projects:
  * DUB project format (dub.json or dub.sdl); dependency projects are shown in the workspace tree
  * New project wizard
  * Project specific settings: configuration, command line arguments, working directory
* Build and run:
  * Build, rebuild, clean and run projects with DUB; DUB package configuration selection (contributed by NCrashed); DUB dependencies update
  * Toolchain settings for DMD, LDC and GDC
  * Build log highlight and navigation to the place of an error or warning by clicking on a log line (contributed by Extrawurst)
  * Programs run in the internal terminal (Output panel) on Linux and macOS, or in an external terminal
  * Run single files with rdmd
* Debugging with GDB (Linux, macOS) or mago-mi (Windows): breakpoints, stepping, call stack, local variables and function parameters
* Source editor:
  * Syntax highlight for D, JSON and DML
  * Autocompletion while typing and by Ctrl+Space or Ctrl+Shift+G (using DCD)
  * Call tips with function signatures (Ctrl+Shift+Space)
  * Go to definition by Ctrl+G or F12, back and forward by Alt+Left and Alt+Right (using DCD)
  * Doc comments on mouse hover, or by Ctrl+Shift+D or Ctrl+F12 (using DCD)
  * Smart indents; indent / unindent with Tab and Shift+Tab or Ctrl+\] and Ctrl+\[
  * Toggle line or block comments by Ctrl+/ and Ctrl+Shift+/
  * Find, replace, find in files (Ctrl+Shift+F), bookmarks, go to line
* Other:
  * Light and dark themes
  * Configurable keyboard shortcuts
  * Viewer for DMD profiler logs (trace.log)
  * "Reveal in Explorer" for projects, folders and files

Screenshot of Default theme

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide.png "screenshot")

Screenshot of Dark theme

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide-dark.png "screenshot")

Screenshot of console mode (running in windows console)

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide-console-win32.png "screenshot")

Links:

* GitHub page: [https://github.com/buggins/dlangide](https://github.com/buggins/dlangide)
* Wiki: [https://github.com/buggins/dlangide/wiki](https://github.com/buggins/dlangide/wiki)
* DlangUI project GitHub page: [https://github.com/buggins/dlangui](https://github.com/buggins/dlangui)
* Mago debugger GitHub page: [https://github.com/rainers/mago](https://github.com/rainers/mago)


Try DlangIDE
============

You need a D compiler and DUB. Install DMD from [https://dlang.org/download.html](https://dlang.org/download.html)
(DUB is included), or LDC or GDC. DlangIDE needs DMD 2.100.2 or newer, or LDC 1.30 or newer.

Fetch, build and run the latest released version of DlangIDE:

    dub run dlangide --build=release

There are no pre-built binaries for current versions.

Linux notes
-----------

DlangIDE loads SDL2, FreeType and fontconfig at runtime. Most desktop distributions already have them.
Otherwise install them, e.g. on Debian / Ubuntu:

    sudo apt-get install libsdl2-2.0-0 libfreetype6 libfontconfig1

On Fedora and other RPM based distributions:

    sudo dnf install SDL2 freetype fontconfig

Other DUB configurations:

    dub run dlangide --build=release -c x11        # native X11 backend instead of SDL2
    dub run dlangide --build=release -c console    # text mode, runs in a terminal

The x11 configuration needs the X11 and GLX development packages to build (e.g. `libx11-dev libglx-dev`).

macOS notes
-----------

Install SDL2, which is used as the default backend, e.g. with Homebrew:

    brew install sdl2

If everything looks too small or too large, choose the screen DPI manually in
Edit / Preferences / Interface: Override screen DPI.

Windows notes
-------------

No additional libraries are needed: the default backend uses the Win32 API.
The mago-mi debugger is included in `libs/windows/x86`; set its path in Edit / Preferences / D / Debugger.


Build tools
===========

DlangIDE uses DUB as build tool, and its dub.json or dub.sdl as project file format.
You can select DMD, LDC or GDC compiler toolchain.


DCD integration
===============

Symbol lookup and autocompletion is using DCD (D completion daemon).

Hans-Albert Maritz (Freakazo) implementated DCD integration using DCD client/server.

Keywan Ghadami improved it to use DCD as a library.

Now DCD is embedded into DlangIDE, and no separate executables are needed.


Importing of existing project
=============================

DlangIDE supports only DUB project format.

To import existing DUB project, use menu item "File" / "Open project or workspace" and select dub.json or dub.sdl of your project to import.


Debugger support
================

* Linux and macOS: GDB
* Windows: mago-mi ([libs/windows/x86/mago-mi.exe](https://github.com/buggins/dlangide/blob/master/libs/windows/x86/mago-mi.exe))

Set the debugger executable in Edit / Preferences / D / Debugger.

Programs started without the debugger run in the internal terminal (Output panel) on Linux and macOS.


Building DlangIDE
=================

Build and run with DUB:

    git clone https://github.com/buggins/dlangide.git
    cd dlangide
    dub run

If you see build errors, try to upgrade dependencies:

    dub upgrade
    dub build --force

HINT: Try to open sample project Tetris, from workspaces/tetris with DlangIDE.


Keyboard shortcut settings
==========================

For Linux and macOS, keyboard shortcut settings are placed in file

    ~/.dlangide/shortcuts.json

For Windows, in directory like

    C:\Users\user\AppData\Roaming\.dlangide\shortcuts.json

If no such file exists, it's being created on DlangIDE start,
filling with default values to simplify configuration.

Just edit its content to redefine some key bindings.

File format is simple and intuitive. Example:

```json
{
    "EditorActions.Copy": "Ctrl+C",
    "EditorActions.Paste": "Ctrl+V",
    "EditorActions.Cut": "Ctrl+X",
    "EditorActions.Undo": "Ctrl+Z",
    "EditorActions.Redo": [
        "Ctrl+Y",
        "Ctrl+Shift+Z"
    ],
    "EditorActions.Indent": [
        "Tab",
        "Ctrl+]"
    ],
    "EditorActions.Unindent": [
        "Shift+Tab",
        "Ctrl+["
    ],
    "EditorActions.ToggleLineComment": "Ctrl+/",
    "EditorActions.ToggleBlockComment": "Ctrl+Shift+/"
}
```


Workspace include path setting
==============================

You can set additional import paths (for correct work with DCD) in the workspace settings file (e.g. newworkspace.dlangidews):

```json
{
    "name" : "newworkspace",
    "description" : null,
    "projects" : {
        "newproject" : "newproject/dub.json"
    },
    "includePath" : [
        "/usr/include/dlang/dmd/"
    ]
}
```


Development
===========

Clone the repository and build it with DUB (see above). Use any editor or IDE with D support,
e.g. DlangIDE itself, or VS Code with the code-d extension.

To work on DlangIDE together with DlangUI, clone both repositories next to each other:

    git clone https://github.com/buggins/dlangui.git
    git clone https://github.com/buggins/dlangide.git

and point DlangIDE to the local DlangUI checkout: in `dlangide/dub.selections.json`, replace the dlangui version
with `"dlangui": {"path": "../dlangui"}`.

Coding style: [https://github.com/buggins/dlangui/blob/master/CODING_STYLE.md](https://github.com/buggins/dlangui/blob/master/CODING_STYLE.md)

Please report bugs and feature requests in [GitHub issues](https://github.com/buggins/dlangide/issues).
Pull requests are welcome.


License
=======

Boost Software License 1.0, see [LICENSE.txt](LICENSE.txt).
