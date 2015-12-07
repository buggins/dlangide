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
		super(newWorkspace ? UIString("New Workspace"d) : UIString("New Project"d), parent.window, DialogFlag.Modal | DialogFlag.Resizable, 500, 400);
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
        _edLocation = content.childById!DirEditLine("edLocation");
        _edLocation.text = toUTF32(_location);
        _statusText = content.childById!TextWidget("statusText");

        if (_currentWorkspace) {
            _workspaceName = toUTF8(_currentWorkspace.name);
            _edWorkspaceName.text = toUTF32(_workspaceName);
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
    TextWidget _statusText;
    string _projectName = "newproject";
    string _workspaceName = "newworkspace";
    string _location;

    void initTemplates() {
        _templates ~= new ProjectTemplate("Empty app project"d, "Empty application project.\nNo source files."d, null, null, false);
        _templates ~= new ProjectTemplate("Empty library project"d, "Empty library project.\nNo Source files."d, null, null, true);
        _templates ~= new ProjectTemplate("Hello world app"d, "Hello world application."d, "app.d",
                    q{
                        import std.stdio;
                        void main(string[] args) {
                            writeln("Hello World!");
                        }
                    }, false);
        _templates ~= new ProjectTemplate("DlangUI: hello world app"d, "Hello world application\nbased on DlangUI library"d, "app.d",
                    q{
                        import std.stdio;
                        void main(string[] args) {
                            writeln("Hello World!");
                        }
                    }, false);
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
        updateDirLayout();
    }

    protected void updateDirLayout() {
        dchar[] buf;
        if (_cbCreateSubdir.checked)
            buf ~= toUTF32(_workspaceName) ~ toUTF32(WORKSPACE_EXTENSION) ~ "\n";
        dstring level = "";
        if (_cbCreateSubdir.checked) {
            buf ~= toUTF32(_projectName) ~ "/\n";
            level = "    ";
        }
        buf ~= level ~ "dub.json" ~ "\n";
        buf ~= level ~ "source/" ~ "\n";
        if (_currentTemplate.srcfile.length) {
            buf ~= level ~ "    " ~ toUTF32(_currentTemplate.srcfile) ~ "\n";
        }
        _directoryLayout.text = buf.dup;
        validate();
    }

    bool setError(dstring msg) {
        _statusText.text = msg;
        return msg.empty;
    }

    ProjectCreationResult _result;

    override void close(const Action action) {
        Action newaction = action.clone();
        if (action.id == IDEActions.FileNewWorkspace || action.id == IDEActions.FileNewProject) {
            if (!validate()) {
                window.showMessageBox(UIString("Cannot create project"d), UIString("Invalid parameters"));
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
        if (!exists(_location) || !isDir(_location)) {
            return setError("Invalid location");
        }
        return setError("");
    }

    bool createProject() {
        if (!validate())
            return false;
        Workspace ws = _currentWorkspace;
        if (_newWorkspace) {
            string wsfilename = buildNormalizedPath(_location, _workspaceName ~ WORKSPACE_EXTENSION);
            ws = new Workspace(_ide, wsfilename);
            ws.name = toUTF32(_workspaceName);
            if (!ws.save())
                return setError("Cannot create workspace file");
        }
        string pdir = _location;
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
        project.save();
        ws.addProject(project);
        if (ws.startupProject is null)
            ws.startupProject = project;
        if (!_currentTemplate.srcfile.empty && !_currentTemplate.srccode.empty) {
            string srcdir = buildNormalizedPath(pdir, "dub.json");
            if (!exists(srcdir))
                mkdir(srcdir);
            string srcfile = buildNormalizedPath(srcdir, _currentTemplate.srcfile);
            write(srcfile, _currentTemplate.srccode);
        }
        if (!project.save())
            return setError("Cannot save project file");
        if (!ws.save())
            return setError("Cannot save workspace file");
        _result = new ProjectCreationResult(ws, project);
        return true;
    }
}

class ProjectTemplate {
    dstring name;
    dstring description;
    string srcfile;
    string srccode;
    bool isLibrary;
    this(dstring name, dstring description, string srcfile, string srccode, bool isLibrary) {
        this.name = name;
        this.description = description;
        this.srcfile = srcfile;
        this.srccode = srccode;
        this.isLibrary = isLibrary;
    }
}
