module app;

import dlangui;
import std.stdio;
import std.conv;
import dlangide.ui.frame;
import dlangide.ui.commands;
import dlangide.workspace.workspace;
import std.experimental.logger;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    debug(TestParser) {
        import ddc.lexer.parser;
        runParserTests();
    }

    version(Windows) {
        debug {
            sharedLog = new FileLogger("dcd.log");
        } else {
            sharedLog = new NullLogger();
        }
    } else {
        debug {
            //sharedLog = new FileLogger("dcd.log");
        } else {
            sharedLog = new NullLogger();
        }
    }

    //version (Windows) {
    //    import derelict.lldb.lldbtest;
    //    runLldbTests();
    //}

    // embed non-standard resources listed in views/resources.list into executable
    embeddedResourceList.addResources(embedResourcesFromList!("resources.list")());

    Platform.instance.uiTheme = "ide_theme_default";

    // you can override default hinting mode here
    //FontManager.hintingMode = HintingMode.Light;
    //FontManager.hintingMode = HintingMode.AutoHint;
    FontManager.hintingMode = HintingMode.Normal;
    //FontManager.hintingMode = HintingMode.Disabled;
    // you can override antialiasing setting here
    FontManager.minAnitialiasedFontSize = 0;
    /// set font gamma (1.0 is neutral, < 1.0 makes glyphs lighter, >1.0 makes glyphs bolder)
    FontManager.fontGamma = 0.8;
    version (USE_OPENGL) {
        // you can turn on subpixel font rendering (ClearType) here
        FontManager.subpixelRenderingMode = SubpixelRenderingMode.None; //
        FontManager.fontGamma = 0.9;
        FontManager.hintingMode = HintingMode.AutoHint;
    } else {
        version (USE_FREETYPE) {
            // you can turn on subpixel font rendering (ClearType) here
            FontManager.fontGamma = 0.8;
            //FontManager.subpixelRenderingMode = SubpixelRenderingMode.BGR; //SubpixelRenderingMode.None; //
            FontManager.hintingMode = HintingMode.AutoHint;
        }
    }

    //version(USE_WIN_DEBUG) {
    //    debuggerTest();
    //}
    //version(USE_GDB_DEBUG) {
    //    debuggerTestGDB();
    //}
    version(unittest) {
        return 0;
    } else {

        // create window
        Window window = Platform.instance.createWindow("Dlang IDE", null, WindowFlag.Resizable, 900, 730);
        static if (BACKEND_GUI) {
            // set window icon
            window.windowIcon = drawableCache.getImage("dlangui-logo1");
        }
    
        //Widget w = new Widget();
        //pragma(msg, w.click.return_t, "", w.click.params_t);

        IDEFrame frame = new IDEFrame(window);
        
        // Open project, if it specified in command line
        if (args.length > 1)
        {
            Action a = ACTION_FILE_OPEN_WORKSPACE.clone();
            a.stringParam = args[1].toAbsolutePath;
            frame.handleAction(a);
            // Mark that workspace opened to prevent auto open
            frame.isOpenedWorkspace(true);
        }

        // open home screen tab
        if (!frame.isOpenedWorkspace)
            frame.showHomeScreen();
        // for testing: load workspace at startup
        //frame.openFileOrWorkspace(appendPath(exePath, "../workspaces/sample1/sample1.dlangidews"));

        // show window
        window.show();
        // restore window state, size, position
        frame.restoreUIStateOnStartup();

        //jsonTest();

        // run message loop
        return Platform.instance.enterMessageLoop();
    }
}

/*
version(USE_WIN_DEBUG) {
    void debuggerTest() {
        import ddebug.windows.windebug;
        WinDebugger debugger = new WinDebugger("test\\dmledit.exe", "");
        debugger.start();
    }
}

version(USE_GDB_DEBUG) {
    void debuggerTestGDB() {
        import ddebug.gdb.gdbinterface;
        import core.thread;
        Log.d("Testing GDB debugger");
        DebuggerBase debugger = new DebuggerBase();
        debugger.startDebugging("gdb", "test", [], "", delegate(ResponseCode code, string msg) {
                Log.d("startDebugging result: ", code, " : ", msg);
                //assert(code == ResponseCode.NotImplemented);
            });
        debugger.stop();
        destroy(debugger);

        // async

        debugger = new GDBInterface();
        DebuggerProxy proxy = new DebuggerProxy(debugger, delegate(Runnable runnable) {
                runnable();
            });
        Log.d("calling debugger.start()");
        debugger.start();
        Log.d("calling proxy.startDebugging()");
        proxy.startDebugging("gdb", "/home/lve/src/d/dlangide/test/gdbtest", ["param1", "param2"], "/home/lve/src/d/dlangide/test", delegate(ResponseCode code, string msg) {
                Log.d("startDebugging result: ", code, " : ", msg);
                //assert(code == ResponseCode.NotImplemented);
            });
        Thread.sleep(dur!"msecs"(200000));
        debugger.stop();
        Thread.sleep(dur!"msecs"(200000));
        destroy(debugger);
        Log.d("Testing of GDB debugger is finished");
    }
}
*/

unittest {
    void jsonTest() {
        import dlangui.core.settings;
        Setting s = new Setting();
        s["param1_ulong"] = cast(ulong)1543453u;
        s["param2_long"] = cast(long)-22934;
        s["param3_double"] = -39.123e-10;
        s["param4_string"] = "some string value";
        s["param5_bool_true"] = true;
        s["param6_bool_false"] = false;
        s["param7_null"] = new Setting();
        Setting a = new Setting();
        a[0] = cast(ulong)1u;
        a[1] = cast(long)-2;
        a[2] = 3.3;
        a[3] = "some string value";
        a[4] = true;
        a[5] = false;
        a[6] = new Setting();
        Setting mm = new Setting();
        mm["n"] = cast(ulong)5u;
        mm["name"] = "test";
        a[7] = mm;
        s["param8_array"] = a;
        Setting m = new Setting();
        m["aaa"] = "bbb";
        m["aaa2"] = cast(ulong)5u;
        m["aaa3"] = false;
        s["param9_object"] = m;
        string json = s.toJSON(true);
        s.save("test_file.json");

        Setting loaded = new Setting();
        loaded.load("test_file.json");
        string json2 = loaded.toJSON(true);
        loaded.save("test_file2.json");
    }

}
