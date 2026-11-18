module dlangide.workspace.projectsettings;

import dlangui.core.settings;
import dlangui.core.i18n;

import dlangide.workspace.idesettings;

import std.string;
import std.array;
import std.algorithm : equal;

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
        dbg.setBooleanDef("external_console", false); // the Output panel terminal
    }

    @property Setting buildSettings() {
        Setting res = _setting.objectByPath("build", true);
        return res;
    }

    @property Setting debugSettings() {
        Setting res = _setting.objectByPath("debug", true);
        return res;
    }

    @property string projectConfiguration() {
        return buildSettings.getString("configuration", "default");
    }

    @property void projectConfiguration(string newConfiguration) {
        buildSettings.setString("configuration", newConfiguration);
    }

    @property bool buildVerbose() {
        return buildSettings.getBoolean("verbose", false);
    }

    /// compiler executable for the project's toolchain, or null to let DUB choose
    string getToolchain(IDESettings idesettings) {
        string cfg = buildSettings.getString("toolchain");
        if (cfg.empty || cfg.equal("default")) {
            // DUB tries dmd first: use the DMD executable from Preferences if it was set (#364),
            // otherwise DUB finds a compiler in PATH
            string dmd = idesettings.getToolchainCompilerExecutable("dmd");
            return dmd.empty || dmd.equal("dmd") ? null : dmd;
        }
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

    @property bool runInExternalConsole() {
        return debugSettings.getBoolean("external_console", false);
    }

    /// command line arguments for running and debugging (Project Settings -> Run/Debug -> Command line)
    @property string runArgs() {
        return debugSettings.getString("run_args", "");
    }

    /// working directory for running and debugging (Project Settings -> Run/Debug -> Working directory);
    /// empty if not set
    @property string workingDir() {
        return debugSettings.getString("working_dir", "");
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

/// the Default toolchain uses the DMD executable from Preferences when it was set (#364)
unittest {
    auto ide = new IDESettings(null);
    ide.updateDefaults();
    auto project = new ProjectSettings(null);
    project.updateDefaults();
    assert(project.getToolchain(ide) is null); // DMD executable "dmd": DUB chooses the compiler
    ide.dmdToolchainSettings.setString("executable", "/opt/dmd/bin/dmd");
    assert(project.getToolchain(ide) == "/opt/dmd/bin/dmd");
    project.buildSettings.setString("toolchain", "ldc");
    assert(project.getToolchain(ide) == "ldc2");
    project.buildSettings.setString("toolchain", "dmd");
    assert(project.getToolchain(ide) == "/opt/dmd/bin/dmd");
}
