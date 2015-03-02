module dlangide.ui.searchPanel;

import dlangide.ui.frame;
import dlangui;

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
			return to!string(line) ~ ':' ~ to!string(col) ~ ' ' ~ fileName;
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
	
	bool findText(dstring source) {
		SearchMatch[] matches;
		//TODO Should not crash when in homepage.
		foreach(int lineIndex, dstring line; _frame.currentEditor.content.lines) {
			auto colIndex = line.indexOf(source);
			if( colIndex != -1) {
				matches ~= SearchMatch(lineIndex+1, colIndex, "");
			}
		}
		if(matches.length == 0) {
			_resultLog.appendText(to!dstring("No matches in current file." ~ '\n'));
		}
		else {
			_resultLog.appendText(to!dstring("Matches found in current file: " ~ '\n'));
			foreach(SearchMatch match; matches) {
				_resultLog.appendText(to!dstring("  ->" ~ match.toString ~ '\n'));
			}
		}
		return true;
	}
}