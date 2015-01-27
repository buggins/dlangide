module app;

import dlangui.all;
import std.stdio;
import std.conv;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangide.workspace.workspace;


mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    // embed non-standard resources listed in views/resources.list into executable
    embeddedResourceList.addResources(embedResourcesFromList!("resources.list")());

    // you can override default hinting mode here
    FontManager.hintingMode = HintingMode.Normal;
    // you can override antialiasing setting here
    FontManager.minAnitialiasedFontSize = 0;
	version (USE_OPENGL) {
		// you can turn on subpixel font rendering (ClearType) here
		FontManager.subpixelRenderingMode = SubpixelRenderingMode.None; //
	} else {
		// you can turn on subpixel font rendering (ClearType) here
		FontManager.subpixelRenderingMode = SubpixelRenderingMode.BGR; //SubpixelRenderingMode.None; //
	}

    // create window
    Window window = Platform.instance.createWindow("Dlang IDE", null);
	
    IDEFrame frame = new IDEFrame(window);

    // create some widget to show in window
    window.windowIcon = drawableCache.getImage("dlangui-logo1");

    // open home screen tab
    frame.showHomeScreen();
    // for testing: load workspace at startup
    //frame.loadWorkspace(appendPath(exePath, "../workspaces/sample1/sample1.dlangidews"));

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
