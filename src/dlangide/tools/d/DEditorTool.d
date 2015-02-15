module dlangide.tools.d.editorTool;

import dlangide.tools.editorTool;
import dlangide.tools.d.DCDInterface;
import dlangide.ui.dsourceedit;
import dlangui.widgets.editors;
import dlangide.ui.frame;
import std.stdio;
import std.string;
import dlangui.core.logger;

import std.conv;

class DEditorTool : EditorTool 
{


	this(IDEFrame frame) {
		_dcd = new DCDInterface();
		super(frame);
	}

	override bool goToDefinition(DSourceEdit editor, TextPosition caretPosition) {

		auto byteOffset = caretPositionToByteOffset(editor.text, caretPosition);
		ResultSet output = _dcd.goToDefinition(editor.text, byteOffset);


		switch(output.result) {
			//TODO: Show dialog
			case DCDResult.FAIL:
			case DCDResult.DCD_NOT_RUNNING:
			case DCDResult.NO_RESULT:
				return false;
			case DCDResult.SUCCESS:
				auto target = to!int(output.output[1]);
				if(output.output[0].indexOf("stdin".dup) != -1) {
					Log.d("Declaration is in current file. Jumping to it.");
					auto destPos = byteOffsetToCaret(editor.text, target);
					editor.setCaretPos(destPos.line,destPos.pos);
				}
				else {
					//Must open file first to get the content for finding the correct caret position.
    				_frame.openSourceFile(to!string(output.output[0]));
					auto destPos = byteOffsetToCaret(_frame.currentEditor.text(), target);
					_frame.currentEditor.setCaretPos(destPos.line,destPos.pos);
        		}
        		return true;
        	default:
        		return false;
		}
    }

    override dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition) {

		auto byteOffset = caretPositionToByteOffset(editor.text, caretPosition);
		ResultSet output = _dcd.getCompletions(editor.text, byteOffset);
		switch(output.result) {
			//TODO: Show dialog
			case DCDResult.FAIL:
			case DCDResult.DCD_NOT_RUNNING:
			case DCDResult.NO_RESULT:
			case DCDResult.SUCCESS:
        	default:
        		return output.output;
		}
    }

private:
	DCDInterface _dcd;

	int caretPositionToByteOffset(dstring content, TextPosition caretPosition) {
		auto line = 0;
		auto pos = 0;
		auto bytes = 0;
		foreach(c; content) {
			bytes++;
			if(c == '\n') {
				line++;
			}
			if(line == caretPosition.line) {
				if(pos == caretPosition.pos)
					break;
				pos++;
			}
		}
		return bytes;
	}

	TextPosition byteOffsetToCaret(dstring content, int byteOffset) {
		int bytes = 0;
		int line = 0;
		int pos = 0;
		TextPosition textPos;
		foreach(c; content) {
			if(bytes == byteOffset) {
	            //We all good.
	            textPos.line = line;
	            textPos.pos = pos;
	            return textPos;
        	}
        	bytes++;
        	if(c == '\n')
	        {
	        	line++;
	        	pos = 0;
	        }
	        else {
        		pos++;
        	}
    	}
    	return textPos;
	}
}