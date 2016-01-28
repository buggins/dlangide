module dlangide.workspace.projectsettings;

import dlangui.core.settings;
import dlangui.core.i18n;

import dlangide.workspace.idesettings;

import std.string;
import std.array;

const AVAILABLE_TOOLCHAINS = ["default", "dmd", "ldc", "gdc"];
const AVAILABLE_ARCH = ["default", "x86", "x86_64", "arm", "arm64"];

/// local settings for project (not supposed to put under source control)
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
        build.setStringDef("dub_additional_params", "");
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
        return idesettings.getToolchainCompilerExecutable(cfg);
    }

    string getDubAdditionalParams(IDESettings idesettings) {
        string cfg = buildSettings.getString("toolchain");
        string globalparams = idesettings.dubAdditionalParams;
        string globaltoolchainparams = idesettings.getToolchainAdditionalDubParams(cfg);
        string projectparams = buildSettings.getString("dub_additional_params", "");
        string verbosity = buildVerbose ? "-v" : null;
        return joinParams(globalparams, globaltoolchainparams, projectparams, verbosity);
    }

    string getArch(IDESettings idesettings) {
        string cfg = buildSettings.getString("arch");
        if (cfg.equal("default"))
            return null;
        return cfg;
    }
}

/// join parameter lists separating with space
string joinParams(string[] params...) pure {
    char[] res;
    foreach(param; params) {
        string s = param.strip;
        if (!s.empty) {
            if (!res.empty)
                res ~= " ";
            res ~= s;
        }
    }
    if (res.empty)
        return null;
    return res.dup;
}
