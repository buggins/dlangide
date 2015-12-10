module dlangide.workspace.projectsettings;

import dlangui.core.settings;
import dlangui.core.i18n;

import dlangide.workspace.idesettings;

const AVAILABLE_TOOLCHAINS = ["default", "dmd", "ldc", "gdc"];
const AVAILABLE_ARCH = ["default", "x86", "x86_64"];

class ProjectSettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
    }

    override void updateDefaults() {
        Setting build = buildSettings();
        build.setStringDef("toolchain", "default");
        build.setStringDef("arch", "default");
        build.setBooleanDef("verbose", false);
        Setting dbg = debugSettings();
        dbg.setBooleanDef("external_console", true);
    }

    @property Setting buildSettings() {
        Setting res = _setting.objectByPath("build", true);
        return res;
    }

    @property Setting debugSettings() {
        Setting res = _setting.objectByPath("debug", true);
        return res;
    }

    @property bool buildVerbose() {
        return buildSettings.getBoolean("verbose", false);
    }

    string getToolchain(IDESettings idesettings) {
        string cfg = buildSettings.getString("toolchain");
        return idesettings.getToolchainSettings(cfg);
    }

    string getArch(IDESettings idesettings) {
        string cfg = buildSettings.getString("arch");
        if (cfg.equal("default"))
            return null;
        return cfg;
    }
}

