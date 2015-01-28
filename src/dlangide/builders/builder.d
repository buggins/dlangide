module dlangide.builders.builder;

import dlangui.core.logger;
import dlangide.workspace.project;
import dlangide.ui.outputpanel;
import dlangide.builders.extprocess;
import dlangui.widgets.appframe;
import std.algorithm;
import core.thread;
import std.string;
import std.conv;

class Builder : BackgroundOperationWatcher, ProcessOutputTarget {
    protected Project _project;
    protected ExternalProcess _extprocess;
    protected OutputPanel _log;

    @property Project project() { return _project; }
    @property void project(Project p) { _project = p; }

    this(AppFrame frame, Project project, OutputPanel log) {
        super(frame);
        _project = project;
        _log = log;
        _extprocess = new ExternalProcess();
		Log.d("Builder.this");
    }
    /// log lines
    override void onText(dstring text) {
        dstring[] lines = text.split('\n');
        _log.addLogLines(null, lines);
    }

    /// returns icon of background operation to show in status line
    override @property string icon() { return "folder"; }
    /// update background operation status
    override void update() {
		ExternalProcessState state = _extprocess.state;
        if (state == ExternalProcessState.None) {
			_log.clear();
            onText("Running dub\n"d);
            state = _extprocess.run(cast(char[])"dub", cast(char[][])["build"], cast(char[])_project.dir, this, null);
            if (state != ExternalProcessState.Running) {
                onText("Failed to run builder tool\n");
                _finished = true;
                destroy(_extprocess);
                _extprocess = null;
                return;
            }
        }
        state = _extprocess.poll();
        if (state == ExternalProcessState.Stopped) {
            onText("Builder finished with result "d ~ to!dstring(_extprocess.result) ~ "\n"d);
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
