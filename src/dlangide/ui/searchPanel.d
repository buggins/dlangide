module dlangide.ui.searchPanel;


import dlangui;

import dlangide.ui.frame;
import dlangide.ui.wspanel;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.string;
import std.conv;

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

    protected dstring _textToHighlight;
    @property dstring textToHighlight() { return _textToHighlight; }
    @property void textToHighlight(dstring s) { _textToHighlight = s; }

    protected uint _filenameColor = 0x0000C0;
    protected uint _errorColor = 0xFF0000;
    protected uint _warningColor = 0x606000;
    protected uint _deprecationColor = 0x802040;

    /// handle theme change: e.g. reload some themed resources
    override void onThemeChanged() {
        _filenameColor = style.customColor("build_log_filename_color", 0x0000C0);
        _errorColor = style.customColor("build_log_error_color", 0xFF0000);
        _warningColor = style.customColor("build_log_warning_color", 0x606000);
        _deprecationColor = style.customColor("build_log_deprecation_color", 0x802040);
        super.onThemeChanged();
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
                dstring rest = txt[i..$];
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
            int foundHighlightStart = 0;
            int foundHighlightEnd = 0;
            bool textStarted = false;
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
                    if (rest.startsWith(_textToHighlight)) {
                        foundHighlightStart = i;
                        foundHighlightEnd = i + cast(int)_textToHighlight.length;
                    }
                    if (i >= foundHighlightStart && i < foundHighlightEnd) {
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

class SearchWidget : TabWidget {
    HorizontalLayout _layout;
    EditLine _findText;
    SearchLogWidget _resultLog;
    int _resultLogMatchIndex;
    ComboBox _searchScope;

    protected IDEFrame _frame;
    protected SearchMatchList[] _matchedList;

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

    protected bool onEditorAction(const Action action) {
        if (action.id == EditorActions.InsertNewLine) {
            return onFindButtonPressed(this);
        }
        return false;
    }

    this(string ID, IDEFrame frame) {
        super(ID);
        _frame = frame;
        
        layoutHeight(FILL_PARENT);
        
        //Remove title, more button
        removeAllChildren();
        
        _layout = new HorizontalLayout();
        _layout.addChild(new TextWidget("FindLabel", "Find: "d));
        
        _findText = new EditLine();
        _findText.padding(Rect(5,4,50,4));
        _findText.layoutWidth(400);
        _findText.editorAction = &onEditorAction; // to handle Enter key press in editor
        _layout.addChild(_findText);
        
        auto goButton = new ImageButton("findTextButton", "edit-find");
        goButton.click = &onFindButtonPressed;
        _layout.addChild(goButton);
        
        _searchScope = new ComboBox("searchScope", ["File"d, "Project"d, "Dependencies"d, "Everywhere"d]);
        _searchScope.selectedItemIndex = 0;
        _layout.addChild(_searchScope);
        addChild(_layout);

        _resultLog = new SearchLogWidget("SearchLogWidget");
        _resultLog.searchResultClickHandler = &onMatchClick;
        _resultLog.layoutHeight(FILL_PARENT);
        addChild(_resultLog);
    }
    
    //Recursively search for text in projectItem
    void searchInProject(ProjectItem project, dstring text) {
        if (project.isFolder == true) {
            ProjectFolder projFolder = cast(ProjectFolder) project;
            import std.parallelism;
            for (int i = 0; i < projFolder.childCount; i++) {
                    taskPool.put(task(&searchInProject, projFolder.child(i), text));   
            }
        }
        else {
            Log.d("Searching in: " ~ project.filename);
            SearchMatchList match = findMatches(project.filename, text);
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
        
        _resultLog.textToHighlight = ""d;
        _resultLog.text = ""d;
        _matchedList = [];
        _resultLogMatchIndex = 0;
        
        import std.parallelism; //for taskpool.
        
        switch (_searchScope.text) {
            case "File":
                SearchMatchList match = findMatches(_frame.currentEditor.filename, source);
                if(match.matches.length > 0)
                    _matchedList ~= match;
                break;
            case "Project":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                    if(!project.isDependency)
                        taskPool.put(task(&searchInProject, project.items, source));
               }
               break;
            case "Dependencies":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                    if(project.isDependency)
                        taskPool.put(task(&searchInProject, project.items, source));
               }
               break;
            case "Everywhere":
               foreach(Project project; _frame._wsPanel.workspace.projects) {
                    taskPool.put(task(&searchInProject, project.items, source));
               }
               break;
            default:
                assert(0);
        }
        _resultLog.textToHighlight = source;
        return true;
    }
    
    override void onDraw(DrawBuf buf) {
        //Check if there are new matches to display
        if(_resultLogMatchIndex < _matchedList.length) {
            for(; _resultLogMatchIndex < _matchedList.length; _resultLogMatchIndex++) {
                SearchMatchList matchList = _matchedList[_resultLogMatchIndex];
                _resultLog.appendText("Matches in "d ~ to!dstring(matchList.filename) ~ '\n');
                foreach(SearchMatch match; matchList.matches) {
                    _resultLog.appendText(" --> ["d ~ to!dstring(match.line+1) ~ ":"d ~ to!dstring(match.col) ~ "]" ~ match.lineContent ~"\n"d);
                }
            }
        }
        super.onDraw(buf);
    }
    
    //Find the match/matchList that corrosponds to the line in _resultLog
    bool onMatchClick(int line) {
        line++;
        foreach(matchList; _matchedList){
            line--;
            if (line == 0) {
                _frame.openSourceFile(matchList.filename);
                _frame.currentEditor.setFocus();
                return true;
            }
            foreach(match; matchList.matches) {
                line--;
                if (line == 0) {
                    _frame.openSourceFile(matchList.filename);
                    _frame.currentEditor.setCaretPos(match.line, to!int(match.col));
                    _frame.currentEditor.setFocus();
                    return true;
                }
            }
        }
        return false;
    }
}

SearchMatchList findMatches(in string filename, in dstring searchString) {
    EditableContent content = new EditableContent(true);
    content.load(filename);
    SearchMatchList match;
    match.filename = filename;

    foreach(int lineIndex, dstring line; content.lines) {
        auto colIndex = line.indexOf(searchString);
        
        if (colIndex != -1) {
            match.matches ~= SearchMatch(lineIndex, colIndex, line);
        }
    }
    return match;  
}
