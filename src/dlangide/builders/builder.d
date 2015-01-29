module dlangide.builders.builder;

import dlangide.workspace.project;
import dlangide.ui.outputpanel;
import dlangide.builders.extprocess;
import dlangui.widgets.appframe;
import std.algorithm;
import std.string;
import std.conv;

class Builder : BackgroundOperationWatcher {
    protected Project _project;
    protected ExternalProcess _extprocess;
    protected OutputPanel _log;
    protected ProtectedTextStorage _box;

    @property Project project() { return _project; }
    @property void project(Project p) { _project = p; }

    this(AppFrame frame, Project project, OutputPanel log) {
        super(frame);
        _project = project;
        _log = log;
        _extprocess = new ExternalProcess();
        _box = new ProtectedTextStorage();
    }
    /// log lines
    void pollText() {
        dstring text = _box.readText();
        dstring[] lines = text.split('\n');
        _log.addLogLines(null, lines);
    }

    /// returns icon of background operation to show in status line
    override @property string icon() { return "folder"; }
    /// update background operation status
    override void update() {
        scope(exit)pollText();
        if (_extprocess.state == ExternalProcessState.None) {
            _box.writeText("Running dub\n"d);
            char[] program = "dub".dup;
            char[][] params;
            char[] dir = _project.dir.dup;
            params ~= "build".dup;
            params ~= "-v".dup;
            params ~= "--force".dup;
            _extprocess.run(program, params, dir, _box, null);
            if (_extprocess.state != ExternalProcessState.Running) {
                _box.writeText("Failed to run builder tool\n"d);
                _finished = true;
                destroy(_extprocess);
                _extprocess = null;
                return;
            }
        }
        ExternalProcessState state = _extprocess.poll();
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
