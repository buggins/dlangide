module dlangide.ui.commands;

import dlangui.core.events;
import dlangui.widgets.editors;

enum : int {
    ACTION_HELP_ABOUT = 5500,
}

enum IDEActions : int {
    None = 0,
    ProjectOpen = 1010000,
    FileNew,
    FileOpen,
    FileSave,
    FileClose,
    FileExit,
}

__gshared Action ACTION_FILE_NEW = new Action(IDEActions.FileOpen, "MENU_FILE_NEW"c, "document-new", KeyCode.KEY_N, KeyFlag.Control);
__gshared Action ACTION_FILE_OPEN = new Action(IDEActions.FileOpen, "MENU_FILE_OPEN"c, "document-open", KeyCode.KEY_O, KeyFlag.Control);
__gshared Action ACTION_FILE_SAVE = new Action(IDEActions.FileSave, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control);
__gshared Action ACTION_FILE_EXIT = new Action(IDEActions.FileExit, "MENU_FILE_EXIT"c, "document-close"c, KeyCode.KEY_X, KeyFlag.Alt);
__gshared Action ACTION_EDIT_COPY = new Action(EditorActions.Copy, "Copy"d, "edit-copy"c, KeyCode.KEY_C, KeyFlag.Control);
__gshared Action ACTION_EDIT_PASTE = new Action(EditorActions.Copy, "Paste"d, "edit-paste"c, KeyCode.KEY_V, KeyFlag.Control);
__gshared Action ACTION_EDIT_CUT = new Action(EditorActions.Copy, "Cut"d, "edit-cut"c, KeyCode.KEY_X, KeyFlag.Control);
__gshared Action ACTION_EDIT_UNDO = new Action(EditorActions.Undo, "Undo"d, "edit-undo"c, KeyCode.KEY_Z, KeyFlag.Control);
__gshared Action ACTION_EDIT_REDO = new Action(EditorActions.Redo, "Redo"d, "edit-redo"c, KeyCode.KEY_Z, KeyFlag.Control|KeyFlag.Shift);
