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

dstring replaceVars(dstring source, dstring[dstring] valueMap) {
    if (!valueMap.length)
        return source; // no var values
    if (source.indexOf("{") < 0)
        return source; // no vars
    dchar[] res;
    res.assumeSafeAppend;
    res.reserve(source.length + 10);
    int varNameStart = -1;
    for(int i = 0; i < source.length; i++) {
        dchar ch = source[i];
        if (ch == '{') {
            varNameStart = i + 1;
        } else if (ch == '}') {
            if (varNameStart >= 0) {
                dstring varName = source[varNameStart .. i];
                if (varName.length) {
                    if (auto value = varName in valueMap) {
                        res ~= *value;
                    }
                }
            } else {
                res ~= ch;
            }
            varNameStart = -1;
        } else if (varNameStart < 0) {
            res ~= ch;
        } // else it's inside variable name
    }
    return cast(dstring)res;
}

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
    protected dstring _description;

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
        string opDescriptionId;
        switch(buildOp) with(BuildOperation) {
            case Build:
                opDescriptionId = "BUILD_OP_DESCRIPTION_BUILD";
                break;
            case Clean:
                opDescriptionId = "BUILD_OP_DESCRIPTION_CLEAN";
                break;
            case Rebuild:
                opDescriptionId = "BUILD_OP_DESCRIPTION_REBUILD";
                break;
            case Run:
                opDescriptionId = "BUILD_OP_DESCRIPTION_RUN";
                break;
            case Upgrade:
                opDescriptionId = "BUILD_OP_DESCRIPTION_UPGRADE";
                break;
            default:
                break;
        }
        if (opDescriptionId) {
            import dlangui.core.i18n;
            _description = UIString.fromId(opDescriptionId).value;
            dstring[dstring] values;
            values["projectName"d] = project.name;
            _description = replaceVars(_description, values);
        }
    }

    /// log lines
    void pollText() {
        dstring text = _box.readText();
        if (text.length) {
            _log.appendText(null, text);
        }
    }

    /// returns description of background operation to show in status line
    override @property dstring description() { return _description; }
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

