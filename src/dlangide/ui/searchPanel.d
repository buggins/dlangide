module dlangide.ui.searchPanel;


import dlangui;

import dlangide.ui.frame;
import dlangide.ui.wspanel;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.string;
import std.conv;

// parallel search is disabled to fix #178
//version = PARALLEL_SEARCH;

interface SearchResultClickHandler {
    bool onSearchResultClick(int line);
}

//LogWidget with highlighting for search results.
class SearchLogWidget : LogWidget {

    //Sends which line was clicked.
    Signal!SearchResultClickHandler searchResultClickHandler;

    this(string ID){
        super(ID);
        scrollLock = false;
        onThemeChanged();
    }

    protected uint _filenameColor = 0x0000C0;
    protected uint _errorColor = 0xFF0000;
    protected uint _warningColor = 0x606000;
    protected uint _deprecationColor = 0x802040;
    // characters of the line being drawn that are part of a match, reused between lines
    protected bool[] _matchMask;

    /// handle theme change: e.g. reload some themed resources
    override void onThemeChanged() {
        super.onThemeChanged();
        _filenameColor = style.customColor("build_log_filename_color", 0x0000C0);
        _errorColor = style.customColor("build_log_error_color", 0xFF0000);
        _warningColor = style.customColor("build_log_warning_color", 0x606000);
        _deprecationColor = style.customColor("build_log_deprecation_color", 0x802040);
    }

    override protected CustomCharProps[] handleCustomLineHighlight(int line, dstring txt, ref CustomCharProps[] buf) {
        uint defColor = textColor;
        uint flags = 0;
        if (buf.length < txt.length)
            buf.length = txt.length;
            
        //Highlights the filename
        if(txt.startsWith("Matches in ")) {
            CustomCharProps[] colors = buf[0..txt.length];
            uint cl = defColor;
            flags = 0;
            for (int i = 0; i < txt.length; i++) {
                if(i == 11) {
                    cl = _filenameColor;
                    flags = TextFlag.Underline;
                }
                colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
        } else { //Highlight line and column
            CustomCharProps[] colors = buf[0..txt.length];
            uint cl = _filenameColor;
            flags = 0;
            bool textStarted = false;
            // the matches in the line text after "]", found with the options of the search (#260)
            if (_matchMask.length < txt.length)
                _matchMask.length = txt.length;
            bool[] mask = _matchMask[0 .. txt.length];
            mask[] = false;
            immutable ptrdiff_t textStart = txt.indexOf(']') + 1;
            if (textStart > 0 && _textToHighlight.length) {
                forEachLineMatch(txt[textStart .. $], 0, _textToHighlight,
                        (_textToHighlightOptions & TextSearchFlag.CaseSensitive) != 0,
                        (_textToHighlightOptions & TextSearchFlag.WholeWords) != 0, (TextRange r) {
                    mask[textStart + r.start.pos .. textStart + r.end.pos] = true;
                });
            }
            for (int i = 0; i < txt.length; i++) {
                dstring rest = txt[i..$];
                if (rest.startsWith(" -->"d)) {
                    cl = _warningColor;
                    flags = 0;
                }
                if(i == 4) {
                    cl = _errorColor;
                }

                if (textStarted && _textToHighlight.length > 0) {
                    if (mask[i]) {
                        flags = TextFlag.Underline;
                        cl = _deprecationColor;
                    } else {
                        flags = 0;
                        cl = defColor;
                    }
                }

                colors[i].color = cl;
                colors[i].textFlags = flags;

                //Colors to apply in following iterations of the loop.
                if(!textStarted && rest.startsWith("]")) {
                    cl = defColor;
                    flags = 0;
                    textStarted = true;
                }
            }
            return colors;
        }
    }
    
    override bool onMouseEvent(MouseEvent event) {
        bool res = super.onMouseEvent(event);
        if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
            int line = _caretPos.line;
            if (searchResultClickHandler.assigned) {
                searchResultClickHandler(line);
                return true;
            }
        }
        return res;
    }
    
    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.RETURN) {
            int line = _caretPos.line;
            if (searchResultClickHandler.assigned) {
                searchResultClickHandler(line);
                return true;
            }
        }
        return super.onKeyEvent(event);
    }
}


struct SearchMatch {
    int line;
    long col;
    dstring lineContent;
}

struct SearchMatchList {
    string filename;
    SearchMatch[] matches;
}

/// Search In Files panel: a tab of the log panel. Not a TabWidget: it removed the tab parts, and since dlangui 0.13
/// TabWidget.addChild() added the panel's children through the destroyed tab control (#549, buggins/dlangui#1016)
class SearchWidget : VerticalLayout {
    HorizontalLayout _layout;
    EditLine _findText;
    SearchLogWidget _resultLog;
    int _resultLogMatchIndex;
    ComboBox _searchScope;
    ImageCheckButton _cbCaseSensitive;
    ImageCheckButton _cbWholeWords;

    protected IDEFrame _frame;
    protected SearchMatchList[] _matchedList;
    // text and options of the last search: a click on a result highlights its matches (#260)
    protected dstring _searchedText;
    protected uint _searchedFlags;
    // the text of the files open in editors, by file name, for the running search: unsaved edits are searched (#611)
    protected const(dstring)[][string] _openFileLines;

    //Sets focus on result;
    void focus() {
        _findText.setFocus();
        _findText.handleAction(new Action(EditorActions.SelectAll));
    }
    bool onFindButtonPressed(Widget source) {
        dstring txt = _findText.text;
        if (txt.length > 0) {
            findText(txt);
            _resultLog.setFocus();
        }
        return true;
    }
    
    public void setSearchText(dstring txt){
        _findText.text = txt;
    }

    this(string ID, IDEFrame frame) {
        super(ID);
        _frame = frame;
        // the look and focus behavior it had as a TabWidget
        styleId = STYLE_TAB_WIDGET;
        focusGroup = true;

        layoutHeight(FILL_PARENT);

        _layout = new HorizontalLayout();
        _layout.addChild(new TextWidget("FindLabel", "Find: "d));
        _layout.layoutWidth = FILL_PARENT;

        _findText = new EditLine();
        // 5,4,50,4 px at 100% in points, so it scales with the screen DPI (#547); console builds keep their values
        _findText.padding(WIDGET_STYLE_CONSOLE ? Rect(5, 4, 50, 4)
                : Rect(makePointSize(4), makePointSize(3), makePointSize(38), makePointSize(3)));
        _findText.layoutWidth = FILL_PARENT;
        // to handle Enter key press in editor
        _findText.enterKey = delegate (EditWidgetBase editor) {
            return onFindButtonPressed(this);
        };
        _layout.addChild(_findText);
        
        auto goButton = new ImageButton("findTextButton", "edit-find");
        goButton.click = &onFindButtonPressed;
        _layout.addChild(goButton);
        
        _layout.addChild(new HSpacer);

        _searchScope = new ComboBox("searchScope", ["File"d, "Project"d, "Dependencies"d, "Everywhere"d]);
        _searchScope.selectedItemIndex = 0;
        _layout.addChild(_searchScope);

        _cbCaseSensitive = new ImageCheckButton("cbCaseSensitive", "find_case_sensitive");
        _cbCaseSensitive.tooltipText = "EDIT_FIND_CASE_SENSITIVE";
        _cbCaseSensitive.styleId = "TOOLBAR_BUTTON";
        _cbCaseSensitive.checked = true;
        _layout.addChild(_cbCaseSensitive);

        _cbWholeWords = new ImageCheckButton("cbWholeWords", "find_whole_words");
        _cbWholeWords.tooltipText = "EDIT_FIND_WHOLE_WORDS";
        _cbWholeWords.styleId = "TOOLBAR_BUTTON";
        _layout.addChild(_cbWholeWords);

        addChild(_layout);

        _resultLog = new SearchLogWidget("SearchLogWidget");
        _resultLog.searchResultClickHandler = &onMatchClick;
        _resultLog.layoutHeight(FILL_PARENT);
        addChild(_resultLog);
    }
    
    //Recursively search for text in projectItem
    void searchInProject(ProjectItem project, dstring text, uint searchFlags) {
        if (project.isFolder == true) {
            ProjectFolder projFolder = cast(ProjectFolder) project;
            import std.parallelism;
            for (int i = 0; i < projFolder.childCount; i++) {
                version (PARALLEL_SEARCH)
                    taskPool.put(task(&searchInProject, projFolder.child(i), text, searchFlags));
                else
                    searchInProject(projFolder.child(i), text, searchFlags);
            }
        }
        else {
            Log.d("Searching in: " ~ project.filename);
            SearchMatchList match = findMatches(project.filename, text, searchFlags,
                    _openFileLines.get(project.filename, null));
            if(match.matches.length > 0) {
                synchronized {
                    _matchedList ~= match;
                    invalidate(); //Widget must updated with new matches
                }
            }
        }
    }
    
    bool findText(dstring source) {
        Log.d("Finding " ~ source);
        
        _resultLog.setTextToHighlight(""d, 0);
        _resultLog.text = ""d;

        if (currentWorkspace is null)
            return false;

        _matchedList = [];
        _resultLogMatchIndex = 0;
        // the Case sensitive and Whole words buttons (#260)
        immutable uint searchFlags = makeSearchFlags();
        _searchedText = source;
        _searchedFlags = searchFlags;
        _openFileLines = null;
        foreach (ed; _frame.allOpenedEditors)
            _openFileLines[ed.filename] = ed.content.lines;
        // the search runs here, synchronously (PARALLEL_SEARCH is off; its tasks would need their own copies of
        // the map and the lines): don't keep the editors' text after it
        scope (exit)
            _openFileLines = null;
        
        import std.parallelism; //for taskpool.
        
        switch (_searchScope.text) {
            case "File":
                if (_frame.currentEditor) {
                    SearchMatchList match = findMatches(_frame.currentEditor.filename, source, searchFlags,
                            _frame.currentEditor.content.lines);
                    if(match.matches.length > 0)
                        _matchedList ~= match;
                }
                break;
            case "Project":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                    if(!project.isDependency) {
                        version (PARALLEL_SEARCH)
                            taskPool.put(task(&searchInProject, project.items, source, searchFlags));
                        else
                            searchInProject(project.items, source, searchFlags);
                    }
               }
               break;
            case "Dependencies":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                    if(project.isDependency) {
                        version (PARALLEL_SEARCH)
                            taskPool.put(task(&searchInProject, project.items, source, searchFlags));
                        else
                            searchInProject(project.items, source, searchFlags);
                    }
               }
               break;
            case "Everywhere":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                   version (PARALLEL_SEARCH)
                       taskPool.put(task(&searchInProject, project.items, source, searchFlags));
                   else
                       searchInProject(project.items, source, searchFlags);
               }
               break;
            default:
                assert(0);
        }
        _resultLog.setTextToHighlight(source, searchFlags);
        return true;
    }
    
    override void onDraw(DrawBuf buf) {
        //Check if there are new matches to display
        if(_resultLogMatchIndex < _matchedList.length) {
            for(; _resultLogMatchIndex < _matchedList.length; _resultLogMatchIndex++) {
                SearchMatchList matchList = _matchedList[_resultLogMatchIndex];
                _resultLog.appendText("Matches in "d ~ to!dstring(matchList.filename) ~ '\n');
                foreach(SearchMatch match; matchList.matches) {
                    // line and column 1-based, as in the status bar, and a space before the text (#611)
                    _resultLog.appendText(" --> ["d ~ to!dstring(match.line+1) ~ ":"d ~ to!dstring(match.col+1) ~ "] " ~ match.lineContent ~"\n"d);
                }
            }
        }
        super.onDraw(buf);
    }

    void checkSearchMode() {
        if (!_frame.currentEditor && _searchScope.selectedItemIndex == 0)
            _searchScope.selectedItemIndex = 1;
    }

    uint makeSearchFlags() {
        uint res = 0;
        if (_cbCaseSensitive.checked)
            res |= TextSearchFlag.CaseSensitive;
        if (_cbWholeWords.checked)
            res |= TextSearchFlag.WholeWords;
        return res;
    }

    //Find the match/matchList that corrosponds to the line in _resultLog
    bool onMatchClick(int line) {
        line++;
        foreach(matchList; _matchedList){
            line--;
            if (line == 0) {
                if (_frame.openSourceFile(matchList.filename)) {
                    _frame.currentEditor.setTextToHighlight(_searchedText, _searchedFlags);
                    _frame.currentEditor.setFocus();
                }
                return true;
            }
            foreach(match; matchList.matches) {
                line--;
                if (line == 0) {
                    if (_frame.openSourceFile(matchList.filename)) {
                        _frame.caretHistory.pushNewPosition();
                        _frame.currentEditor.setCaretPos(match.line, to!int(match.col));
                        _frame.currentEditor.setTextToHighlight(_searchedText, _searchedFlags);
                        _frame.currentEditor.setFocus();
                        _frame.caretHistory.pushNewPosition();
                    }
                    return true;
                }
            }
        }
        return false;
    }
}

/// the lines of file filename with a match of searchString; searchFlags: TextSearchFlag.CaseSensitive and WholeWords.
/// lines: the text of an editor that has the file open, with its unsaved edits, or null to read the file (#611)
SearchMatchList findMatches(in string filename, in dstring searchString, uint searchFlags,
        const(dstring)[] lines = null) {
    const(dstring)[] text = lines !is null ? lines : loadLines(filename);
    SearchMatchList match;
    match.filename = filename;

    foreach(lineIndex, dstring line; text) {
        immutable ptrdiff_t colIndex = firstMatchColumn(line, searchString, searchFlags);
        if (colIndex != -1) {
            match.matches ~= SearchMatch(cast(int)lineIndex, colIndex, line);
        }
    }
    return match;  
}

/// the lines of file filename
private const(dstring)[] loadLines(in string filename) {
    EditableContent content = new EditableContent(true);
    content.load(filename);
    return content.lines;
}

unittest {
    // the text of an open editor is searched, not the file (here: no file at all) (#611)
    const(dstring)[] edited = ["struct Figure {"d, ""d, "Figure f;"d];
    SearchMatchList m = findMatches("no-such-file-611.d", "Figure"d, TextSearchFlag.CaseSensitive, edited);
    assert(m.filename == "no-such-file-611.d" && m.matches.length == 2);
    assert(m.matches[0].line == 0 && m.matches[0].col == 7 && m.matches[1].line == 2 && m.matches[1].col == 0);
}

/// column of the first match of pattern in line, or -1; searchFlags: TextSearchFlag.CaseSensitive and WholeWords.
/// The same matching as the editor's search, which also works around a Phobos bug in case-insensitive indexOf (#260)
ptrdiff_t firstMatchColumn(dstring line, dstring pattern, uint searchFlags) {
    ptrdiff_t col = -1;
    EditBox.forEachLineMatch(line, 0, pattern, (searchFlags & TextSearchFlag.CaseSensitive) != 0,
            (searchFlags & TextSearchFlag.WholeWords) != 0, (TextRange r) {
        if (col < 0)
            col = r.start.pos;
    });
    return col;
}

unittest {
    enum cs = TextSearchFlag.CaseSensitive, ww = TextSearchFlag.WholeWords;
    // case: Phobos indexOf missed "text" in "    TextWidget" (dlang/phobos#11160)
    assert(firstMatchColumn("    TextWidget"d, "text"d, 0) == 4);
    assert(firstMatchColumn("    TextWidget"d, "text"d, cs) == -1);
    assert(firstMatchColumn("    TextWidget"d, "Text"d, cs) == 4);
    // whole words
    assert(firstMatchColumn("    TextWidget"d, "Text"d, ww) == -1);
    assert(firstMatchColumn("TextWidget; Text t;"d, "Text"d, ww | cs) == 12);
    assert(firstMatchColumn("textWidget; TEXT t;"d, "text"d, ww) == 12);
    assert(firstMatchColumn("no match"d, "Text"d, 0) == -1);
}
