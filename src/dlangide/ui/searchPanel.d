module dlangide.ui.searchPanel;

import dlangide.ui.frame;
import dlangui;

class SearchWidget : TabWidget {
	HorizontalLayout _layout;
	EditLine _findText;
	LogWidget _resultLog;


	protected IDEFrame _frame;
	
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
	
	bool findText(dstring source) {
		struct SearchMatch {
			int line;
			long col;
			string fileName;
		}

		import std.string;
		SearchMatch[] matches;
		//TODO Should not crash when in homepage.
		foreach(int lineIndex, dstring line; _frame.currentEditor.content.lines) {
			auto colIndex = line.indexOf(source);
			if( colIndex != -1) {
				matches ~= SearchMatch(lineIndex+1, colIndex, "");
				_resultLog.appendText( "   " ~ to!dstring(matches[$-1]) ~ '\n');
			}
		}
//		_resultLog.text = "";
//		if(matches.length > 1){
//			_resultLog.appendText(to!dstring(matches[0].line));
//		}
		return false;
	}
}