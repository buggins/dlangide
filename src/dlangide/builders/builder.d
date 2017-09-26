module dlangide.builders.builder;

import dlangui.core.logger;
import dlangide.workspace.project;
import dlangide.workspace.workspace;
import dlangide.ui.outputpanel;
import dlangide.builders.extprocess;
import dlangui.widgets.appframe;
import std.algorithm;
import std.array;
import core.thread;
import std.string;
import std.conv;

alias BuildResultListener = void delegate(int);

class Builder : BackgroundOperationWatcher {
    protected Project _project;
    protected ExternalProcess _extprocess;
    protected OutputPanel _log;
    protected ProtectedTextStorage _box;
    protected ProjectConfiguration _projectConfig;
    protected BuildConfiguration _buildConfig;
    protected BuildOperation _buildOp;
    protected string _executable;
    protected string _additionalParams;
    protected BuildResultListener _listener;
    protected int _exitCode = int.min;
    protected string _toolchain;
    protected string _arch;

    @property Project project() { return _project; }
    @property void project(Project p) { _project = p; }

    this(AppFrame frame, Project project, OutputPanel log, ProjectConfiguration projectConfig, BuildConfiguration buildConfig, 
             BuildOperation buildOp, 
             string dubExecutable,
             string dubAdditionalParams,
             string toolchain = null,
             string arch = null,
             BuildResultListener listener = null) {
        super(frame);
        _listener = listener;
        _projectConfig = projectConfig;
        _buildConfig = buildConfig;
        _buildOp = buildOp;
        _executable = dubExecutable.empty ? "dub" : dubExecutable;
        _additionalParams = dubAdditionalParams;
        _project = project;
        _log = log;
        _toolchain = toolchain;
        _arch = arch;
        _extprocess = new ExternalProcess();
        _box = new ProtectedTextStorage();
    }

    /// log lines
    void pollText() {
        dstring text = _box.readText();
        if (text.length) {
            _log.appendText(null, text);
        }
    }

    /// returns icon of background operation to show in status line
    override @property string icon() { return "folder"; }
    /// update background operation status
    override void update() {
        scope(exit)pollText();
        ExternalProcessState state = _extprocess.state;
        if (state == ExternalProcessState.None) {
            import dlangui.core.files;
            string exepath = findExecutablePath(_executable);
            if (!exepath) {
                _finished = true;
                destroy(_extprocess);
                _extprocess = null;
                return;
            }

            _log.clear();
            char[] program = exepath.dup;
            char[][] params;
            char[] dir = _project.dir.dup;

            {
                // dub
                if (_buildOp == BuildOperation.Build || _buildOp == BuildOperation.Rebuild) {
                    params ~= "build".dup;
                    if (_buildOp == BuildOperation.Rebuild) {
                        params ~= "--force".dup;
                    }
                    if (!_arch.empty)
                        params ~= ("--arch=" ~ _arch).dup;
                    if (!_toolchain.empty)
                        params ~= ("--compiler=" ~ _toolchain).dup;
                    params ~= "--build-mode=allAtOnce".dup;
                } else if (_buildOp == BuildOperation.Clean) {
                    params ~= "clean".dup;
                } else if (_buildOp == BuildOperation.Run) {
                    if (_projectConfig.type == ProjectConfiguration.Type.Library) {
                        params ~= "test".dup;
                    } else {
                        params ~= "run".dup;
                    }
                } else if (_buildOp == BuildOperation.Upgrade) {
                    params ~= "upgrade".dup;
                    params ~= "--force-remove".dup;
                    import std.path;
                    import std.file;
                    string projectFile = project.filename;
                    string selectionsFile = projectFile.stripExtension ~ ".selections.json";
                    if (selectionsFile.exists && selectionsFile.isFile) {
                        Log.i("Removing file ", selectionsFile);
                        remove(selectionsFile);
                    }
                }

                if (_buildOp != BuildOperation.Clean && _buildOp != BuildOperation.Upgrade) {
                    switch (_buildConfig) {
                        default:
                        case BuildConfiguration.Debug:
                            params ~= "--build=debug".dup;
                            break;
                        case BuildConfiguration.Release:
                            params ~= "--build=release".dup;
                            break;
                        case BuildConfiguration.Unittest:
                            params ~= "--build=unittest".dup;
                            break;
                    }
                    if (!_additionalParams.empty)
                        params ~= _additionalParams.dup;
                }

                if(_projectConfig.name != ProjectConfiguration.DEFAULT_NAME) {
                    params ~= "--config=".dup ~ _projectConfig.name;
                }
            }
            
            auto text = "Running (in " ~ dir ~ "): " ~ program ~ " " ~ params.join(' ') ~ "\n";
            _box.writeText(to!dstring(text));
            state = _extprocess.run(program, params, dir, _box, null);
            if (state != ExternalProcessState.Running) {
                _box.writeText("Failed to run builder tool\n"d);
                _finished = true;
                destroy(_extprocess);
                _extprocess = null;
                return;
            }
        }
        state = _extprocess.poll();
        if (state == ExternalProcessState.Stopped) {
            _exitCode = _extprocess.result;
            _box.writeText("Builder finished with result "d ~ to!dstring(_extprocess.result) ~ "\n"d);
            _finished = true;
            return;
        }
        if (_cancelRequested) {
            _extprocess.kill();
            _extprocess.wait();
            _finished = true;
            return;
        }
        super.update();
    }
    override void removing() {
        super.removing();
        if (_exitCode != int.min && _listener)
            _listener(_exitCode);
    }
}

string[] splitByLines(string s) {
    string[] res;
    int start = 0;
    for(int i = 0; i <= s.length; i++) {
        if (i == s.length) {
            if (start < i)
                res ~= s[start .. i];
            break;
        }
        if (s[i] == '\r' || s[i] == '\n') {
            if (start < i)
                res ~= s[start .. i];
            start = i + 1;
        }
    }
    return res;
}

string[] detectImportPathsForCompiler(string compiler) {
    string[] res;
    import std.process : executeShell;
    import std.string : startsWith, indexOf;
    import std.path : buildNormalizedPath;
    import std.file : write, remove;
    import dlangui.core.files;
    try {
        string sourcefilename = appDataPath(".dlangide") ~ PATH_DELIMITER ~ "tmp_dummy_file_to_get_import_paths.d";
        write(sourcefilename, "import module_that_does_not_exist;\n");
        auto ls = executeShell("\"" ~ compiler ~ "\" \"" ~ sourcefilename ~ "\"");
        remove(sourcefilename);
        string s = ls.output;
        string[] lines = splitByLines(s);
        debug Log.d("compiler output:\n", s);
        foreach(line; lines) {
            if (line.startsWith("import path[")) {
                auto p = line.indexOf("] = ");
                if (p > 0) {
                    line = line[p + 4 .. $];
                    string path = line.buildNormalizedPath;
                    debug Log.d("import path found: `", line, "`");
                    res ~= line;
                }
            }
        }
        return res;
    } catch (Exception e) {
        return null;
    }
}
