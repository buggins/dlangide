module dlangide.ui.newfolder;

import std.array : empty;
import std.file : mkdir, exists;
import std.path : buildNormalizedPath;
import std.utf : toUTF32;

import dlangui.core.logger;
import dlangui.core.stdaction;
import dlangui.dialogs.dialog;
import dlangui.dml.parser;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.widget;

import dlangide.ui.commands;
import dlangide.ui.frame;
import dlangide.ui.newfile;
import dlangide.workspace.project;

class NewFolderDialog : Dialog {
    private {
        IDEFrame _ide;
        Project _project;
        ProjectFolder _folder;
        string _location;
    }


    this(IDEFrame parent, Project currentProject, ProjectFolder folder) {
        super(UIString.fromId("OPTION_NEW_SOURCE_FILE"c), parent.window, 
              DialogFlag.Modal | DialogFlag.Resizable | DialogFlag.Popup, 500, 400);
        _ide = parent;
        _icon = "dlangui-logo1";
        this._project = currentProject;
        this._folder = folder;
        if (folder){
            _location = folder.filename;
        } 
        else {
            _location = currentProject.dir;
        }
    }

    override void initialize() {
        super.initialize();
        Widget content;
        try {
            content = parseML(q{
                    VerticalLayout {
                        id: vlayout
                        padding: Rect { 5, 5, 5, 5 }
                        layoutWidth: fill; layoutHeight: fill
                        TableLayout {
                            margins: 5
                            colCount: 2
                            layoutWidth: fill; layoutHeight: wrap
                            TextWidget { text: NAME }
                            EditLine { id: edName; text: "newfolder"; layoutWidth: fill }
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
        _edFileName = content.childById!EditLine("edName");
        _edFilePath = content.childById!EditLine("edFilePath");
        _statusText = content.childById!TextWidget("statusText");

        _edFileName.enterKey.connect(&onEnterKey);
        _edFilePath.enterKey.connect(&onEnterKey);

        _edFileName.setDefaultPopupMenu();
        _edFilePath.setDefaultPopupMenu();

        _edFileName.contentChange = delegate (EditableContent source) {
            updateValues(source.text);
            validate();
        };

        addChild(content);
        addChild(createButtonsPanel([ACTION_FILE_NEW_DIRECTORY, ACTION_CANCEL], 0, 0));

        updateValues(_edFileName.text);
    }

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

    private bool validate() {
        if (!isValidModuleName(_fileName))
            return setError("Invalid folder name");
        return setError(null);
    }

    private void updateValues(dstring fileName) {
        _fileName = toUTF8(fileName);
        _edFilePath.text = toUTF32(fullPathName);
    }

    private bool setError(dstring msg) {
        _statusText.text = msg;
        return msg.empty;
    }

    private {
        EditLine _edFileName;
        EditLine _edFilePath;
        TextWidget _statusText;

        string _fileName = "newfile";
        FileCreationResult _result;
        string fullPathName() @property {
            return buildNormalizedPath(_location, _fileName);
        }
    }

    private bool createItem() {
        string fullPathName = this.fullPathName;
        if(exists(fullPathName))
            return setError("Folder already exists");
        try {
            mkdir(fullPathName);
        } catch (Exception e) {
            Log.e("Cannot create folder", e);
            return setError("Cannot create folder");
        }
        _result = new FileCreationResult(_project, fullPathName);
        return true;
    }

    override void close(const Action action) {
        Action newaction = action.clone();
        if (action.id == IDEActions.FileNewDirectory) {
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
}