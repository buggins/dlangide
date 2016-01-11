module dlangide.ui.newfile;

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
import std.algorithm : startsWith, endsWith;

class FileCreationResult {
    Project project;
    string filename;
    this(Project project, string filename) {
        this.project = project;
        this.filename = filename;
    }
}

class NewFileDlg : Dialog {
    IDEFrame _ide;
    Project _project;
    ProjectFolder _folder;
    string[] _sourcePaths;
    this(IDEFrame parent, Project currentProject, ProjectFolder folder) {
        super(UIString("New source file"d), parent.window, 
              DialogFlag.Modal | DialogFlag.Resizable | DialogFlag.Popup, 500, 400);
        _ide = parent;
        _icon = "dlangui-logo1";
        this._project = currentProject;
        this._folder = folder;
        _location = folder ? folder.filename : currentProject.dir;
        _sourcePaths = currentProject.sourcePaths;
        if (_sourcePaths.length)
            _location = _sourcePaths[0];
        if (folder)
            _location = folder.filename;
    }
    /// override to implement creation of dialog controls
    override void initialize() {
        super.initialize();
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
                        }
                        TableLayout {
                            margins: 5
                            colCount: 2
                            layoutWidth: fill; layoutHeight: wrap
                            TextWidget { text: "Name" }
                            EditLine { id: edName; text: "newfile"; layoutWidth: fill }
                            TextWidget { text: "Location" }
                            DirEditLine { id: edLocation; layoutWidth: fill }
                            TextWidget { text: "Module name" }
                            EditLine { id: edModuleName; text: ""; layoutWidth: fill; readOnly: true }
                            TextWidget { text: "File path" }
                            EditLine { id: edFilePath; text: ""; layoutWidth: fill; readOnly: true }
                        }
                        TextWidget { id: statusText; text: ""; layoutWidth: fill; textColor: #FF0000 }
                    }
                });
        } catch (Exception e) {
            Log.e("Exceptin while parsing DML", e);
            throw e;
        }


        _projectTemplateList = content.childById!StringListWidget("projectTemplateList");
        _templateDescription = content.childById!EditBox("templateDescription");
        _edFileName = content.childById!EditLine("edName");
        _edFilePath = content.childById!EditLine("edFilePath");
        _edModuleName = content.childById!EditLine("edModuleName");
        _edLocation = content.childById!DirEditLine("edLocation");
        _edLocation.text = toUTF32(_location);
        _statusText = content.childById!TextWidget("statusText");

        _edLocation.filetypeIcons[".d"] = "text-d";
        _edLocation.filetypeIcons["dub.json"] = "project-d";
        _edLocation.filetypeIcons["package.json"] = "project-d";
        _edLocation.filetypeIcons[".dlangidews"] = "project-development";
        _edLocation.addFilter(FileFilterEntry(UIString("DlangIDE files"d), "*.dlangidews;*.d;*.dd;*.di;*.ddoc;*.dh;*.json;*.xml;*.ini"));
        _edLocation.caption = "Select directory"d;

        // fill templates
        dstring[] names;
        foreach(t; _templates)
            names ~= t.name;
        _projectTemplateList.items = names;
        _projectTemplateList.selectedItemIndex = 0;

        templateSelected(0);

        // listeners
        _edLocation.contentChange = delegate (EditableContent source) {
            _location = toUTF8(source.text);
            validate();
        };

        _edFileName.contentChange = delegate (EditableContent source) {
            _fileName = toUTF8(source.text);
            validate();
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
        addChild(createButtonsPanel([ACTION_FILE_NEW_SOURCE_FILE, ACTION_CANCEL], 0, 0));

    }

    StringListWidget _projectTemplateList;
    EditBox _templateDescription;
    DirEditLine _edLocation;
    EditLine _edFileName;
    EditLine _edModuleName;
    EditLine _edFilePath;
    TextWidget _statusText;

    string _fileName = "newfile";
    string _location;
    string _moduleName;
    string _packageName;
    string _fullPathName;

    int _currentTemplateIndex = -1;
    ProjectTemplate _currentTemplate;
    ProjectTemplate[] _templates;

    static bool isSubdirOf(string path, string basePath) {
        if (path.equal(basePath))
            return true;
        if (path.length > basePath.length + 1 && path.startsWith(basePath)) {
            char ch = path[basePath.length];
            return ch == '/' || ch == '\\';
        }
        return false;
    }

    bool findSource(string path, ref string sourceFolderPath, ref string relativePath) {
        foreach(dir; _sourcePaths) {
            if (isSubdirOf(path, dir)) {
                sourceFolderPath = dir;
                relativePath = path[sourceFolderPath.length .. $];
                if (relativePath.length > 0 && (relativePath[0] == '\\' || relativePath[0] == '/'))
                    relativePath = relativePath[1 .. $];
                return true;
            }
        }
        return false;
    }

    bool setError(dstring msg) {
        _statusText.text = msg;
        return msg.empty;
    }

    bool validate() {
        string filename = _fileName;
        string fullFileName = filename;
        if (!_currentTemplate.fileExtension.empty && filename.endsWith(_currentTemplate.fileExtension))
            filename = filename[0 .. $ - _currentTemplate.fileExtension.length];
        else
            fullFileName = fullFileName ~ _currentTemplate.fileExtension;
        _fullPathName = buildNormalizedPath(_location, fullFileName);
        _edFilePath.text = toUTF32(_fullPathName);
        if (!isValidFileName(filename))
            return setError("Invalid file name");
        if (!exists(_location) || !isDir(_location))
            return setError("Location directory does not exist");

        if (_currentTemplate.isModule) {
            string sourcePath, relativePath;
            if (!findSource(_location, sourcePath, relativePath))
                return setError("Location is outside of source path");
            if (!isValidModuleName(filename))
                return setError("Invalid file name");
            _moduleName = filename;
            char[] buf;
            foreach(ch; relativePath) {
                if (ch == '/' || ch == '\\')
                    buf ~= '.';
                else
                    buf ~= ch;
            }
            _packageName = buf.dup;
            string m = !_packageName.empty ? _packageName ~ '.' ~ _moduleName : _moduleName;
            _edModuleName.text = toUTF32(m);
            _packageName = m;
        } else {
            string projectPath = _project.dir;
            if (!isSubdirOf(_location, projectPath))
                return setError("Location is outside of project path");
            _edModuleName.text = "";
            _moduleName = "";
            _packageName = "";
        }
        return true;
    }

    private FileCreationResult _result;
    bool createItem() {
        try {
            if (_currentTemplate.isModule) {
                string txt = "module " ~ _packageName ~ ";\n\n" ~ _currentTemplate.srccode;
                write(_fullPathName, txt);
            } else {
                write(_fullPathName, _currentTemplate.srccode);
            }
        } catch (Exception e) {
            Log.e("Cannot create file", e);
            return setError("Cannot create file");
        }
        _result = new FileCreationResult(_project, _fullPathName);
        return true;
    }

    override void close(const Action action) {
        Action newaction = action.clone();
        if (action.id == IDEActions.FileNew) {
            if (!validate()) {
                window.showMessageBox(UIString("Error"d), UIString("Invalid parameters"));
                return;
            }
            if (!createItem()) {
                window.showMessageBox(UIString("Error"d), UIString("Failed to create project item"));
                return;
            }
            newaction.objectParam = _result;
        }
        super.close(newaction);
    }

    protected void templateSelected(int index) {
        if (_currentTemplateIndex == index)
            return;
        _currentTemplateIndex = index;
        _currentTemplate = _templates[index];
        _templateDescription.text = _currentTemplate.description;
        //updateDirLayout();
        validate();
    }

    void initTemplates() {
        _templates ~= new ProjectTemplate("Empty module"d, "Empty D module file."d, ".d",
                    "\n", true);
        _templates ~= new ProjectTemplate("Text file"d, "Empty text file."d, ".txt",
                    "\n", true);
        _templates ~= new ProjectTemplate("JSON file"d, "Empty json file."d, ".json",
                    "{\n}\n", true);
    }
}

class ProjectTemplate {
    dstring name;
    dstring description;
    string fileExtension;
    string srccode;
    bool isModule;
    this(dstring name, dstring description, string fileExtension, string srccode, bool isModule) {
        this.name = name;
        this.description = description;
        this.fileExtension = fileExtension;
        this.srccode = srccode;
        this.isModule = isModule;
    }
}

