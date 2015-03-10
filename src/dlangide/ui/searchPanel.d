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
	}

    override protected CustomCharProps[] handleCustomLineHighlight(int line, dstring txt, ref CustomCharProps[] buf) {
		uint defColor = textColor;
		const uint filenameColor = 0x0000C0;
		const uint errorColor = 0xFF0000;
		const uint warningColor = 0x606000;
		const uint deprecationColor = 0x802040;
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
					cl = filenameColor;
                    flags = TextFlag.Underline;
	        	}
	        	colors[i].color = cl;
                colors[i].textFlags = flags;
            }
            return colors;
		}
        //Highlight line and collumn
		else {
		    CustomCharProps[] colors = buf[0..txt.length];
		    uint cl = filenameColor;
		    flags = TextFlag.Underline;
		    for (int i = 0; i < txt.length; i++) {
		        dstring rest = txt[i..$];
		        if (rest.startsWith(" -->"d)) {
		            cl = warningColor;
		            flags = 0;
		        }
		        if(i == 4) {
		        	cl = errorColor;
		        	flags = TextFlag.Underline;
		        }
		        
		        colors[i].color = cl;
		        colors[i].textFlags = flags;

		        //Colors to apply in following iterations of the loop.
		        if(rest.startsWith("]")) {
		        	cl = defColor;
		        	flags = 0;
		        }
		    }
		    return colors;
		}
	}
    
	override bool onMouseEvent(MouseEvent event) {
        super.onMouseEvent(event);
		if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
            int line = _caretPos.line;
            if (searchResultClickHandler.assigned) {
                searchResultClickHandler(line);
                return true;
            }
        }
        return false;
    }
}

class SearchWidget : TabWidget {
	HorizontalLayout _layout;
	EditLine _findText;
	SearchLogWidget _resultLog;

	protected IDEFrame _frame;
    protected SearchMatchList[] _matchedList;

	struct SearchMatch {
		int line;
		long col;
		dstring lineContent;
	}
    
    struct SearchMatchList {
        string filename;
        SearchMatch[] matches;
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
		_layout.addChild(_findText);
		
		auto goButton = new ImageButton("findTextButton", "edit-redo");
		goButton.addOnClickListener( delegate(Widget) {
				findText(_findText.text);
				return true;
			});
		_layout.addChild(goButton);
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
	        for (int i = 0; i < projFolder.childCount; i++) {
                searchInProject(projFolder.child(i), text);   
	        }
        }
        else {
            Log.d("Searching in: " ~ project.filename);
            EditableContent content = new EditableContent(true);
            content.load(project.filename);
            SearchMatchList match;
            match.filename = project.filename;

            foreach(int lineIndex, dstring line; content.lines) {
    			auto colIndex = line.indexOf(text);
    			if (colIndex != -1) {
    				match.matches ~= SearchMatch(lineIndex, colIndex, line);
    			}
    		}
            
            if(match.matches.length > 0) {
                _matchedList ~= match;
            }
        }
    }
	
	bool findText(dstring source) {
        Log.d("Finding " ~ source);
        
        _resultLog.text = ""d;
        _matchedList = [];
        
		//TODO Should not crash when in homepage.
        
        foreach(Project project; _frame._wsPanel.workspace.projects) {
            Log.d("Searching in project " ~ project.filename);
        	searchInProject(project.items, source);
        }
        
        if (_matchedList.length == 0) {
			_resultLog.appendText(to!dstring("No matches found.\n"));
		}
		else {
			foreach(SearchMatchList fileMatchList; _matchedList) {
				_resultLog.appendText("Matches in "d ~ to!dstring(fileMatchList.filename) ~ '\n');
				foreach(SearchMatch match; fileMatchList.matches) {
					_resultLog.appendText(" --> ["d ~ to!dstring(match.line+1) ~ ":"d ~ to!dstring(match.col) ~ "]" ~ match.lineContent ~"\n"d);
				}
			}
		}
		return true;
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
