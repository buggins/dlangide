[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/buggins/dlangide?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)  [![Build Status](https://travis-ci.org/buggins/dlangide.svg?branch=master)](https://travis-ci.org/buggins/dlangide) [![PayPayl donate button](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=H2ADZV8S6TDHQ "Donate once-off to this project using Paypal")

Dlang IDE
=========

2021年底 从 Github 导入: https://github.com/buggins/dlangide .
更新了dlangui 到 0.9.186, 现可正常编译运行。 基于libui, 暂不能drag-n-drop,
其它功能都正常。

Cross platform D language IDE written using DlangUI library.

Screenshot of Default theme

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide.png "screenshot")

Screenshot of Dark theme

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide-dark.png "screenshot")

Screenshot of console mode (running in windows console)

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide-console-win32.png "screenshot")

Currently supported features:

* Uses DUB (dub.json or dub.sdl) project format
* Shows tree with project source files
* Can open and edit source files from project or file system in multi-tab editor
* Build and run project with DUB
* Build log highlight and navigation to place of error or warning by clicking on log line (contributed by Extrawurst)
* DUB dependencies update
* DUB package configuration selection (contributed by NCrashed)
* Dependency projects are shown in workspace tree
* New project wizard
* Toolchain settings for DMD, LDC, GDC
* Project specific settings
* Basic debugger support using GDB (work in progress)


Source editor features:

* D language source code, json, dml syntax highlight
* Indent / unindent text with Tab and Shift+Tab or Ctrl+\[ and Ctrl+\]
* Toggle line or block comments by Ctrl+/ and Ctrl+Shift+/
* D source code autocompletion by Ctrl+Space or Ctrl+Shift+G (using DCD)
* D source code Go To Definition by Ctrl+G or F12 (using DCD)
* D source Doc comments display on mouse hover (using DCD)
* D source code Smart Indents
* Select word by mouse double click



GitHub page: [https://github.com/buggins/dlangide](https://github.com/buggins/dlangide)

Wiki: [https://github.com/buggins/dlangide/wiki](https://github.com/buggins/dlangide/wiki)

DlangUI project GitHub page: [https://github.com/buggins/dlangui](https://github.com/buggins/dlangui)

Mago debugger GitHub page: [https://github.com/rainers/mago](https://github.com/rainers/mago)


Try DlangIDE
============

You can use DUB utility and DMD compiler to download, build and run recent version of DlangIDE from GIT repository.

Pre-requisites: install DMD from [https://dlang.org/download.html](https://dlang.org/download.html). In recent DMD packages, DUB utility is included.

Now you can fetch, build and run DlangIDE:

    dub fetch dlangide
    dub run --build=release dlangide

OSX build notes
---------------

On OSX you will need to install libSDL2, which is used as a default backend.

E.g. use homebrew or some other package manager to install it.

    brew install sdl2

For troubleshooting of screen DPI detection (e.g. if everything is small on Retina display), 
you can choose DPI manually in menu Edit / Preferences / Interface : Override screen DPI.
(This issue will be fixed soon).

Linux build notes
-----------------

On Linux will need to install libSDL2, which is used as a default backend.

If it's not yet installed, install it in order to run DlangIDE.

For debian/ubuntu use:

    sudo apt-get install libsdl2-dev

For RPM based distributions:

    sudo yum install SDL2-devel


Windows build notes
-------------------

Pre-built win32 binaries can be found in releases section.

As well, you can build it yourself.

Recent builds with dmd under windows have issues with crash in OPTILINK linker from DMD.

Workaround: add --arch=x86_mscoff or --arch=x86_64 to DUB commandline

Build 32bit version using microsoft linker and COFF object and library file format:

    dub run --build=release --arch=x86_mscoff dlangide

Build 64bit version using microsoft linker:

    dub run --build=release --arch=x86_64 dlangide

Note: unlike default --arch=x86, both x86_mscoff and x86_64 have a dependency on linker from Visual Studio C++ compiler toolchain.


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

* Windows: use mago-mi debugger (https://github.com/buggins/dlangide/blob/master/libs/windows/x86/mago-mi.exe) or GDB
* Linux: use GDB or lldb-mi debugger
* OSX: use GDB or LLDBMI2 debugger


Building DlangIDE
=================

Build and run with DUB:

	git clone https://github.com/buggins/dlangide.git
	cd dlangide
	dub run

If you see build errors, try to upgrade dependencies:

        dub clean-caches
	dub upgrade --force-remove
	dub build --force

	
Needs DMD 2.066.1 or newer to build.


HINT: Try to open sample project Tetris, from workspaces/tetris with DlangIDE.

To develop in VisualD together with DlangUI, put this project on the same level as dlangui repository, and its dependencies.


Keyboard shortcut settings
===========================

Keyboard shortcuts settings support is added.

For linux and macos settings are placed in file

	~/.dlangide/shortcuts.json

For Windows, in directory like

	C:\Users\user\AppData\Roaming\.dlangide\shortcuts.json

If no such file exists, it's being created on DlangIDE start, 
filling with default values to simplify configuration.

Just edit its content to redefine some key bindings.

File format is simple and intuitive. Example:

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


Development environment setup
=============================

Howto hack DlangIDE.

For Windows, install MS Visual Studio (e.g. Community 2013) + VisualD plugin

Install GIT, DUB, DMD.


For Linux and OSX, install MonoDevelop + Mono-D plugin.

For Linux / OSX, additionally install libSDL2 and X11 development packages.


Create some folder to place sources, e.g. ~/src/d/

Clone DlangUI and DlangIDE repositories into source folder

        git clone --recursive https://github.com/buggins/dlangui.git
        git clone --recursive https://github.com/buggins/dlangide.git

Windows: open solution file with Visual-D

        dlangui/dlangui-msvc.sln

Linux: open solution file with Mono-D

        dlangide/dlangide-monod-linux.sln

OSX: open solution file with Mono-D

        dlangide/dlangide-monod-osx.sln

Choose dlangide as startup project.

Coding style: [https://github.com/buggins/dlangui/blob/master/CODING_STYLE.md](https://github.com/buggins/dlangui/blob/master/CODING_STYLE.md)


Workspace include path setting
==============================

Now you can set dmd includes paths (for correct work with DCD) in workspace settings file (newworkspace.dlangidews)
<pre>
example:
{
        "name" : "newworkspace",
        "description" : null,
        "projects" : {
                "newproject" : "newproject/dub.json"<br>
        },
        "includePath" : [
                "/usr/include/dlang/dmd/"
        ]
}
</pre>
