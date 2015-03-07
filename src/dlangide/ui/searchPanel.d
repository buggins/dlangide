module dlangide.ui.searchPanel;


import dlangui;
import dlangui.core.editable;

import dlangide.ui.frame;
import dlangide.ui.wspanel;
import dlangide.workspace.workspace;
import dlangide.workspace.project;

import std.string;
import std.conv;

class SearchLogWidget : LogWidget {

	this(string ID){
		super(ID);
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

		        //Colors to applay after current character.
		        if(rest.startsWith("]")) {
		        	cl = defColor;
		        	flags = 0;
		        }
		    }
		    return colors;
		}
	}
}

class SearchWidget : TabWidget {
	HorizontalLayout _layout;
	EditLine _findText;
	LogWidget _resultLog;

	protected IDEFrame _frame;

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
		_resultLog.layoutHeight(FILL_PARENT);
        addChild(_resultLog);


	}
    
    void searchInProject(ProjectItem project, ref SearchMatchList[] matchList, dstring text) {
        if(project.isFolder) {
            foreach(ProjectItem child; cast(ProjectFolder) project) {
                searchInProject(child, matchList, text);   
            }
        }
        else {
            EditableContent content = new EditableContent(true);
            content.load(project.filename);
            SearchMatchList match;
            match.filename = project.filename;

            foreach(int lineIndex, dstring line; content.lines) {
    			auto colIndex = line.indexOf(text);
    			if( colIndex != -1) {
    				match.matches ~= SearchMatch(lineIndex+1, colIndex, line);
    			}
    		}
            
            if(match.matches.length > 0) {
                matchList ~= match;
            }
        }
    }
	
	bool findText(dstring source) {
        Log.d("Finding " ~ source);
		SearchMatchList[] matches;
		//TODO Should not crash when in homepage.
        
        foreach(Project project; _frame._wsPanel.workspace.projects) {
        	searchInProject(project.items, matches, source);
        }
        
        if(matches.length == 0) {
			_resultLog.appendText(to!dstring("No matches found.\n"));
		}
		else {
			foreach(SearchMatchList fileMatchList; matches) {
				_resultLog.appendText("Matches in "d ~ to!dstring(fileMatchList.filename) ~ '\n');
				foreach(SearchMatch match; fileMatchList.matches) {
					_resultLog.appendText(" --> ["d ~ to!dstring(match.line) ~ ":"d ~ to!dstring(match.col) ~ "]" ~ match.lineContent ~"\n"d);
				}
			}
		}
		return true;
	}
}