module dlangide.workspace.workspacesettings;

import dlangui.core.settings;
import dlangui.core.i18n;

class WorkspaceSettings : SettingsFile {

    this(string filename) {
        super(filename);
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
    }

    override void updateDefaults() {
    }

}

