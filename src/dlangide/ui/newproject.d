module dlangide.ui.newproject;

import dlangui.core.types;
import dlangui.core.i18n;
import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;

class NewProjectDlg : Dialog {

    this(UIString caption, Window parentWindow = null, uint flags = DialogFlag.Modal) {
        super(caption, parentWindow, flags);
        _caption = caption;
        _parentWindow = parentWindow;
        _flags = flags;
        _icon = "dlangui-logo1";
    }

	/// override to implement creation of dialog controls
	override void init() {
        super.init();
	}

}
