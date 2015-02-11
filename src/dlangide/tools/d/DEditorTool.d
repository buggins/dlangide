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

		
		auto content = editor.text();
		auto byteOffset = caretPositionToByteOffset(content, caretPosition);

		char[][] arguments = ["-l".dup, "-c".dup];
		arguments ~= [to!(char[])(byteOffset)];
		arguments ~= [to!(char[])(editor.projectSourceFile.filename())];

		dstring output;
		_dcd.execute(arguments, output);

		string[] outputLines = to!string(output).splitLines();
		Log.d("DCD:", outputLines);

        foreach(string outputLine ; outputLines) {
        	if(outputLine.indexOf("Not Found".dup) == -1) {
        		auto split = outputLine.indexOf("\t");
        		if(split == -1) {
        			Log.d("DCD output format error.");
        			break;
        		}
        		if(indexOf(outputLine[0 .. split],"stdin".dup) != -1) {
        			Log.d("Declaration is in current file. Can jump to it.");
        			auto target = to!int(outputLine[split+1 .. $]);
        			auto destPos = byteOffsetToCaret(content, target);
        			editor.setCaretPos(destPos.line,destPos.pos);
                }
                else {
                	auto filename = outputLine[0 .. split];
                	if(_frame !is null) {
                		writeln("Well I'm trying");
                		_frame.openSourceFile(filename);
                		auto target = to!int(outputLine[split+1 .. $]);
        				auto destPos = byteOffsetToCaret(_frame.currentEditor.text(), target);

        				_frame.currentEditor.setCaretPos(destPos.line,destPos.pos);
                		writeln("Well I tried");
                	}
                }
            }
        }
        return true;
    }

    override dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition) {
		auto content = editor.text();
		auto byteOffset = caretPositionToByteOffset(content, caretPosition);

		char[][] arguments = ["-c".dup];
		arguments ~= [to!(char[])(byteOffset)];
		arguments ~= [to!(char[])(editor.projectSourceFile.filename())];

		dstring output;
		_dcd.execute(arguments, output);

		char[] state = "".dup;
		dstring[] suggestions;
		foreach(dstring outputLine ; output.splitLines()) {
			if(outputLine == "identifiers") {
				state = "identifiers".dup;
			}
			else if(outputLine == "calltips") {
				state = "calltips".dup;
			}
			else {
				auto split = outputLine.indexOf("\t");
				if(split < 0) {
					break;
				}
				if(state == "identifiers") {
					suggestions ~= outputLine[0 .. split];
				}
			}
		}
		return suggestions;
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