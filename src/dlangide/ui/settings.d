module dlangide.ui.settings;

import dlangui.core.settings;
import dlangui.core.i18n;
import dlangui.graphics.fonts;
import dlangui.widgets.lists;
import dlangui.dialogs.settingsdialog;

public import dlangide.workspace.projectsettings;
public import dlangide.workspace.idesettings;
public import dlangide.workspace.workspacesettings;

/// create DlangIDE settings pages tree
SettingsPage createSettingsPages() {
    SettingsPage res = new SettingsPage("", UIString(""d));

    SettingsPage ui = res.addChild("interface", UIString("OPTION_INTERFACE"c));
    ui.addStringComboBox("interface/theme", UIString("OPTION_THEME"c), [
            StringListValue("ide_theme_default", "OPTION_DEFAULT"c), 
            StringListValue("ide_theme_dark", "OPTION_DARK"c)]);
    ui.addStringComboBox("interface/language", UIString("OPTION_LANGUAGE"c), [
            StringListValue("en", "MENU_VIEW_LANGUAGE_EN"c), 
            StringListValue("ru", "MENU_VIEW_LANGUAGE_RU"c), 
            StringListValue("es", "MENU_VIEW_LANGUAGE_ES"c),
	    StringListValue("cs", "MENU_VIEW_LANGUAGE_CS"c)]);

    ui.addIntComboBox("interface/hintingMode", UIString("OPTION_FONT_HINTING"c), [StringListValue(0, "OPTION_FONT_HINTING_NORMAL"c), 
                StringListValue(1, "OPTION_FONT_HINTING_FORCE"c), 
                StringListValue(2, "OPTION_FONT_HINTING_DISABLED"c), StringListValue(3, "OPTION_FONT_HINTING_LIGHT"c)]);
    ui.addIntComboBox("interface/minAntialiasedFontSize", UIString("OPTION_FONT_ANTIALIASING"c), 
                      [StringListValue(0, "OPTION_FONT_ANTIALIASING_ALWAYS_ON"c), 
                      StringListValue(12, "12"d), 
                      StringListValue(14, "14"d), 
                      StringListValue(16, "16"d), 
                      StringListValue(20, "20"d), 
                      StringListValue(24, "24"d), 
                      StringListValue(32, "32"d), 
                      StringListValue(48, "48"d), 
                      StringListValue(255, "OPTION_FONT_ANTIALIASING_ALWAYS_OFF"c)]);
    ui.addFloatComboBox("interface/fontGamma", UIString("OPTION_FONT_GAMMA"c), 
                   [
                    StringListValue(500,  "0.5   "d),
                    StringListValue(600,  "0.6   "d),
                    StringListValue(700,  "0.7   "d),
                    StringListValue(800,  "0.8   "d),
                    StringListValue(850,  "0.85  "d),
                    StringListValue(900,  "0.9   "d),
                    StringListValue(950,  "0.95  "d),
                    StringListValue(1000, "1.0   "d),
                    StringListValue(1050, "1.05  "d),
                    StringListValue(1100, "1.1   "d), 
                    StringListValue(1150, "1.15  "d), 
                    StringListValue(1200, "1.2   "d), 
                    StringListValue(1250, "1.25  "d), 
                    StringListValue(1300, "1.3   "d), 
                    StringListValue(1400, "1.4   "d), 
                    StringListValue(1500, "1.5   "d), 
                    StringListValue(1700, "1.7   "d), 
                    StringListValue(2000, "2.0   "d)]);

    SettingsPage ed = res.addChild("editors", UIString("OPTION_EDITORS"c));
    SettingsPage texted = ed.addChild("editors/textEditor", UIString("OPTION_TEXT_EDITORS"c));

    // font faces
    StringListValue[] faces;
    faces ~= StringListValue("Default", "OPTION_DEFAULT"c);
    import dlangui.graphics.fonts;
    import std.utf : toUTF32;
    FontFaceProps[] allFaces = FontManager.instance.getFaces();
    import std.algorithm.sorting : sort;
    auto fontComp = function(ref FontFaceProps a, ref FontFaceProps b) {
        if (a.family == FontFamily.MonoSpace && b.family != FontFamily.MonoSpace)
            return -1;
        if (a.family != FontFamily.MonoSpace && b.family == FontFamily.MonoSpace)
            return 1;
        if (a.face < b.face)
            return -1;
        if (a.face > b.face)
            return 1;
        return 0;
    };
    //auto sorted = allFaces.sort!((a, b) => (a.family == FontFamily.MonoSpace && b.family != FontFamily.MonoSpace) || (a.face < b.face));
    auto sorted = sort!((a, b) => fontComp(a, b) < 0)(allFaces);
    
    //allFaces = allFaces.sort!((a, b) => a.family == FontFamily.MonoSpace && b.family == FontFamily.MonoSpace || a.face < b.face);
    //for (int i = 0; i < allFaces.length; i++) {
    foreach (face; sorted) {
        if (face.family == FontFamily.MonoSpace)
            faces ~= StringListValue(face.face, "*"d ~ toUTF32(face.face));
        else
            faces ~= StringListValue(face.face, toUTF32(face.face));
    }
    texted.addStringComboBox("editors/textEditor/fontFace", UIString("OPTION_FONT_FACE"c), faces);

    texted.addNumberEdit("editors/textEditor/tabSize", UIString("OPTION_TAB"c), 1, 16, 4);
    texted.addCheckbox("editors/textEditor/useSpacesForTabs", UIString("OPTION_USE_SPACES"c));
    texted.addCheckbox("editors/textEditor/smartIndents", UIString("OPTION_SMART_INDENTS"c));
    texted.addCheckbox("editors/textEditor/smartIndentsAfterPaste", UIString("OPTION_SMART_INDENTS_PASTE"c));
    texted.addCheckbox("editors/textEditor/showWhiteSpaceMarks", UIString("OPTION_SHOW_SPACES"c));
    texted.addCheckbox("editors/textEditor/showTabPositionMarks", UIString("OPTION_SHOW_TABS"c));


    SettingsPage dlang = res.addChild("dlang", UIString("D"d));
    SettingsPage dub = dlang.addChild("dlang/dub", UIString("DUB"d));
    dub.addExecutableFileNameEdit("dlang/dub/executable", UIString("OPTION_DUB_EXECUTABLE"c), "dub");
    dub.addStringEdit("dlang/dub/additional_params", UIString("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage rdmd = dlang.addChild("dlang/rdmd", UIString("rdmd"d));
    rdmd.addExecutableFileNameEdit("dlang/rdmd/executable", UIString("OPTION_RDMD_EXECUTABLE"c), "rdmd");
    rdmd.addStringEdit("dlang/rdmd/additional_params", UIString("OPTION_RDMD_ADDITIONAL_PARAMS"c), "");
    SettingsPage ddebug = dlang.addChild("dlang/debugger", UIString("OPTION_DEBUGGER"c));
    version (Windows) {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString("OPTION_DEBUGGER_EXECUTABLE"c), "gdb");
    } else {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString("OPTION_DEBUGGER_EXECUTABLE"c), "mago-mi");
    }
    SettingsPage terminal = dlang.addChild("dlang/terminal", UIString("OPTION_TERMINAL"c));
    terminal.addExecutableFileNameEdit("dlang/terminal/executable", UIString("OPTION_TERMINAL_EXECUTABLE"c), "xterm");

    SettingsPage toolchains = dlang.addChild("dlang/toolchains", UIString("OPTION_TOOLCHANS"c));
    SettingsPage dmdtoolchain = toolchains.addChild("dlang/toolchains/dmd", UIString("DMD"d));
    dmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/dmd/executable", UIString("OPTION_DMD_EXECUTABLE"c), "dmd");
    dmdtoolchain.addStringEdit("dlang/toolchains/dmd/dub_additional_params", UIString("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage ldctoolchain = toolchains.addChild("dlang/toolchains/ldc", UIString("LDC"d));
    ldctoolchain.addExecutableFileNameEdit("dlang/toolchains/ldc/executable", UIString("OPTION_LDC2_EXECUTABLE"c), "ldc2");
    ldctoolchain.addStringEdit("dlang/toolchains/ldc/dub_additional_params", UIString("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage ldmdtoolchain = toolchains.addChild("dlang/toolchains/ldmd", UIString("LDMD"d));
    ldmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/ldmd/executable", UIString("OPTION_LDMD2_EXECUTABLE"c), "ldmd2");
    ldmdtoolchain.addStringEdit("dlang/toolchains/ldmd/dub_additional_params", UIString("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage gdctoolchain = toolchains.addChild("dlang/toolchains/gdc", UIString("GDC"d));
    gdctoolchain.addExecutableFileNameEdit("dlang/toolchains/gdc/executable", UIString("OPTION_GDC_EXECUTABLE"c), "gdc");
    gdctoolchain.addStringEdit("dlang/toolchains/gdc/dub_additional_params", UIString("OPTION_DUB_ADDITIONAL_PARAMS"c), "");

    return res;
}

/// create DlangIDE settings pages tree
SettingsPage createProjectSettingsPages() {
    SettingsPage res = new SettingsPage("", UIString(""d));

    SettingsPage build = res.addChild("build", UIString("Build"d));
    build.addStringComboBox("build/toolchain", UIString("Toolchain"d), [
            StringListValue("default", "Default"d), 
            StringListValue("dmd", "DMD"d), 
            StringListValue("ldc", "LDC"d), 
            StringListValue("ldmd", "LDMD"d), 
            StringListValue("gdc", "GDC"d)]);
    build.addStringComboBox("build/arch", UIString("Architecture"d), [
            StringListValue("default", "Default"d), 
            StringListValue("x86", "x86"d), 
            StringListValue("x86_64", "x86_64"d),
            StringListValue("arm", "arm"d),
            StringListValue("arm64", "arm64"d),
    ]);
    build.addCheckbox("build/verbose", UIString("Verbose"d), true);
    build.addStringEdit("build/dub_additional_params", UIString("DUB additional params"d), "");

    SettingsPage dbg = res.addChild("debug", UIString("Run and Debug"d));
    dbg.addStringEdit("debug/run_args", UIString("Command line args"d), "");
    dbg.addDirNameEdit("debug/working_dir", UIString("Working directory"d), "");
    dbg.addCheckbox("debug/external_console", UIString("Run in external console"d), true);

    return res;
}
