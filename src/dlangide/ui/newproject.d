module dlangide.ui.newproject;

import dlangui.core.types;
import dlangui.core.i18n;
import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.controls;
import dlangui.widgets.lists;
import dlangui.dml.parser;
import dlangui.core.stdaction;
import dlangide.workspace.project;
import dlangide.workspace.workspace;

class NewProjectDlg : Dialog {

    Workspace currentWorkspace;
    this(Window parent, bool newWorkspace, Workspace currentWorkspace) {
		super(newWorkspace ? UIString("New Workspace"d) : UIString("New Project"d), parent, DialogFlag.Modal | DialogFlag.Resizable, 500, 400);
        _icon = "dlangui-logo1";
        this.currentWorkspace = currentWorkspace;
    }

	/// override to implement creation of dialog controls
	override void init() {
        super.init();
        initTemplates();
		Widget content = parseML(q{
                VerticalLayout {
                    id: vlayout
                    padding: Rect { 5, 5, 5, 5 }
                    layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                    HorizontalLayout {
                        layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                        VerticalLayout {
                            margins: 5
                            layoutWidth: WRAP_CONTENT; layoutHeight: FILL_PARENT
                            TextWidget { text: "Project template" }
                            StringListWidget { 
                                id: projectTemplateList 
                                layoutWidth: WRAP_CONTENT; layoutHeight: FILL_PARENT
                            }
                        }
                        VerticalLayout {
                            margins: 5
                            layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            TextWidget { text: "Template description" }
                            EditBox { 
                                id: templateDescription; readOnly: true 
                                layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            }
                        }
                    }
                    HorizontalLayout {
                        layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                        TableLayout {
                            margins: 5
                            colCount: 2
                            layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            TextWidget { text: "" }
                            CheckBox { id: cbCreateWorkspace; text: "Create new solution" }
                            TextWidget { text: "Workspace name" }
                            EditLine {
                                id: edWorkspaceName; text: "newworkspace"
                            }
                            TextWidget { text: "Project name" }
                            EditLine {
                                id: edProjectName; text: "newproject"
                            }
                            TextWidget { text: "" }
                            CheckBox { id: cbCreateSubdir; text: "Create subdirectory for project" }
                            TextWidget { text: "Location" }
                            EditLine {
                                id: edLocation
                            }
                        }
                        VerticalLayout {
                            layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            margins: 5
                            TextWidget { text: "Directory layout" }
                            EditBox { 
                                id: directoryLayout; readOnly: true
                                layoutWidth: FILL_PARENT; layoutHeight: FILL_PARENT
                            }
                        }
                    }
                }
            });

        _projectTemplateList = content.childById!StringListWidget("projectTemplateList");
        _templateDescription = content.childById!EditBox("templateDescription");
        _directoryLayout = content.childById!EditBox("directoryLayout");
        _edProjectName = content.childById!EditLine("edProjectName");
        _edWorkspaceName = content.childById!EditLine("edWorkspaceName");
        _cbCreateSubdir = content.childById!CheckBox("cbCreateSubdir");
        _cbCreateWorkspace = content.childById!CheckBox("cbCreateWorkspace");

        _edProjectName.contentChange = delegate (EditableContent source) {
            _projectName = source.text;
            updateDirLayout();
        };
        _edWorkspaceName.contentChange = delegate (EditableContent source) {
            _workspaceName = source.text;
            updateDirLayout();
        };

        // fill templates
        dstring[] names;
        foreach(t; _templates)
            names ~= t.name;
        _projectTemplateList.items = names;
        _projectTemplateList.selectedItemIndex = 0;
        _projectTemplateList.itemSelected = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };
        _projectTemplateList.itemClick = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };
        templateSelected(0);
        updateDirLayout();

        addChild(content);
        addChild(createButtonsPanel([ACTION_OK, ACTION_CANCEL], 0, 0));

	}

	bool _newWorkspace;
	bool _;
    StringListWidget _projectTypeList;
    StringListWidget _projectTemplateList;
    EditBox _templateDescription;
    EditBox _directoryLayout;
    EditLine _edWorkspaceName;
    EditLine _edProjectName;
    CheckBox _cbCreateSubdir;
    CheckBox _cbCreateWorkspace;
    dstring _projectName = "newproject";
    dstring _workspaceName = "newworkspace";

    void initTemplates() {
        _templates ~= new ProjectTemplate("Empty app project"d, "Empty application project.\nNo source files."d);
        _templates ~= new ProjectTemplate("Empty library project"d, "Empty library project.\nNo Source files."d);
        _templates ~= new ProjectTemplate("Hello world app"d, "Hello world application."d);
        _templates ~= new ProjectTemplate("DlangUI: hello world app"d, "Hello world application\nbased on DlangUI library"d);
    }

    int _currentTemplateIndex = -1;
    ProjectTemplate _currentTemplate;
    ProjectTemplate[] _templates;

    protected void templateSelected(int index) {
        if (_currentTemplateIndex == index)
            return;
        _currentTemplateIndex = index;
        _currentTemplate = _templates[index];
        _templateDescription.text = _currentTemplate.description;
    }

    protected void updateDirLayout() {
        dchar[] buf;
        buf ~= _workspaceName ~ toUTF32(WORKSPACE_EXTENSION) ~ "\n";
        dstring level = "";
        if (_cbCreateSubdir.checked) {
            buf ~= _projectName ~ "/\n";
            level = "    ";
        }
        buf ~= level ~ "dub.json" ~ "\n";
        _directoryLayout.text = buf.dup;
    }
}

class ProjectTemplate {
    dstring name;
    dstring description;
    this(dstring name, dstring description) {
        this.name = name;
        this.description = description;
    }
}
