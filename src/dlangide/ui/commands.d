module dlangide.ui.commands;

enum IDEActions : int {
    None = 0,
    FileOpen = 10000,
    FileClose,
    FileExit,
    EditCopy = 11000,
    EditPaste,
    EditCut,
    EditUndo,
    EditRedo,
}

