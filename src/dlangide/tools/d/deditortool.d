module dlangide.tools.d.deditorTool;

import dlangide.tools.editorTool;
import dlangide.tools.d.dcdinterface;
import dlangide.ui.dsourceedit;
import dlangui.widgets.editors;
import dlangide.ui.frame;
import std.stdio;
import std.string;
import std.utf;
import dlangui.core.logger;

import std.conv;

// TODO: async operation in background thread
// TODO: effective caretPositionToByteOffset/byteOffsetToCaret impl

class DEditorTool : EditorTool 
{


	this(IDEFrame frame) {
		_dcd = new DCDInterface(DCD_SERVER_PORT_FOR_DLANGIDE);
		super(frame);
	}

	override bool goToDefinition(DSourceEdit editor, TextPosition caretPosition) {
        string[] importPaths = editor.importPaths();
        string content = toUTF8(editor.text);
		auto byteOffset = caretPositionToByteOffset(content, caretPosition);
		ResultSet output = _dcd.goToDefinition(importPaths, content, byteOffset);


		switch(output.result) {
			//TODO: Show dialog
			case DCDResult.FAIL:
			case DCDResult.DCD_NOT_RUNNING:
			case DCDResult.NO_RESULT:
                editor.setFocus();
				return false;
			case DCDResult.SUCCESS:
				auto target = to!int(output.output[1]);
				if(output.output[0].indexOf("stdin".dup) != -1) {
					Log.d("Declaration is in current file. Jumping to it.");
					auto destPos = byteOffsetToCaret(content, target);
					editor.setCaretPos(destPos.line,destPos.pos);
                    editor.setFocus();
				}
				else {
					//Must open file first to get the content for finding the correct caret position.
    				_frame.openSourceFile(to!string(output.output[0]));
                    string txt;
                    txt = toUTF8(_frame.currentEditor.text);
					auto destPos = byteOffsetToCaret(txt, target);
					_frame.currentEditor.setCaretPos(destPos.line,destPos.pos);
                    _frame.currentEditor.setFocus();
        		}
        		return true;
        	default:
        		return false;
		}
    }

    override dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition) {
        string[] importPaths = editor.importPaths();

        string content = toUTF8(editor.text);
		auto byteOffset = caretPositionToByteOffset(content, caretPosition);
		ResultSet output = _dcd.getCompletions(importPaths, content, byteOffset);
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

	int caretPositionToByteOffset(string content, TextPosition caretPosition) {
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

	TextPosition byteOffsetToCaret(string content, int byteOffset) {
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
