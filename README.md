Dlang IDE
=========

D language IDE written using DlangUI library.

Currently supported features:

* Can open DUB (dub.json) projects
* Shows tree with project source files
* Can open and edit source files from project or file system in multi-tab editor
* Build and run project with DUB
* Build log highlight and navigation to place of error or warning by clicking on log line
* DUB dependencies update

Source editor features:

* D language source code syntax highlight (basic)
* Indent / unindent text with Tab and Shift+Tab
* Toggle line or block comments by Ctrl+/ and Ctrl+Shift+/
* Select word by mouse double click


![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-dlangide.png "screenshot")

GitHub page: [https://github.com/buggins/dlangide](https://github.com/buggins/dlangide)

DlangUI project GitHub page: [https://github.com/buggins/dlangui](https://github.com/buggins/dlangui)


Build and run with DUB:

	git clone https://github.com/buggins/dlangide.git
	cd dlangide
	dub run
	
Needs DMD 2.066.1 to build.

HINT: Try to open sample project Tetris, from workspaces/tetris with DlangIDE.

To develop in VisualD together with DlangUI, put this project on the same level as dlangui repository, and its dependencies.
