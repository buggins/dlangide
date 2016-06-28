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

    SettingsPage ui = res.addChild("interface", UIString("Interface"d));
    ui.addStringComboBox("interface/theme", UIString("Theme"d), [
            StringListValue("ide_theme_default", "Default"d), 
            StringListValue("ide_theme_dark", "Dark"d)]);
    ui.addStringComboBox("interface/language", UIString("Language"d), [
            StringListValue("en", "English"d), 
            StringListValue("ru", "Russian"d), 
            StringListValue("es", "Spanish"d),
	    StringListValue("cs", "Čeština"d)]);
    ui.addIntComboBox("interface/hintingMode", UIString("Font hinting mode"d), [StringListValue(0, "Normal"d), StringListValue(1, "Force Auto Hint"d), 
                StringListValue(2, "Disabled"d), StringListValue(3, "Light"d)]);
    ui.addIntComboBox("interface/minAntialiasedFontSize", UIString("Minimum font size for antialiasing"d), 
                      [StringListValue(0, "Always ON"d), 
                      StringListValue(12, "12"d), 
                      StringListValue(14, "14"d), 
                      StringListValue(16, "16"d), 
                      StringListValue(20, "20"d), 
                      StringListValue(24, "24"d), 
                      StringListValue(32, "32"d), 
                      StringListValue(48, "48"d), 
                      StringListValue(255, "Always OFF"d)]);
    ui.addFloatComboBox("interface/fontGamma", UIString("Font gamma"d), 
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

    SettingsPage ed = res.addChild("editors", UIString("Editors"d));
    SettingsPage texted = ed.addChild("editors/textEditor", UIString("Text Editors"d));
    texted.addNumberEdit("editors/textEditor/tabSize", UIString("Tab size"d), 1, 16, 4);
    texted.addCheckbox("editors/textEditor/useSpacesForTabs", UIString("Use spaces for tabs"d));
    texted.addCheckbox("editors/textEditor/smartIndents", UIString("Smart indents"d));
    texted.addCheckbox("editors/textEditor/smartIndentsAfterPaste", UIString("Smart indent after paste"d));
    texted.addCheckbox("editors/textEditor/showWhiteSpaceMarks", UIString("Show white space marks"d));
    texted.addCheckbox("editors/textEditor/showTabPositionMarks", UIString("Show tab position marks"d));

    SettingsPage dlang = res.addChild("dlang", UIString("D"d));
    SettingsPage dub = dlang.addChild("dlang/dub", UIString("DUB"d));
    dub.addExecutableFileNameEdit("dlang/dub/executable", UIString("DUB executable"d), "dub");
    dub.addStringEdit("dlang/dub/additional_params", UIString("DUB additional params"d), "");
    SettingsPage rdmd = dlang.addChild("dlang/rdmd", UIString("rdmd"d));
    rdmd.addExecutableFileNameEdit("dlang/rdmd/executable", UIString("rdmd executable"d), "rdmd");
    rdmd.addStringEdit("dlang/rdmd/additional_params", UIString("rdmd additional params"d), "");
    SettingsPage ddebug = dlang.addChild("dlang/debugger", UIString("Debugger"d));
    version (Windows) {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString("Debugger executable"d), "gdb");
    } else {
        ddebug.addExecutableFileNameEdit("dlang/debugger/executable", UIString("Debugger executable"d), "mago-mi");
    }
    SettingsPage terminal = dlang.addChild("dlang/terminal", UIString("Terminal"d));
    terminal.addExecutableFileNameEdit("dlang/terminal/executable", UIString("Terminal executable"d), "xterm");

    SettingsPage toolchains = dlang.addChild("dlang/toolchains", UIString("Toolchains"d));
    SettingsPage dmdtoolchain = toolchains.addChild("dlang/toolchains/dmd", UIString("DMD"d));
    dmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/dmd/executable", UIString("DMD executable"d), "dmd");
    dmdtoolchain.addStringEdit("dlang/toolchains/dmd/dub_additional_params", UIString("DUB additional params"d), "");
    SettingsPage ldctoolchain = toolchains.addChild("dlang/toolchains/ldc", UIString("LDC"d));
    ldctoolchain.addExecutableFileNameEdit("dlang/toolchains/ldc/executable", UIString("LDC2 executable"d), "ldc2");
    ldctoolchain.addStringEdit("dlang/toolchains/ldc/dub_additional_params", UIString("DUB additional params"d), "");
    SettingsPage ldmdtoolchain = toolchains.addChild("dlang/toolchains/ldmd", UIString("LDMD"d));
    ldmdtoolchain.addExecutableFileNameEdit("dlang/toolchains/ldmd/executable", UIString("LDMD2 executable"d), "ldmd2");
    ldmdtoolchain.addStringEdit("dlang/toolchains/ldmd/dub_additional_params", UIString("DUB additional params"d), "");
    SettingsPage gdctoolchain = toolchains.addChild("dlang/toolchains/gdc", UIString("GDC"d));
    gdctoolchain.addExecutableFileNameEdit("dlang/toolchains/gdc/executable", UIString("GDC executable"d), "gdc");
    gdctoolchain.addStringEdit("dlang/toolchains/gdc/dub_additional_params", UIString("DUB additional params"d), "");

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
