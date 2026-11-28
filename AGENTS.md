# AGENTS.md — DlangIDE

Notes for AI agents and contributors working on this repository.

**Development environment.** The environment notes here come from a Windows host with WSL2 (Ubuntu): Linux builds and
tests run in WSL, Windows builds and GUI checks run on the host from the same shell (see dlangui's AGENTS.md). Notes
for other setups (pure Linux, macOS) may be added later. Machine-specific details (paths, helper scripts) belong in an
untracked `AGENTS.local.md`; maintainers may also keep local work notes (`PLAN.md`) out of git.

## Project overview

DlangIDE is a cross-platform IDE for the D programming language. Its GUI is built with **DlangUI**, whose sources
live in the sibling directory `../dlangui` (see `../dlangui/AGENTS.md` for the DlangUI API).

- Author: Vadim Lopatin (`buggins`). Repository: https://github.com/buggins/dlangide. License: Boost 1.0.
- GitHub collaborators: `dmi7ry`, `shiche`, `GrimMaple`, `and3md` (plus owner `buggins`).
  GrimMaple did the most recent maintenance (2023: dlangui 0.10.3 port, DCD bump, logger fix).
- Maintained again since Nov 2026 (releases v0.9.0 to v0.11.2); before that mostly dormant from early 2024.
  Issue #437 (2026-08) asks about a new maintainer, or moving the repo to the `dlang-supplemental` org.
- Current version: **v0.11.2** (tagged 2026-11-27 on 60a6733, annotated tag, release issue #619, PR #620; v0.11.1 on 9da19c3; v0.11.0 2026-11-25 on 09ada5b; v0.10.0 2026-11-22, v0.9.0 2026-11-09).
  Old tag `v0.8.19` (`94ee171`, 2024-03-12) is not on `master` (only a dlangui dependency bump).
- Release process: an issue with the notes and a PR bumping `views/VERSION` (no trailing newline); after the merge an
  annotated tag `vX.Y.Z` (message `vX.Y.Z`) on the merge commit, then `gh release create vX.Y.Z --verify-tag
  --title vX.Y.Z --notes-file ...`. Publishing starts `package-windows.yml`, which attaches the Windows .zip files and
  installers (x86_64, x86). code.dlang.org picks up the tag through the webhook.

Features:
- DUB projects (`dub.json`, `dub.sdl`, `package.json`) and multi-project workspaces (`*.dlangidews`)
- Multi-tab source editor with D, JSON and DML syntax highlighting, smart indent, and line/block comment toggling
- Build, run, clean, rebuild and upgrade through DUB, with compiler log navigation
- DCD-based autocompletion, go-to-definition and doc comments on hover. DCD is embedded as a library, not run as a separate process.
- GDB/MI-based debugger: breakpoints, stack, locals and watch panels. mago-mi on Windows.
- New project, file and folder wizards
- Search in files
- DMD `-profile` `trace.log` viewer
- Settings dialogs and configurable keyboard shortcuts
- Light, dark and console themes. Runs in text-mode consoles with the `console` config.

## Workflow

- **Every change needs a GitHub Issue and a Pull Request.** This is the same rule as in dlangui. Never commit directly to `master`.
  1. Create an issue with `gh issue create`, or reuse an existing one.
  2. Work on a feature branch.
  3. Open a PR into `master` that references the issue (`Fixes #N`).
- **Code review before each commit.** AI agents run a code review (Claude Code: `/code-review medium`) on the
  pending changes before committing. If it reports findings that should be fixed, list them for the user (with your verdict: confirmed or
  not, fix now or separate issue) and ask which ones to apply before committing. Findings left for later get their
  own issues. Fixes for bugs found while testing something else also get their own issue and PR.
- PRs are created as drafts. Changes made with an AI agent say so: commit messages end with a `Co-Authored-By:`
  line for the agent, PR bodies with a "Generated with" line.
- CI: GitHub Actions (`.github/workflows/ci.yml`, #439, extended in #443). 9 build jobs: {ubuntu, windows} × {dmd-latest, ldc-latest},
  ubuntu dmd-2.100.2, ubuntu-24.04 ldc-1.30.0 / ldc-1.36.0 (old LDC binaries need libxml2.so.2, missing on
  ubuntu-latest = 26.04), windows dmd-2.100.2, macos ldc-latest; plus a `dscanner` job (`dscanner.ini`, #530, fails
  on any warning) and `package-windows.yml` (x86 and x86_64 packages). DUB packages cached (like dlangui).
  Repo setting since 2026-11-08: PR branches are deleted automatically on merge.
  Steps: `dub test`, `dub build`, `dub build -c console`, `dub build -c freetype` on Windows, `dub build -c x11` on Linux.
- Code style follows DlangUI's `CODING_STYLE.md` (D Style, 4 spaces, `_camelCase` private fields).
- Safer D practices for new and changed code (#627, as in dlangui's AGENTS.md; adapted from
  [camunda/safer-d](https://github.com/camunda/safer-d), whose checker and no-null style don't fit DlangUI's class-based
  API):
  - Never catch `Throwable` or `Error` (an assert, a range error, out of memory: the program is broken), except in an
    entry point's last-resort handler (DlangUI's backends have them in `DLANGUImain`/`DLANGUIWinMain`). A
    `catch (Exception)` that swallows the exception says why in a comment.
  - A `switch` over an enum whose value is always exactly one member, set by our own code, is a `final switch`: list
    the members it skips as empty cases instead of `default:`, so a new member breaks the build wherever it needs
    handling. Flag sets (`State`, `KeyFlag`, `WindowFlag`) and values from the OS, files or casts (key codes) keep
    `default:`: a `final switch` on a value that matches no member throws `SwitchError`, or is undefined in release
    builds.
  - `size_t` subtraction wraps (`0 - 1` is huge): compare before subtracting lengths, offsets and indices, or compute
    in `ptrdiff_t`; keep the comparison and the subtraction together, so an edit can't flip one side.
  - Test-only imports go into the `unittest` block or the test helper that uses them, not into a module-level
    `version (unittest)` block: non-test code that uses such an import passes `dub test` and breaks the release build.
  - A comment directly above every `@trusted` says why it is safe.
- `AGENTS.md` is tracked (since 2026-11-28; untracked before). `AGENTS.local.md` and `PLAN.md` are local files
  (`.git/info/exclude`): never commit them.

## Building and testing

```sh
dub build                 # -> bin/dlangide  (config "default": SDL2 + OpenGL on posix, Win32 on Windows)
dub build -c x11          # other configs: minimal, console, x11 (passed through to dlangui subConfigurations)
dub test                  # unittests -> bin/dlangide-test-default
dub run -- path/to/workspace.dlangidews   # first CLI arg opens a workspace or dub.json
```

Baseline on 2026-11-28 with LDC 1.36.0 and DUB 1.36.0 on Linux (WSL2):

| Command | Result |
|---|---|
| `dub build` | OK, no deprecation warnings (the DlangIDE sources have none since #439) |
| `dub test` | OK, "12 modules passed unittests" |

Dependencies (`dub.json`):
- `dlangui`: a version dependency from code.dlang.org, `"~>0.25.1"` (#623, PR #624, 2026-11-28; `~>0.25.0` since #621; `~>0.24.0` since #617; `~>0.23.0` since #610, PR #612; `~>0.22.0` since #594, PR #595), also in
  `workspaces/tetris/dub.json`, `windows/makeicon.d` and the "DlangUI: hello world app" new-project template
  (`DUB_JSON_DLANGUI_HELLOWORLD` in `src/dlangide/ui/newproject.d`; it sat at `~>0.13.1` until PR #595). Before, it
  was a git dependency pinned to a release commit (#551 v0.19.0, #563 v0.20.0, #573 v0.21.0, #582 v0.21.1), because code.dlang.org listed only dlangui 0.13.1 until
  2026-11-24. For the next dlangui release, raise the range in those four places once code.dlang.org lists it.
  A local `dub.selections.json` (gitignored) can point dlangui to `{"path": "../dlangui"}`, so the IDE builds against
  the dlangui checkout (the path selection wins over the version range); CI fetches the release from code.dlang.org.
- `dcd ~>0.16.0-beta.1` (selected 0.16.9). This brings in `dsymbol`, `libdparse` 0.25.1, `msgpack-d` and `emsi_containers`.
- Version identifiers:
  - `EmbedStandardResources` (all platforms)
  - `freetype` configuration (#519): `USE_FREETYPE` on Windows. Until #519 it was set for every Windows build, but FreeType never loaded (dlangui #825, fixed by dlangui PR #826), so Windows always used Win32 GDI fonts.
  - Versions set in DlangIDE's recipe (top level or configuration) DO reach dlangui's compile, and dlangui's versions (`USE_OPENGL`, `USE_SDL`, ...) reach DlangIDE's. `dub describe` per-package `versions` shows only each recipe's own; use `dub describe --data=versions --data-list` or `dub build -v`.
- Linux links `libz`. On Windows, `libs/windows/x86/mago-mi.exe` is copied next to the binary.

**Building against a local dlangui checkout.** By default, changes in `../dlangui` are **not** used (the dlangui release from code.dlang.org is). To build against them, do one of the following:
- Add `"dlangui": {"path": "../dlangui"}` to `dub.selections.json`. The file is gitignored, so this stays local.
- Run `dub add-override dlangui "~>0.25" ../dlangui` (the range must match `dub.json`).
- Run `dub add-local ../dlangui`.

Remove the override afterwards to get back to builds of the dlangui release.

**Worktrees** (the main checkout may be on someone's branch; work in `git worktree add <temp dir> origin/master`):
copy `dub.selections.json` into the worktree and make the dlangui path absolute (`"path": "/<path to>/dlangui"`),
or it points to a `../dlangui` next to the worktree.

**Windows GUI tests** (see dlangui's AGENTS.md "Windows checks" for the posted-input helper and its limits):
- `git pull` the Windows checkouts of dlangide and dlangui first; the Windows `dub.selections.json` points dlangui to
  `<win-work>/dlangui`. Check that the build succeeded (a failed build leaves the old exe). Start with
  `Start-Process -FilePath <win-work>\dlangide\bin\dlangide.exe -WorkingDirectory <win-work>\dlangide\bin
  -ArgumentList <workspace>.dlangidews`; the window title is `<workspace name> - DLangIDE`.
- Test workspace: a copy of `workspaces/tetris` outside the repo. Write its `.wssettings` so that it opens only the
  files the test needs (screenshots show the editors' text). Back up and restore `%APPDATA%\.dlangide\settings.json`
  (the recent workspaces change) and the workspace settings.
- Scenarios with changes by other programs (`git checkout`): copy the workspace to a temporary folder, `git init` it with
  two branches (`.gitignore` the `.wssettings` and `tetris.settings`), check out each branch once before starting the
  IDE (autocrlf rewrites the files on the first checkout), delete the folder afterwards.
- Menus work with posted clicks: Workspace refresh is Project > Refresh workspace items (Ctrl+R can't be sent),
  save is File > Save file, close is Window > Close document; the close dialogs take Enter (Save) and Tab.

Runtime requirements:
- SDL2, FreeType, fontconfig and OpenGL shared libraries (posix default config)
- `dub` and a D compiler (dmd, ldc2 or gdc) on `PATH` to build projects
- `gdb` (or `lldb-mi`, or `mago-mi` on Windows) for debugging
- `rdmd` for "run current file with rdmd"

## Repository layout

```
dub.json                 executable "dlangide" -> bin/; configs default/minimal/console/x11
src/dlangide.d           module app: APP_ENTRY_POINT + UIAppMain (font/hinting setup, theme, creates IDEFrame, opens CLI workspace or home screen)
src/dlangide/
  ui/                    GUI: main frame, panels, dialogs, editor widget
  workspace/             workspace/project model, DUB project parsing, settings files
  builders/              DUB build runner, external process wrapper
  tools/                 editor tools: DCD interface, D syntax support, dmd trace parser, (disabled) libdparse parser
src/ddebug/              debugger abstraction + GDB/MI implementation (independent of dlangide.*, uses dlangui logger)
src/ddc/lexer/           old hand-written D tokenizer/lexer (used by syntax highlighting / smart indent)
views/
  VERSION                version string (`v0.11.2`), bumped by hand before tagging
  resources.list, console_resources.list   resources embedded in the executable
  res/                   ide_theme_default.xml, ide_theme_dark.xml, console_ide_theme_*.xml, mdpi/ + hdpi/ icons,
                         i18n/{en,ru,de,es,cs}.ini
                         dlangide-logo.32x32.svg: app logo (window icon via windowIconId, dialogs, #560)
windows/                 dlangide.ico + dlangide.res (exe icon, sourceFiles-windows), generated from the SVG logo by
                         `dub run --single windows/makeicon.d`; package.ps1 + dlangide.iss: CI packaging (zip, Inno Setup installer)
workspaces/              sample workspaces: sample1 (2 projects), tetris; rdmd test files
tools/disowntty/         helper used to run debuggee in an external terminal (GDB on posix)
libs/windows/x86/        mago-mi.exe (Windows debugger)
lib/win32/               old FreeImage.dll / SDL2.dll (legacy)
*.dproj, *.sln, *.visualdproj   stale Mono-D / VisualD project files (the old root dlangide.iss was removed in #577)
```

## Architecture

### Startup (`src/dlangide.d`)

1. Set up the DCD logger: `dcd.log` in debug builds, `NullLogger` in release.
2. Embed resources from `views/resources.list`.
3. Set `Platform.instance.uiTheme = "ide_theme_default"`.
4. Tune `FontManager`: hinting, gamma, subpixel rendering. The settings depend on `USE_OPENGL` / `USE_FREETYPE` (both visible from dlangui).
5. Create a 900×730 window and an `IDEFrame(window)`.
6. Open the workspace given as the first CLI argument, or show the home screen.
7. Call `window.show()`, then `frame.restoreUIStateOnStartup()`, then enter the message loop.

### UI (`src/dlangide/ui/`)

`frame.d` (the largest UI module) defines **`IDEFrame : AppFrame`**, the central controller.
- Builds the main menu, toolbars, dock panels and the editor `TabWidget`.
- Handles all `IDEActions` in `handleAction` / `handleActionStateRequest`.
- Owns the current `Workspace`, the `IDESettings` and the build, run and debug execution.
- Keeps the caret history (`CaretHistory`).
- Uses `executeInUiThread` to bring callbacks from background threads (builder, DCD, debugger) back to the UI thread.

Other modules:

| Module | Contents |
|---|---|
| `commands.d` | `enum IDEActions` + `Action` constants (`ACTION_FILE_OPEN_WORKSPACE`, …). Shortcuts are customizable through AppFrame's `shortcuts.json`. |
| `dsourceedit.d` | `DSourceEdit : SourceEdit`: D editor with breakpoints, bookmarks, completion popup (`CompletionPopupMenu`), tooltip docs |
| `wspanel.d` | `WorkspacePanel : DockWindow`: project tree (`TreeWidget`) |
| `outputpanel.d` | `OutputPanel : DockWindow`: tabs with `CompilerLogWidget` (clickable errors), search results, and on posix only (`ENABLE_INTERNAL_TERMINAL`) the internal terminal |
| `terminal.d` | `TerminalWidget` + `TerminalDevice` (pty-based VT emulation for program/debuggee I/O, posix) |
| `searchPanel.d` | `SearchWidget`: find in files |
| `debuggerui.d` | `DebuggerUIHandler`: links the debugger callbacks to the UI (current line, stack, locals, breakpoints) |
| `stackpanel.d`, `watchpanel.d` | Debugger stack and variables dock windows (`StringGridWidget`) |
| `homescreen.d` | Start page (recent workspaces, links) |
| `newproject.d`, `newfile.d`, `newfolder.d` | Wizards. Project templates: hello world app, DlangUI hello world, vibe.d hello world, empty app, empty library. Sources are embedded as D string literals. |
| `settings.d` | Builds the `SettingsDialog` pages for the IDE and project settings |
| `dmdprofilerview.d` | Viewer for DMD `-profile` `trace.log` (grid of functions, callers and callees) |

Files changed by other programs (#621/#622, #623/#624; dlangui's external change handling, see its AGENTS.md
"Files and external changes"):
- Preferences > Editors > Text Editors: `editors/textEditor/externalChanges` (`reload` = default, `notify`, `ignore`;
  `IDESettings.externalChangeMode`) and `atomicSave`, applied in `DSourceEdit.applySettings()`.
- Every user save goes through `DSourceEdit.saveChecked(afterSaveQuestion)` / `IDEFrame.saveDocument()`: File > Save,
  Save all, Save As to the same file, Save in the close-tab / close-workspace / exit dialogs (`saveAllAndClose()`).
  If the file changed on disk, the editor asks Overwrite / Reload / Cancel; the continuation (close, exit) runs,
  posted, after Overwrite (saved) or Reload, and is dropped on any other answer, an edit, or when the question is
  replaced because the file changed again.
- A deleted file shows dlangui's bar (Save / Keep) plus Close (`ACTION_CLOSE_DELETED_FILE`); Close posts
  `onTabClose`, because closing the tab destroys the bar that handles the click. The "kept open with unsaved changes"
  log line comes from `DSourceEdit.deletedFileKeptOpen` when that bar first appears.
- Workspace > Refresh (`closeRemovedDocuments`) checks all open editors and closes tabs of deleted files without
  unsaved changes, unless the user chose Keep (in `ignore` mode: whenever the file is missing).
- Bar Save / Overwrite: `DSourceEdit.saveAfterExternalChange()` calls `SourceEdit.save(fn)`, so a failure shows the
  bar's error only (this class's `save(fn)` would add a message box).

### Workspace model (`src/dlangide/workspace/`)

- `workspace.d`: `Workspace`.
  - Loads and saves the `*.dlangidews` JSON file (name, description, `projects` map name → `dub.json` path, `includePath`).
  - Picks the startup project.
  - Keeps the breakpoints and bookmarks.
  - Defines `BuildOperation` (Build, Clean, Rebuild, Run, Upgrade) and `BuildConfiguration` (Debug, Release, Unittest).
- `project.d`: `Project`, `ProjectFolder`, `ProjectSourceFile`.
  - Reads `dub.json` / `dub.sdl`: configurations, source and import paths, dependencies.
  - Resolves DUB dependencies (`DubPackageFinder`, `~/.dub/packages`) and shows them as dependency projects.
  - Collects compiler import paths by compiling a dummy file in `~/.dlangide` (`CompilerImportPathsCache`).
  - Defines `ProjectConfiguration` (executable or library).
- Settings files are JSON, built on `dlangui.core.settings.SettingsFile`:
  - `idesettings.d`, `IDESettings`: `<settingsDir>/settings.json`.
    Holds editor options (tabs, smart indents, font, auto-complete) and UI options (theme, language, `screenDpiOverride`, hinting, UI font, toolbar/statusbar).
    Also holds the executables for dub, rdmd, the debugger and the terminal (default `xterm`), the toolchains dmd/ldc2/ldmd2/gdc
    (each with `dub_additional_params`), and recent workspaces.
  - `workspacesettings.d`, `WorkspaceSettings`: `<workspace>.wssettings`, next to the `.dlangidews` file (gitignored in user projects).
    Holds the open files, breakpoints, bookmarks and startup project.
  - `projectsettings.d`, `ProjectSettings`: `<project>.settings`. Holds the build and run options (arguments, working dir, external terminal).
- `settingsDir` is `AppFrame.settingsDir` from dlangui, which is `appDataPath(".dlangide")`:
  - Linux and macOS: `~/.dlangide/`
  - Windows: `%APPDATA%\.dlangide\`

  It contains `settings.json` and `shortcuts.json`.

### Build and run (`src/dlangide/builders/`)

- `builder.d`: `Builder : BackgroundOperationWatcher`. Runs `dub` in the project dir:
  - Build/Rebuild: `build [--force] [--arch=] [--compiler=] --build-mode=allAtOnce`
  - Run: `run`, or `test` for library projects
  - Clean: `clean`
  - Upgrade: `upgrade --force-remove`, which first deletes `dub.selections.json`
  - Most operations also get `--build=debug|release|unittest` and `--config=<name>` when it isn't the default config.
  - Output streams to the `OutputPanel` log.
- `extprocess.d`: `ExternalProcess` plus background reader threads. It is a custom process wrapper that predates `std.process.pipeProcess` use.

Program execution without the debugger: `ddebug/common/nodebug.d`, `ProgramExecutionNoDebug`.
It runs in the internal terminal on posix, or in an external terminal (`terminal/executable` setting, default `xterm`).
`tools/disowntty` helps with that.

### Debugger (`src/ddebug/`)

- `common/debugger.d`:
  - `Debugger` interface and `DebuggerCallback`.
  - `DebuggerProxy`: marshals calls to the debugger thread, and callbacks back to the UI through `executeInUiThread`.
  - `DebuggerBase : Thread`.
  - Data types: `Breakpoint`, `DebugFrame`, `DebugThread`, `DebugVariable`, …
- `gdb/gdbinterface.d`: `GDBInterface : ConsoleDebuggerInterface`. Drives `gdb --interpreter=mi` (works with any MI-compatible
  debugger: gdb, lldb-mi, mago-mi). The executable comes from `IDESettings.debuggerExecutable`: `gdb` by default, `mago-mi` on Windows.
- `gdb/gdbmiparser.d`: GDB/MI output parser (`MIValue` tree).
- The frame always creates a `GDBInterface` (in `frame.d`). There is no Windows-native debugger. Old `USE_WIN_DEBUG` code is commented out.

### D language tooling (`src/dlangide/tools/`)

- `editortool.d`: `EditorTool` abstraction (go to definition, completions, doc comments). `DefaultEditorTool` is the no-op version.
- `d/deditortool.d`: `DEditorTool`, which routes requests to DCD.
- `d/dcdinterface.d`: `DCDInterface : Thread`.
  - Runs DCD **in-process**: `dcd.server.autocomplete`, `dsymbol.modulecache`.
  - Requests are tasks on a queue: `ModuleCacheWarmupTask`, `GetCompletionsTask`, `GoToDefinitionTask`, `DocCommentsTask`.
  - Results are posted back to the UI thread.
  - Import paths come from the project, its dependencies, the compiler, and the workspace `includePath`.
- `d/dsyntax.d`: `SimpleDSyntaxSupport : SyntaxSupport`. Token highlighting, bracket matching, smart indent, comment toggling. Uses `ddc.lexer.tokenizer`.
- `d/dparser.d`: libdparse-based module parser. Compiled only with `version(USE_LIBDPARSE)`, which is off by default.
- `d/dmdtrace.d`: parser for DMD `trace.log` (profiler), run as a background operation.

## Cross-platform notes

- **Linux**: default SDL2 + OpenGL + FreeType backend, or `-c x11`. Internal terminal available. Debugging with gdb.
- **Windows**: Win32 backend with Win32 GDI fonts; FreeType with `-c freetype` (`libfreetype-6.dll` is always copied to `bin` by dlangui's copyFiles). Programs run in the Output panel via ConPTY (#509) or an external console. Debugging with mago-mi (bundled, x86) or gdb. Old DMD OPTILINK issues mean `--arch=x86_mscoff` or `x86_64` is recommended.
- **macOS**: SDL2 backend (`brew install sdl2`). Debugging with gdb or lldb-mi. Untested recently (open issues #434, #435).
- **Console** (`-c console`): runs in a text terminal with the console themes. Many features are limited.

## Known issues and gotchas
- `version (Windows)` code is compiled only on Windows: build and test it there too (see dlangui's AGENTS.md,
  "Windows checks"; the Windows checkouts have CRLF line endings). macOS is covered only by CI.
- Testing dlangui changes in the IDE: point `dub.selections.json` at `../dlangui` (see above), and check the exit log
  for leak reports ("Non-zero ... instance count") after closing the IDE.

- i18n: `views/res/i18n/<lang>.ini` is loaded after dlangui's `std_<lang>.ini` and overrides the same keys. dlangui
  ships en/ru/pl only, so es/cs/de here also carry translations of dlangui's external change strings and of
  `ACTION_SAVE`/`ACTION_CLOSE`/`ACTION_IGNORE`/`ACTION_CANCEL`; add new dlangui UI strings there when dlangui adds some.
  en/ru/de have the settings page strings; es/cs are partial (English fallback).
- By default the IDE builds against the **dlangui release from code.dlang.org** (`~>0.25.1`, #623), not `../dlangui`. Use a path override when testing dlangui changes.
- The `libs-windows` gdi32/user32 workaround (#439) is removed in #449: dlangui 0.11 links them itself (buggins/dlangui#711).
- `src/dlangide.d` has a lot of commented-out test code (`USE_WIN_DEBUG`, `USE_GDB_DEBUG`, lldb tests).
- A debug build writes `dcd.log` to the current directory. It is gitignored as `*.log`.
- The `ddc/lexer` tokenizer duplicates functionality now available in libdparse and dlangui (`dmlhighlight`).
- The Mono-D, VisualD and Inno Setup project files are stale.
