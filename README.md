Dlang IDE
=========

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/buggins/dlangide?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Trying to write D language IDE using dlangUI library.

Currently supported features:

* Can open DUB (dub.json) projects
* Shows tree with project source files
* Can open source files from project or file system in multi-tab editor
* D language source code syntax highlight (basic)

Coming soon:

* Build project with DUB


Build and run with DUB:

	git clone https://github.com/buggins/dlangide.git
	cd dlangide
	dub run

To develop in VisualD together with DlangUI, put this project on the same level as dlangui repository, and its dependencies.


