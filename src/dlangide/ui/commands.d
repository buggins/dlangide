module dlangide.ui.commands;

import dlangui.core.events;

enum IDEActions : int {
    None = 0,
    ProjectOpen = 1010000,
    FileOpen,
    FileClose,
    FileExit,
    EditCopy = 1011000,
    EditPaste,
    EditCut,
    EditUndo,
    EditRedo,
}

