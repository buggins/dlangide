Dlang IDE
=========

Trying to write D language IDE using dlangUI library.

Currently supported features:

* Can open DUB (dub.json) projects
* Shows tree with project source files
* Can open source files from project or file system in multi-tab editor
* D language source code syntax highlight (basic)
* Build and run project with DUB

TODO:

* Improve look and feel
* Debugger support


Build and run with DUB:

	git clone https://github.com/buggins/dlangide.git
	cd dlangide
	dub run

Try to open sample project Tetris, from workspaces/tetris with DlangIDE.

To develop in VisualD together with DlangUI, put this project on the same level as dlangui repository, and its dependencies.


