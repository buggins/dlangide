module dlangide.ui.newproject;

import dlangui.core.types;
import dlangui.core.i18n;
import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.editors;
import dlangui.widgets.controls;
import dlangui.widgets.lists;
import dlangui.dml.parser;
import dlangui.core.stdaction;
import dlangui.core.files;
import dlangide.workspace.project;
import dlangide.workspace.workspace;
import dlangide.ui.commands;
import dlangide.ui.frame;

import std.path;
import std.file;
import std.array : empty;

class ProjectCreationResult {
    Workspace workspace;
    Project project;
    this(Workspace workspace, Project project) {
        this.workspace = workspace;
        this.project = project;
    }
}

class NewProjectDlg : Dialog {

    Workspace _currentWorkspace;
    IDEFrame _ide;

    this(IDEFrame parent, bool newWorkspace, Workspace currentWorkspace) {
		super(newWorkspace ? UIString("New Workspace"d) : UIString("New Project"d), parent.window, 
              DialogFlag.Modal | DialogFlag.Resizable | DialogFlag.Popup, 500, 400);
        _ide = parent;
        _icon = "dlangui-logo1";
        this._currentWorkspace = currentWorkspace;
        _newWorkspace = newWorkspace;
        _location = currentWorkspace !is null ? currentWorkspace.dir : currentDir;
    }

	/// override to implement creation of dialog controls
	override void init() {
        super.init();
        initTemplates();
		Widget content;
        try {
            content = parseML(q{
                    VerticalLayout {
                        id: vlayout
                        padding: Rect { 5, 5, 5, 5 }
                        layoutWidth: fill; layoutHeight: fill
                        HorizontalLayout {
                            layoutWidth: fill; layoutHeight: fill
                            VerticalLayout {
                                margins: 5
                                layoutWidth: wrap; layoutHeight: fill
                                TextWidget { text: "Project template" }
                                StringListWidget { 
                                    id: projectTemplateList 
                                    layoutWidth: wrap; layoutHeight: fill
                                }
                            }
                            VerticalLayout {
                                margins: 5
                                layoutWidth: fill; layoutHeight: fill
                                TextWidget { text: "Template description" }
                                EditBox { 
                                    id: templateDescription; readOnly: true 
                                    layoutWidth: fill; layoutHeight: fill
                                }
                            }
                            VerticalLayout {
                                layoutWidth: fill; layoutHeight: fill
                                margins: 5
                                TextWidget { text: "Directory layout" }
                                EditBox { 
                                    id: directoryLayout; readOnly: true
                                    layoutWidth: fill; layoutHeight: fill
                                }
                            }
                        }
                        TableLayout {
                            margins: 5
                            colCount: 2
                            layoutWidth: fill; layoutHeight: wrap
                            TextWidget { text: "" }
                            CheckBox { id: cbCreateWorkspace; text: "Create new solution"; checked: true }
                            TextWidget { text: "Workspace name" }
                            EditLine { id: edWorkspaceName; text: "newworkspace"; layoutWidth: fill }
                            TextWidget { text: "" }
                            CheckBox { id: cbCreateWorkspaceSubdir; text: "Create subdirectory for workspace"; checked: true }
                            TextWidget { text: "Project name" }
                            EditLine { id: edProjectName; text: "newproject"; layoutWidth: fill }
                            TextWidget { text: "" }
                            CheckBox { id: cbCreateSubdir; text: "Create subdirectory for project"; checked: true }
                            TextWidget { text: "Location" }
                            DirEditLine { id: edLocation; layoutWidth: fill }
                        }
                        TextWidget { id: statusText; text: ""; layoutWidth: fill }
                    }
                });
        } catch (Exception e) {
            Log.e("Exceptin while parsing DML", e);
            throw e;
        }


        _projectTemplateList = content.childById!StringListWidget("projectTemplateList");
        _templateDescription = content.childById!EditBox("templateDescription");
        _directoryLayout = content.childById!EditBox("directoryLayout");
        _edProjectName = content.childById!EditLine("edProjectName");
        _edWorkspaceName = content.childById!EditLine("edWorkspaceName");
        _cbCreateSubdir = content.childById!CheckBox("cbCreateSubdir");
        _cbCreateWorkspace = content.childById!CheckBox("cbCreateWorkspace");
        _cbCreateWorkspaceSubdir = content.childById!CheckBox("cbCreateWorkspaceSubdir");
        _edLocation = content.childById!DirEditLine("edLocation");
        _edLocation.text = toUTF32(_location);
        _statusText = content.childById!TextWidget("statusText");

        _edLocation.filetypeIcons[".d"] = "text-d";
        _edLocation.filetypeIcons["dub.json"] = "project-d";
        _edLocation.filetypeIcons["package.json"] = "project-d";
        _edLocation.filetypeIcons[".dlangidews"] = "project-development";
        _edLocation.addFilter(FileFilterEntry(UIString("DlangIDE files"d), "*.dlangidews;*.d;*.dd;*.di;*.ddoc;*.dh;*.json;*.xml;*.ini"));
        _edLocation.caption = "Select directory"d;

        if (_currentWorkspace) {
            _workspaceName = toUTF8(_currentWorkspace.name);
            _edWorkspaceName.text = toUTF32(_workspaceName);
            _cbCreateWorkspaceSubdir.enabled = false;
            _cbCreateWorkspaceSubdir.checked = false;
        } else {
            _cbCreateWorkspace.checked = true;
            _cbCreateWorkspace.enabled = false;
        }
        if (!_newWorkspace) {
            _cbCreateWorkspace.checked = false;
            _cbCreateWorkspace.enabled = _currentWorkspace !is null;
            _edWorkspaceName.readOnly = true;
        }


        // fill templates
        dstring[] names;
        foreach(t; _templates)
            names ~= t.name;
        _projectTemplateList.items = names;
        _projectTemplateList.selectedItemIndex = 0;

        templateSelected(0);
        updateDirLayout();

        // listeners
        _edProjectName.contentChange = delegate (EditableContent source) {
            _projectName = toUTF8(source.text);
            updateDirLayout();
        };

        _edWorkspaceName.contentChange = delegate (EditableContent source) {
            _workspaceName = toUTF8(source.text);
            updateDirLayout();
        };

        _edLocation.contentChange = delegate (EditableContent source) {
            _location = toUTF8(source.text);
            updateDirLayout();
        };

        _cbCreateWorkspace.checkChange = delegate (Widget source, bool checked) {
            _edWorkspaceName.readOnly = !checked;
            _cbCreateWorkspaceSubdir.enabled = checked;
            updateDirLayout();
            return true;
        };

        _cbCreateSubdir.checkChange = delegate (Widget source, bool checked) {
            updateDirLayout();
            return true;
        };

        _cbCreateWorkspaceSubdir.checkChange = delegate (Widget source, bool checked) {
            _edWorkspaceName.readOnly = !checked;
            updateDirLayout();
            return true;
        };

        _projectTemplateList.itemSelected = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };
        _projectTemplateList.itemClick = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };

        addChild(content);
        addChild(createButtonsPanel([_newWorkspace ? ACTION_FILE_NEW_WORKSPACE : ACTION_FILE_NEW_PROJECT, ACTION_CANCEL], 0, 0));
	}

	bool _newWorkspace;
    StringListWidget _projectTypeList;
    StringListWidget _projectTemplateList;
    EditBox _templateDescription;
    EditBox _directoryLayout;
    DirEditLine _edLocation;
    EditLine _edWorkspaceName;
    EditLine _edProjectName;
    CheckBox _cbCreateSubdir;
    CheckBox _cbCreateWorkspace;
    CheckBox _cbCreateWorkspaceSubdir;
    TextWidget _statusText;
    string _projectName = "newproject";
    string _workspaceName = "newworkspace";
    string _location;

    int _currentTemplateIndex = -1;
    ProjectTemplate _currentTemplate;
    ProjectTemplate[] _templates;

    protected void templateSelected(int index) {
        if (_currentTemplateIndex == index)
            return;
        _currentTemplateIndex = index;
        _currentTemplate = _templates[index];
        _templateDescription.text = _currentTemplate.description;
        updateDirLayout();
    }

    protected void updateDirLayout() {
        dchar[] buf;
        dstring level = "";
        if (_cbCreateWorkspaceSubdir.checked) {
            buf ~= toUTF32(_workspaceName) ~ "/\n";
            level ~= "    ";
        }
        if (_cbCreateWorkspace.checked) {
            buf ~= level ~ toUTF32(_workspaceName) ~ toUTF32(WORKSPACE_EXTENSION) ~ "\n";
        }
        if (_cbCreateSubdir.checked) {
            buf ~= level ~ toUTF32(_projectName) ~ "/\n";
            level ~= "    ";
        }
        buf ~= level ~ "dub.json" ~ "\n";
        buf ~= level ~ "source/" ~ "\n";
        if (!_currentTemplate.srcfile.empty) {
            buf ~= level ~ "    " ~ toUTF32(_currentTemplate.srcfile) ~ "\n";
        }
        _directoryLayout.text = buf.dup;
        validate();
    }

    bool setError(dstring msg) {
        _statusText.text = msg;
        return msg.empty;
    }
    dstring getError() {
        return _statusText.text;
    }

    ProjectCreationResult _result;

    override void close(const Action action) {
        Action newaction = action.clone();
        if (action.id == IDEActions.FileNewWorkspace || action.id == IDEActions.FileNewProject) {
            if (!validate()) {
                window.showMessageBox(UIString("Cannot create project"d), UIString(getError()));
                return;
            }
            if (!createProject()) {
                window.showMessageBox(UIString("Cannot create project"d), UIString("Failed to create project"));
                return;
            }
            newaction.objectParam = _result;
        }
        super.close(newaction);
    }

    bool validate() {
        if (!exists(_location)) {
            return setError("The location directory does not exist");
        }
        if(!isDir(_location)) {
            return setError("The location is not a directory");
        }
        if (!isValidProjectName(_projectName))
            return setError("Invalid project name");
        if (!isValidProjectName(_workspaceName))
            return setError("Invalid workspace name");
        return setError("");
    }

    bool createProject() {
        if (!validate())
            return false;
        Workspace ws = _currentWorkspace;
        string wsdir = _location;
        if (_newWorkspace) {
            if (_cbCreateWorkspaceSubdir.checked) {
                wsdir = buildNormalizedPath(wsdir, _workspaceName);
                if (wsdir.exists) {
                    if (!wsdir.isDir)
                        return setError("Cannot create workspace directory");
                } else {
                    try {
                        mkdir(wsdir);
                    } catch (Exception e) {
                        return setError("Cannot create workspace directory");
                    }
                }
            }
            string wsfilename = buildNormalizedPath(wsdir, _workspaceName ~ WORKSPACE_EXTENSION);
            ws = new Workspace(_ide, wsfilename);
            ws.name = toUTF32(_workspaceName);
            if (!ws.save())
                return setError("Cannot create workspace file");
        }
        string pdir = wsdir;
        if (_cbCreateSubdir.checked) {
            pdir = buildNormalizedPath(pdir, _projectName);
            if (pdir.exists) {
                if (!pdir.isDir)
                    return setError("Cannot create project directory");
            } else {
                try {
                    mkdir(pdir);
                } catch (Exception e) {
                    return setError("Cannot create project directory");
                }
            }
        }
        string pfile = buildNormalizedPath(pdir, "dub.json");
        Project project = new Project(ws, pfile);
        project.name = toUTF32(_projectName);
        if (!project.save())
            return setError("Cannot save project");
        project.content.setString("targetName", _projectName);
        if (_currentTemplate.isLibrary) {
            project.content.setString("targetType", "staticLibrary");
            project.content.setString("targetPath", "lib");
        } else {
            project.content.setString("targetType", "executable");
            project.content.setString("targetPath", "bin");
        }
        if (_currentTemplate.json)
            project.content.merge(_currentTemplate.json);
        project.save();
        ws.addProject(project);
        if (ws.startupProject is null)
            ws.startupProject = project;
        if (!_currentTemplate.srcfile.empty && !_currentTemplate.srccode.empty) {
            string srcdir = buildNormalizedPath(pdir, "source");
            if (!exists(srcdir))
                mkdir(srcdir);
            string srcfile = buildNormalizedPath(srcdir, _currentTemplate.srcfile);
            write(srcfile, _currentTemplate.srccode);
        }
        if (!project.save())
            return setError("Cannot save project file");
        if (!ws.save())
            return setError("Cannot save workspace file");
        project.load();
        _result = new ProjectCreationResult(ws, project);
        return true;
    }

    void initTemplates() {
        _templates ~= new ProjectTemplate("Hello world app"d, "Hello world application."d, "app.d",
                    SOURCE_CODE_HELLOWORLD, false);
        _templates ~= new ProjectTemplate("DlangUI: hello world app"d, "Hello world application\nbased on DlangUI library"d, "app.d",
                    SOURCE_CODE_DLANGUI_HELLOWORLD, false, DUB_JSON_DLANGUI_HELLOWORLD);
        _templates ~= new ProjectTemplate("Empty app project"d, "Empty application project.\nNo source files."d, null, null, false);
        _templates ~= new ProjectTemplate("Empty library project"d, "Empty library project.\nNo Source files."d, null, null, true);
    }
}

immutable string SOURCE_CODE_HELLOWORLD = q{
import std.stdio;
void main(string[] args) {
    writeln("Hello World!");
    writeln("Press enter...");
    readln();
}
};

immutable string SOURCE_CODE_DLANGUI_HELLOWORLD = q{
import dlangui;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {
    // create window
    Window window = Platform.instance.createWindow("DlangUI HelloWorld", null);

    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    window.mainWidget = parseML(q{
        VerticalLayout {
            margins: 10
            padding: 10
            backgroundColor: "#C0E0E070" // semitransparent yellow background
            // red bold text with size = 150% of base style size and font face Arial
            TextWidget { text: "Hello World example for DlangUI"; textColor: "red"; fontSize: 150%; fontWeight: 800; fontFace: "Arial" }
            // arrange controls as form - table with two columns
            TableLayout {
                colCount: 2
                TextWidget { text: "param 1" }
                EditLine { id: edit1; text: "some text" }
                TextWidget { text: "param 2" }
                EditLine { id: edit2; text: "some text for param2" }
                TextWidget { text: "some radio buttons" }
                // arrange some radio buttons vertically
                VerticalLayout {
                    RadioButton { id: rb1; text: "Item 1" }
                    RadioButton { id: rb2; text: "Item 2" }
                    RadioButton { id: rb3; text: "Item 3" }
                }
                TextWidget { text: "and checkboxes" }
                // arrange some checkboxes horizontally
                HorizontalLayout {
                    CheckBox { id: cb1; text: "checkbox 1" }
                    CheckBox { id: cb2; text: "checkbox 2" }
                }
            }
            HorizontalLayout {
                Button { id: btnOk; text: "Ok" }
                Button { id: btnCancel; text: "Cancel" }
            }
        }
    });
    // you can access loaded items by id - e.g. to assign signal listeners
    auto edit1 = window.mainWidget.childById!EditLine("edit1");
    auto edit2 = window.mainWidget.childById!EditLine("edit2");
    // close window on Cancel button click
    window.mainWidget.childById!Button("btnCancel").click = delegate(Widget w) {
        window.close();
        return true;
    };
    // show message box with content of editors
    window.mainWidget.childById!Button("btnOk").click = delegate(Widget w) {
        window.showMessageBox(UIString("Ok button pressed"d), 
                              UIString("Editors content\nEdit1: "d ~ edit1.text ~ "\nEdit2: "d ~ edit2.text));
        return true;
    };

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
};

immutable string DUB_JSON_DLANGUI_HELLOWORLD = q{
{
	"dependencies": {
	    "dlangui": "~master"
	}
}
};

class ProjectTemplate {
    dstring name;
    dstring description;
    string srcfile;
    string srccode;
    bool isLibrary;
    string json;
    this(dstring name, dstring description, string srcfile, string srccode, bool isLibrary, string json = null) {
        this.name = name;
        this.description = description;
        this.srcfile = srcfile;
        this.srccode = srccode;
        this.isLibrary = isLibrary;
        this.json = json;
    }
}
