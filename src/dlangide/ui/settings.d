module dlangide.ui.settings;

import dlangui.core.settings;
import dlangui.core.i18n;
import dlangui.graphics.fonts;
import dlangui.widgets.lists;
import dlangui.dialogs.settingsdialog;

public import dlangide.workspace.projectsettings;
public import dlangide.workspace.idesettings;
public import dlangide.workspace.workspacesettings;

StringListValue[] createFaceList(bool monospaceFirst) {
    StringListValue[] faces;
    faces.assumeSafeAppend();
    faces ~= StringListValue("Default", UIString.fromId("OPTION_DEFAULT"c));
    import dlangui.graphics.fonts;
    import std.utf : toUTF32;
    FontFaceProps[] allFaces = FontManager.instance.getFaces();
    import std.algorithm.sorting : sort;
    auto fontCompMonospaceFirst = function(ref FontFaceProps a, ref FontFaceProps b) {
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
    auto fontComp = function(ref FontFaceProps a, ref FontFaceProps b) {
        if (a.face < b.face)
            return -1;
        if (a.face > b.face)
            return 1;
        return 0;
    };
    //auto sorted = allFaces.sort!((a, b) => (a.family == FontFamily.MonoSpace && b.family != FontFamily.MonoSpace) || (a.face < b.face));
    auto sorted = sort!((a, b) => (monospaceFirst ? fontCompMonospaceFirst(a, b) : fontComp(a, b)) < 0)(allFaces);

    //allFaces = allFaces.sort!((a, b) => a.family == FontFamily.MonoSpace && b.family == FontFamily.MonoSpace || a.face < b.face);
    //for (int i = 0; i < allFaces.length; i++) {
    foreach (face; sorted) {
        if (face.family == FontFamily.MonoSpace)
            faces ~= StringListValue(face.face, "*"d ~ toUTF32(face.face));
        else
            faces ~= StringListValue(face.face, toUTF32(face.face));
    }
    return faces;
}

StringListValue[] createIntValueList(int[] values, dstring suffix = ""d) {
    import std.conv : to;
    StringListValue[] res;
    res.assumeSafeAppend();
    foreach(n; values) {
        res ~= StringListValue(n, to!dstring(n) ~ suffix);
    }
    return res;
}

/// create DlangIDE settings pages tree
SettingsPage createSettingsPages() {
    import std.conv : to;
    // Root page
    SettingsPage res = new SettingsPage("", UIString.fromRaw(""d));

    // UI settings page
    SettingsPage ui = res.addChild("interface", UIString.fromId("OPTION_INTERFACE"c));
    ui.addStringComboBox("interface/theme", UIString.fromId("OPTION_THEME"c), [
            StringListValue("ide_theme_default", "OPTION_DEFAULT"c),
            StringListValue("ide_theme_dark", "OPTION_DARK"c)]);
    ui.addStringComboBox("interface/language", UIString.fromId("OPTION_LANGUAGE"c), [
            StringListValue("en", "MENU_VIEW_LANGUAGE_EN"c),
            StringListValue("ru", "MENU_VIEW_LANGUAGE_RU"c),
            StringListValue("es", "MENU_VIEW_LANGUAGE_ES"c),
            StringListValue("de", "MENU_VIEW_LANGUAGE_DE"c),
        StringListValue("cs", "MENU_VIEW_LANGUAGE_CS"c)]);

    // UI font faces
    ui.addStringComboBox("interface/uiFontFace", UIString.fromId("OPTION_FONT_FACE"c),
                      createFaceList(false));
    ui.addIntComboBox("interface/uiFontSize", UIString.fromId("OPTION_FONT_SIZE"c),
                      createIntValueList([6,7,8,9,10,11,12,14,16,18,20,22,24,26,28,30,32]));


    ui.addIntComboBox("interface/hintingMode", UIString.fromId("OPTION_FONT_HINTING"c), [StringListValue(0, "OPTION_FONT_HINTING_NORMAL"c),
                StringListValue(1, "OPTION_FONT_HINTING_FORCE"c),
                StringListValue(2, "OPTION_FONT_HINTING_DISABLED"c), StringListValue(3, "OPTION_FONT_HINTING_LIGHT"c)]);
    ui.addIntComboBox("interface/minAntialiasedFontSize", UIString.fromId("OPTION_FONT_ANTIALIASING"c),
                      [StringListValue(0, "OPTION_FONT_ANTIALIASING_ALWAYS_ON"c),
                      StringListValue(12, "12"d),
                      StringListValue(14, "14"d),
                      StringListValue(16, "16"d),
                      StringListValue(20, "20"d),
                      StringListValue(24, "24"d),
                      StringListValue(32, "32"d),
                      StringListValue(48, "48"d),
                      StringListValue(255, "OPTION_FONT_ANTIALIASING_ALWAYS_OFF"c)]);
    ui.addFloatComboBox("interface/fontGamma", UIString.fromId("OPTION_FONT_GAMMA"c),
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

    ui.addIntComboBox("interface/screenDpiOverride", UIString.fromId("OPTION_SCREEN_DPI_OVERRIDE"c),
                      [StringListValue(0, UIString.fromId("OPTION_SCREEN_DPI_OVERRIDE_NONE"c).value ~ " ("d ~ to!dstring(systemScreenDPI) ~ ")"d),
                      StringListValue(72, "72"d),
                      StringListValue(96, "96"d),
                      StringListValue(120, "120"d),
                      StringListValue(140, "140"d),
                      StringListValue(150, "150"d),
                      StringListValue(300, "300"d),
                      StringListValue(400, "400"d),
                      StringListValue(600, "600"d)]);

    SettingsPage ed = res.addChild("editors", UIString.fromId("OPTION_EDITORS"c));
    SettingsPage texted = ed.addChild("editors/textEditor", UIString.fromId("OPTION_TEXT_EDITORS"c));

    // editor font faces
    texted.addStringComboBox("editors/textEditor/fontFace", UIString.fromId("OPTION_FONT_FACE"c), createFaceList(true));
    texted.addIntComboBox("editors/textEditor/fontSize", UIString.fromId("OPTION_FONT_SIZE"c),
                      createIntValueList([6,7,8,9,10,11,12,14,16,18,20,22,24,26,28,30,32]));

    texted.addNumberEdit("editors/textEditor/tabSize", UIString.fromId("OPTION_TAB"c), 1, 16, 4);
    texted.addCheckbox("editors/textEditor/useSpacesForTabs", UIString.fromId("OPTION_USE_SPACES"c));
    texted.addCheckbox("editors/textEditor/smartIndents", UIString.fromId("OPTION_SMART_INDENTS"c));
    texted.addCheckbox("editors/textEditor/smartIndentsAfterPaste", UIString.fromId("OPTION_SMART_INDENTS_PASTE"c));
    texted.addCheckbox("editors/textEditor/showWhiteSpaceMarks", UIString.fromId("OPTION_SHOW_SPACES"c));
    texted.addCheckbox("editors/textEditor/showTabPositionMarks", UIString.fromId("OPTION_SHOW_TABS"c));
    texted.addCheckbox("editors/textEditor/autoAutoComplete", UIString.fromId("OPTION_AUTO_AUTOCOMPLETE"c));

    // Common page
    SettingsPage common = res.addChild("common", UIString.fromId("OPTION_COMMON"c));
    common.addCheckbox("common/autoOpenLastProject", UIString.fromId("OPTION_AUTO_OPEN_LAST_PROJECT"c));


    SettingsPage dlang = res.addChild("dlang", UIString.fromRaw("D"d));
    SettingsPage dub = dlang.addChild("dlang/dub", UIString.fromRaw("DUB"d));
    dub.addExecutableFileNameEdit("dlang/dub/executable", UIString.fromId("OPTION_DUB_EXECUTABLE"c), "dub");
    dub.addStringEdit("dlang/dub/additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage rdmd = dlang.addChild("dlang/rdmd", UIString.fromRaw("rdmd"d));
    rdmd.addExecutableFileNameEdit("dlang/rdmd/executable", UIString.fromId("OPTION_RDMD_EXECUTABLE"c), "rdmd");
    rdmd.addStringEdit("dlang/rdmd/additional_params", UIString.fromId("OPTION_RDMD_ADDITIONAL_PARAMS"c), "");
    SettingsPage ddebug = dlang.addChild("dlang/debugger", UIString.fromId("OPTION_DEBUGGER"c));
    version (Windows) {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString.fromId("OPTION_DEBUGGER_EXECUTABLE"c), "gdb");
    } else {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString.fromId("OPTION_DEBUGGER_EXECUTABLE"c), "mago-mi");
    }
    SettingsPage terminal = dlang.addChild("dlang/terminal", UIString.fromId("OPTION_TERMINAL"c));
    terminal.addExecutableFileNameEdit("dlang/terminal/executable", UIString.fromId("OPTION_TERMINAL_EXECUTABLE"c), "xterm");

    SettingsPage toolchains = dlang.addChild("dlang/toolchains", UIString.fromId("OPTION_TOOLCHAINS"c));
    SettingsPage dmdtoolchain = toolchains.addChild("dlang/toolchains/dmd", UIString.fromRaw("DMD"d));
    dmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/dmd/executable", UIString.fromId("OPTION_DMD_EXECUTABLE"c), "dmd");
    dmdtoolchain.addStringEdit("dlang/toolchains/dmd/dub_additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage ldctoolchain = toolchains.addChild("dlang/toolchains/ldc", UIString.fromRaw("LDC"d));
    ldctoolchain.addExecutableFileNameEdit("dlang/toolchains/ldc/executable", UIString.fromId("OPTION_LDC2_EXECUTABLE"c), "ldc2");
    ldctoolchain.addStringEdit("dlang/toolchains/ldc/dub_additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage ldmdtoolchain = toolchains.addChild("dlang/toolchains/ldmd", UIString.fromRaw("LDMD"d));
    ldmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/ldmd/executable", UIString.fromId("OPTION_LDMD2_EXECUTABLE"c), "ldmd2");
    ldmdtoolchain.addStringEdit("dlang/toolchains/ldmd/dub_additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");
    SettingsPage gdctoolchain = toolchains.addChild("dlang/toolchains/gdc", UIString.fromRaw("GDC"d));
    gdctoolchain.addExecutableFileNameEdit("dlang/toolchains/gdc/executable", UIString.fromId("OPTION_GDC_EXECUTABLE"c), "gdc");
    gdctoolchain.addStringEdit("dlang/toolchains/gdc/dub_additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");

    return res;
}

/// create DlangIDE settings pages tree
SettingsPage createProjectSettingsPages() {
    SettingsPage res = new SettingsPage("", UIString.fromRaw(""d));

    SettingsPage build = res.addChild("build", UIString.fromId("OPTION_BUILD"c));
    build.addStringComboBox("build/toolchain", UIString.fromId("OPTION_TOOLCHAIN"c), [
            StringListValue("default", UIString.fromId("OPTION_DEFAULT"c)),
            StringListValue("dmd", "DMD"d),
            StringListValue("ldc", "LDC"d),
            StringListValue("ldmd", "LDMD"d),
            StringListValue("gdc", "GDC"d)]);
    build.addStringComboBox("build/arch", UIString.fromId("OPTION_ARCHITECTURE"c), [
            StringListValue("default", UIString.fromId("OPTION_DEFAULT"c)),
            StringListValue("x86", "x86"d),
            StringListValue("x86_64", "x86_64"d),
            StringListValue("arm", "arm"d),
            StringListValue("arm64", "arm64"d),
    ]);
    build.addCheckbox("build/verbose", UIString.fromId("OPTION_VERBOSE"c), true);
    build.addStringEdit("build/dub_additional_params", UIString.fromId("OPTION_DUB_ADDITIONAL_PARAMS"c), "");

    SettingsPage dbg = res.addChild("debug", UIString.fromId("OPTION_RUN_DEBUG"c));
    dbg.addStringEdit("debug/run_args", UIString.fromId("OPTION_COMMAND_LINE"c), "");
    dbg.addDirNameEdit("debug/working_dir", UIString.fromId("OPTION_WORKING_DIR"c), "");
    dbg.addCheckbox("debug/external_console", UIString.fromId("OPTION_RUN_IN_EXTERNAL_CONSOLE"c), false);

    return res;
}
