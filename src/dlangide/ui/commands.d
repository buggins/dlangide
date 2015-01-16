module dlangide.ui.commands;

import dlangui.core.events;

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
    EditCopy = 1011000,
    EditPaste,
    EditCut,
    EditUndo,
    EditRedo,
}

__gshared Action ACTION_FILE_OPEN;
__gshared Action ACTION_FILE_SAVE;
__gshared Action ACTION_FILE_EXIT;
__gshared static this() {
    ACTION_FILE_OPEN = new Action(IDEActions.FileOpen, "MENU_FILE_OPEN"c, "document-open", KeyCode.KEY_O, KeyFlag.Control);
    ACTION_FILE_SAVE = new Action(IDEActions.FileSave, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control);
    ACTION_FILE_EXIT = new Action(IDEActions.FileExit, "MENU_FILE_EXIT"c, "document-close"c, KeyCode.KEY_X, KeyFlag.Alt);
}
