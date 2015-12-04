module dlangide.ui.newproject;

import dlangui.core.types;
import dlangui.core.i18n;
import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.dml.parser;

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
		Widget content = parseML(q{
				VerticalLayout {
				id: vlayout
					HorizontalLayout {
						VerticalLayout {
						layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT; layoutWidth: 1
							TextWidget {
							text: "Project type"
							}
						}
						VerticalLayout {
						layoutWidth: FILL_PARENT; layoutWeight: FILL_PARENT; layoutWidth: 1
							TextWidget {
							text: "Template"
							}
						}
						VerticalLayout {
						layoutWidth: FILL_PARENT; layoutWeight: FILL_PARENT; layoutWidth: 1
							TextWidget {
							text: "Description"
							}
						}
					}
				margins: Rect { left: 5; right: 3; top: 2; bottom: 4 }
				padding: Rect { 5, 4, 3, 2 } // same as Rect { left: 5; top: 4; right: 3; bottom: 2 }
					TextWidget {
						/* this widget can be accessed via id myLabel1 
            e.g. w.childById!TextWidget("myLabel1") 
        */
					id: myLabel1
							text: "Some text"; padding: 5
							enabled: false
					}
					TextWidget {
					id: myLabel2
							text: "More text"; margins: 5
							enabled: true
					}
					CheckBox{ id: cb1; text: "Some checkbox" }
					HorizontalLayout {
						RadioButton { id: rb1; text: "Radio Button 1" }
						RadioButton { id: rb1; text: "Radio Button 2" }
					}
				}
			});
		// you can access loaded items by id - e.g. to assign signal listeners
		auto edit1 = window.mainWidget.childById!EditLine("edit1");

	}

}
