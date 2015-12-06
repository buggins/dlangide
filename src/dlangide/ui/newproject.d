module dlangide.ui.newproject;

import dlangui.core.types;
import dlangui.core.i18n;
import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.lists;
import dlangui.dml.parser;
import dlangui.core.stdaction;

class NewProjectDlg : Dialog {

	bool _newWorkspace;

    StringListWidget _projectTypeList;
    StringListWidget _projectTemplateList;
    EditBox _templateDescription;

    this(Window parent, bool newWorkspace) {
		super(newWorkspace ? UIString("New Workspace"d) : UIString("New Project"d), parent, DialogFlag.Modal);
        _icon = "dlangui-logo1";
    }

	/// override to implement creation of dialog controls
	override void init() {
        super.init();
		Widget content = parseML(q{
                VerticalLayout {
                id: vlayout
                    margins: Rect { left: 5; right: 3; top: 2; bottom: 4 }
                padding: Rect { 5, 4, 3, 2 } // same as Rect { left: 5; top: 4; right: 3; bottom: 2 }
                layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                    HorizontalLayout {
                    layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                        VerticalLayout {
                        layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            TextWidget {
                            text: "Project type"
                            }
                            StringListWidget { id: projectTypeList }
                        }
                        VerticalLayout {
                        layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            TextWidget {
                            text: "Template"
                            }
                            StringListWidget { id: projectTemplateList }
                        }
                        VerticalLayout {
                        layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            TextWidget {
                            text: "Description"
                            }
                            EditBox { id: templateDescription }
                        }
                    }
                    TableLayout {
                    colCount: 2
                            layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                        TextWidget { text: "Project name" }
                        EditLine {
                        id: edProjectName
                        }
                        TextWidget { text: "Solution name" }
                        EditLine {
                        id: edSolutionName
                        }
                        TextWidget { text: "Location" }
                        EditLine {
                        id: edLocation
                        }
                        TextWidget { text: "" }
                        CheckBox { id: cbCreateSubdir; text: "Create subdirectory for project" }
                    }
                }
            });

        _projectTypeList = content.childById!StringListWidget("projectTypeList");
        _projectTemplateList = content.childById!StringListWidget("projectTemplateList");
        _templateDescription = content.childById!EditBox("templateDescription");
        _projectTypeList.items = [
            "Empty Project"d,
            "Library"d,
            "Console Application"d,
            "DlangUI Library"d,
            "DlangUI Application"d,
        ];
        _projectTemplateList.items = [
            "Hello World"d,
            "DlangUI Form based app"d,
            "DlangUI Frame based app"d,
        ];

        addChild(content);
        addChild(createButtonsPanel([ACTION_OK, ACTION_CANCEL], 0, 0));
	}

}
