module dlangide.builders.builder;

import dlangui.core.logger;
import dlangide.workspace.project;
import dlangide.workspace.workspace;
import dlangide.ui.outputpanel;
import dlangide.builders.extprocess;
import dlangui.widgets.appframe;
import std.algorithm;
import core.thread;
import std.string;
import std.conv;

class Builder : BackgroundOperationWatcher {
    protected Project _project;
    protected ExternalProcess _extprocess;
    protected OutputPanel _log;
    protected ProtectedTextStorage _box;
    protected ProjectConfiguration _projectConfig;
    protected BuildConfiguration _buildConfig;
    protected BuildOperation _buildOp;
    protected bool _verbose;

    @property Project project() { return _project; }
    @property void project(Project p) { _project = p; }

    this(AppFrame frame, Project project, OutputPanel log, ProjectConfiguration projectConfig, BuildConfiguration buildConfig, BuildOperation buildOp, bool verbose) {
        super(frame);
        _projectConfig = projectConfig;
        _buildConfig = buildConfig;
        _buildOp = buildOp;
        _verbose = verbose;
        _project = project;
        _log = log;
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
            _log.clear();
            _box.writeText("Running dub\n"d);
            char[] program = "dub".dup;
            char[][] params;
            char[] dir = _project.dir.dup;

            if (_buildOp == BuildOperation.Build || _buildOp == BuildOperation.Rebuild) {
                params ~= "build".dup;
                if (_buildOp == BuildOperation.Rebuild) {
                    params ~= "--force".dup;
                }
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
            }

            if(_projectConfig.name != ProjectConfiguration.DEFAULT_NAME) {
                params ~= "--config=".dup ~ _projectConfig.name;
            }
            
            if (_verbose)
                params ~= "-v".dup;

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
}
