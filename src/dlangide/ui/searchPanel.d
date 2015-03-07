module dlangide.ui.searchPanel;


import dlangui;
import dlangui.core.editable;

import dlangide.ui.frame;
import dlangide.ui.wspanel;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.string;
import std.conv;

class SearchWidget : TabWidget {
	HorizontalLayout _layout;
	EditLine _findText;
	LogWidget _resultLog;

	protected IDEFrame _frame;

	struct SearchMatch {
		int line;
		long col;
		string fileName;
		
		string toString() {
			return '[' ~ to!string(line) ~ ':' ~ to!string(col) ~ "] " ~ fileName;
		}
	}
	
	this(string ID, IDEFrame frame) {
		super(ID);
		_frame = frame;

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

		_resultLog = new LogWidget("SearchLogWidget");
		_resultLog.layoutHeight(FILL_PARENT);
        addChild(_resultLog);


	}
    
    void searchInProject(ProjectItem project, ref SearchMatch[] matches, dstring text) {
        if(project.isFolder) {
            foreach(ProjectItem child; cast(ProjectFolder) project) {
                searchInProject(child, matches, text);   
            }
        }
        else {
            EditableContent content = new EditableContent(true);
            content.load(project.filename);
            foreach(int lineIndex, dstring line; content.lines) {
    			auto colIndex = line.indexOf(text);
    			if( colIndex != -1) {
    				matches ~= SearchMatch(lineIndex+1, colIndex, project.filename);
    			}
    		}
        }        
    }
	
	bool findText(dstring source) {
        Log.d("Finding " ~ source);
		SearchMatch[] matches;
		//TODO Should not crash when in homepage.
        
        searchInProject(_frame.currentEditor.projectSourceFile, matches, source);
        Log.d("Searching in current file " ~ source);

		if(currentWorkspace) {
            foreach(ProjectItem project ; currentWorkspace.projects[0].items) {
                searchInProject(project, matches, source);
            }
        }
        
        if(matches.length == 0) {
			_resultLog.appendText(to!dstring("No matches in current file." ~ '\n'));
		}
		else {
			_resultLog.appendText(to!dstring("Matches found in current file: " ~ '\n'));
			foreach(SearchMatch match; matches) {
                if(match.fileName == _frame.currentEditor.content.filename)
                    _resultLog.appendText(to!dstring(" --> [" ~ to!string(match.line) ~ ':' ~ to!string(match.col) ~ "] in current file\n"));
                else
    				_resultLog.appendText(to!dstring(" --> " ~ match.toString" ~ '\n'));
			}
		}
        
        
        
        
		return true;
	}
}
