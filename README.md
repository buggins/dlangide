Dlang IDE
=========

Cross platform D language IDE written using DlangUI library.

Currently supported features:

* Can open DUB (dub.json) projects
* Shows tree with project source files
* Can open and edit source files from project or file system in multi-tab editor
* Build and run project with DUB
* Build log highlight and navigation to place of error or warning by clicking on log line
* DUB dependencies update
* DUB package configuration selection (implemented by NCrashed)
* Dependency projects are shown in workspace tree

Source editor features:

* D language source code syntax highlight (basic)
* Indent / unindent text with Tab and Shift+Tab or Ctrl+\[ and Ctrl+\]
* Toggle line or block comments by Ctrl+/ and Ctrl+Shift+/
* D source code autocompletion by Ctrl+Space or Ctrl+Shift+G (using DCD)
* D source code Go To Definition by Ctrl+G or F12 (using DCD)
* D source code Smart Indents
* Select word by mouse double click


![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide.png "screenshot")

GitHub page: [https://github.com/buggins/dlangide](https://github.com/buggins/dlangide)

DlangUI project GitHub page: [https://github.com/buggins/dlangui](https://github.com/buggins/dlangui)

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/buggins/dlangide?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)  [![Build Status](https://travis-ci.org/buggins/dlangide.svg?branch=master)](https://travis-ci.org/buggins/dlangide) [![PayPayl donate button](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=H2ADZV8S6TDHQ "Donate once-off to this project using Paypal")


DCD integration
===============

Hans-Albert Maritz (Freakazo) recently implementated DCD integration.
For using of Autocompletion and Go To Definition, you need to install DCD.
(For Win32, built dcd-server.exe and dcd-client.exe are included, and will be copied by DUB during build).
dcd-client and dcd-server must be in the same directory as dlangide executable or in one of PATH dirs.
DlangIDE starts its own copy of DCD daemon on port 9167.


Building DlangIDE
=================

Build and run with DUB:

	git clone https://github.com/buggins/dlangide.git
	cd dlangide
	dub run

If you see build errors, try to upgrade dependencies:

	dub upgrade --force-remove

	
Needs DMD 2.066.1 to build.

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

