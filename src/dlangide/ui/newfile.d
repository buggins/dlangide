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

import std.algorithm : startsWith, endsWith, equal;
import std.array : empty;
import std.utf : toUTF32;
import std.file;
import std.path;

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
        super(UIString.fromId("OPTION_NEW_SOURCE_FILE"c), parent.window, 
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
                                    layoutWidth: 50%; layoutHeight: fill
                                TextWidget { text: OPTION_PROJECT_TEMPLATE }
                                StringListWidget { 
                                id: projectTemplateList 
                                        layoutWidth: wrap; layoutHeight: fill
                                }
                            }
                            VerticalLayout {
                            margins: 5
                                    layoutWidth: 50%; layoutHeight: fill
                                TextWidget { text: OPTION_TEMPLATE_DESCR }
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
                            TextWidget { text: NAME }
                            EditLine { id: edName; text: "newfile"; layoutWidth: fill }
                            TextWidget { text: LOCATION }
                            DirEditLine { id: edLocation; layoutWidth: fill }
                            TextWidget { text: OPTION_MODULE_NAME }
                            EditLine { id: edModuleName; text: ""; layoutWidth: fill; readOnly: true }
                            TextWidget { text: OPTION_FILE_PATH }
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
        _edLocation.addFilter(FileFilterEntry(UIString.fromId("IDE_FILES"c), "*.dlangidews;*.d;*.dd;*.di;*.ddoc;*.dh;*.json;*.xml;*.ini;*.dt"));
        _edLocation.caption = "Select directory"d;

        _edFileName.enterKey.connect(&onEnterKey);
        _edFilePath.enterKey.connect(&onEnterKey);
        _edModuleName.enterKey.connect(&onEnterKey);
        _edLocation.enterKey.connect(&onEnterKey);

        _edFileName.setDefaultPopupMenu();
        _edFilePath.setDefaultPopupMenu();
        _edModuleName.setDefaultPopupMenu();
        _edLocation.setDefaultPopupMenu();

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

    /// called after window with dialog is shown
    override void onShow() {
        super.onShow();
        _edFileName.selectAll();
        _edFileName.setFocus();
    }

    protected bool onEnterKey(EditWidgetBase editor) {
        if (!validate())
            return false;
        close(_buttonActions[0]);
        return true;
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

        if (_currentTemplate.kind == FileKind.MODULE || _currentTemplate.kind == FileKind.PACKAGE) {
            string sourcePath, relativePath;
            if (!findSource(_sourcePaths, _location, sourcePath, relativePath))
                return setError("Location is outside of source path");
            if (!isValidModuleName(filename))
                return setError("Invalid file name");
            _moduleName = filename; 
            _packageName = getPackageName(sourcePath, relativePath);
            string m;
            if (_currentTemplate.kind == FileKind.MODULE) {
                m = !_packageName.empty ? _packageName ~ '.' ~ _moduleName : _moduleName;
            } else {
                m = _packageName;
            }
            _edModuleName.text = toUTF32(m);
            _packageName = m;
            if (_currentTemplate.kind == FileKind.PACKAGE && _packageName.length == 0)
                return setError("Package should be located in subdirectory");
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
        if(!createFile(_fullPathName, _currentTemplate.kind, _packageName, _currentTemplate.srccode)) {
            return setError("Cannot create file");
        }
        
        _result = new FileCreationResult(_project, _fullPathName);
        return true;
    }

    override void close(const Action action) {
        Action newaction = action.clone();
        if (action.id == IDEActions.FileNew) {
            if (!validate()) {
                window.showMessageBox(UIString.fromId("ERROR"c), UIString.fromId("ERROR_INVALID_PARAMETERS"c));
                return;
            }
            if (!createItem()) {
                window.showMessageBox(UIString.fromId("ERROR"c), UIString.fromId("ERROR_INVALID_PARAMETERS"c));
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
        if (_currentTemplate.kind == FileKind.PACKAGE) {
            _edFileName.enabled = false;
            _edFileName.text = "package"d;
        } else {
            if (_edFileName.text == "package")
                _edFileName.text = "newfile";
            _edFileName.enabled = true;
        }
        //updateDirLayout();
        validate();
    }

    void initTemplates() {
        _templates ~= new ProjectTemplate("Empty module"d, "Empty D module file."d, ".d",
            "\n", FileKind.MODULE);
        _templates ~= new ProjectTemplate("Package"d, "D package."d, ".d",
            "\n", FileKind.PACKAGE);
        _templates ~= new ProjectTemplate("Text file"d, "Empty text file."d, ".txt",
            "\n", FileKind.TEXT);
        _templates ~= new ProjectTemplate("JSON file"d, "Empty json file."d, ".json",
            "{\n}\n", FileKind.TEXT);
        _templates ~= new ProjectTemplate("Vibe-D Diet Template file"d, "Empty Vibe-D Diet Template."d, ".dt",
            q{
                doctype html
                    html
                        head
                        title Hello, World
                        body
                        h1 Hello World
            }, FileKind.TEXT);
    }
}

enum FileKind {
    MODULE,
    PACKAGE,
    TEXT,
}

class ProjectTemplate {
    dstring name;
    dstring description;
    string fileExtension;
    string srccode;
    FileKind kind;
    this(dstring name, dstring description, string fileExtension, string srccode, FileKind kind) {
        this.name = name;
        this.description = description;
        this.fileExtension = fileExtension;
        this.srccode = srccode;
        this.kind = kind;
    }
}

bool createFile(string fullPathName, FileKind fileKind, string packageName, string sourceCode) {
    try {
        if (fileKind == FileKind.MODULE) {
            string txt = "module " ~ packageName ~ ";\n\n" ~ sourceCode;
            write(fullPathName, txt);
        } else if (fileKind == FileKind.PACKAGE) {
            string txt = "module " ~ packageName ~ ";\n\n" ~ sourceCode;
            write(fullPathName, txt);
        } else {
            write(fullPathName, sourceCode);
        }
        return true;
    }
    catch(Exception e) 	{
        Log.e("Cannot create file", e);
        return false;
    }
}

string getPackageName(string path, string[] sourcePaths){
    string sourcePath, relativePath;
    if(!findSource(sourcePaths, path, sourcePath, relativePath)) return "";
    return getPackageName(sourcePath, relativePath);
}

string getPackageName(string sourcePath, string relativePath){

    char[] buf;
    foreach(c; relativePath) {
        char ch = c;
        if (ch == '/' || ch == '\\')
            ch = '.';
        else if (ch == '.')
            ch = '_';
        if (ch == '.' && (buf.length == 0 || buf[$-1] == '.'))
            continue; // skip duplicate .
        buf ~= ch;
    }
    if (buf.length && buf[$-1] == '.')
        buf.length--;
    return buf.dup;
}
private bool findSource(string[] sourcePaths, string path, ref string sourceFolderPath, ref string relativePath) {
    foreach(dir; sourcePaths) {
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
private bool isSubdirOf(string path, string basePath) {
    if (path.equal(basePath))
        return true;
    if (path.length > basePath.length + 1 && path.startsWith(basePath)) {
        char ch = path[basePath.length];
        return ch == '/' || ch == '\\';
    }
    return false;
}