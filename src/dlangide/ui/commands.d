module dlangide.ui.commands;

public import dlangui.core.events;
import dlangui.widgets.editors;

enum IDEActions : int {
    None = 0,
    ProjectOpen = 1010000,
    FileNew,
    FileOpen,
    FileSave,
    FileClose,
    FileExit,
    BuildWorkspace,
    RebuildWorkspace,
    CleanWorkspace,
    BuildProject,
    RebuildProject,
    CleanProject,
    SetStartupProject,
    ProjectSettings,
    DebugStart,
    DebugStartNoDebug,
    DebugContinue,
    DebugStop,
    DebugPause,
    HelpAbout,
}

const Action ACTION_FILE_NEW = new Action(IDEActions.FileOpen, "MENU_FILE_NEW"c, "document-new", KeyCode.KEY_N, KeyFlag.Control);
const Action ACTION_FILE_OPEN = new Action(IDEActions.FileOpen, "MENU_FILE_OPEN"c, "document-open", KeyCode.KEY_O, KeyFlag.Control);
const Action ACTION_FILE_SAVE = new Action(IDEActions.FileSave, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control);
const Action ACTION_FILE_EXIT = new Action(IDEActions.FileExit, "MENU_FILE_EXIT"c, "document-close"c, KeyCode.KEY_X, KeyFlag.Alt);
const Action ACTION_WORKSPACE_BUILD = new Action(IDEActions.BuildWorkspace, "MENU_BUILD_WORKSPACE_BUILD"c);
const Action ACTION_WORKSPACE_REBUILD = new Action(IDEActions.RebuildWorkspace, "MENU_BUILD_WORKSPACE_REBUILD"c);
const Action ACTION_WORKSPACE_CLEAN = new Action(IDEActions.CleanWorkspace, "MENU_BUILD_WORKSPACE_CLEAN"c);
const Action ACTION_PROJECT_BUILD = new Action(IDEActions.BuildProject, "MENU_BUILD_PROJECT_BUILD"c, null, KeyCode.F7, 0);
const Action ACTION_PROJECT_REBUILD = new Action(IDEActions.RebuildProject, "MENU_BUILD_PROJECT_REBUILD"c, null, KeyCode.F7, KeyFlag.Control);
const Action ACTION_PROJECT_CLEAN = new Action(IDEActions.CleanProject, "MENU_BUILD_PROJECT_CLEAN"c, null);
const Action ACTION_PROJECT_SET_STARTUP = new Action(IDEActions.SetStartupProject, "MENU_PROJECT_SET_AS_STARTUP"c, null);
const Action ACTION_PROJECT_SETTINGS = new Action(IDEActions.ProjectSettings, "MENU_PROJECT_SETTINGS"c, null);
const Action ACTION_DEBUG_START = new Action(IDEActions.DebugStart, "MENU_DEBUG_START_DEBUGGING"c, "debug-run"c, KeyCode.F5, 0);
const Action ACTION_DEBUG_START_NO_DEBUG = new Action(IDEActions.DebugStartNoDebug, "MENU_DEBUG_START_NO_DEBUGGING"c, null, KeyCode.F5, KeyFlag.Control);
const Action ACTION_DEBUG_CONTINUE = new Action(IDEActions.DebugContinue, "MENU_DEBUG_CONTINUE"c);
const Action ACTION_DEBUG_STOP = new Action(IDEActions.DebugStop, "MENU_DEBUG_STOP"c);
const Action ACTION_DEBUG_PAUSE = new Action(IDEActions.DebugPause, "MENU_DEBUG_PAUSE"c);
const Action ACTION_EDIT_COPY = new Action(EditorActions.Copy, "MENU_EDIT_COPY"c, "edit-copy"c, KeyCode.KEY_C, KeyFlag.Control);
const Action ACTION_EDIT_PASTE = new Action(EditorActions.Paste, "MENU_EDIT_PASTE"c, "edit-paste"c, KeyCode.KEY_V, KeyFlag.Control);
const Action ACTION_EDIT_CUT = new Action(EditorActions.Cut, "MENU_EDIT_CUT"c, "edit-cut"c, KeyCode.KEY_X, KeyFlag.Control);
const Action ACTION_EDIT_UNDO = new Action(EditorActions.Undo, "MENU_EDIT_UNDO"c, "edit-undo"c, KeyCode.KEY_Z, KeyFlag.Control);
const Action ACTION_EDIT_REDO = new Action(EditorActions.Redo, "MENU_EDIT_REDO"c, "edit-redo"c, KeyCode.KEY_Z, KeyFlag.Control|KeyFlag.Shift);
const Action ACTION_HELP_ABOUT = new Action(IDEActions.HelpAbout, "MENU_HELP_ABOUT"c);
