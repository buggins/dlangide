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
        super(frame);
    }

    override string[] getDocComments(DSourceEdit editor, TextPosition caretPosition) {
        string[] importPaths = editor.importPaths();

        string content = toUTF8(editor.text);
        auto byteOffset = caretPositionToByteOffset(content, caretPosition);
        DocCommentsResultSet output = _frame.dcdInterface.getDocComments(importPaths, editor.filename, content, byteOffset);

        switch(output.result) {
            //TODO: Show dialog
            case DCDResult.FAIL:
            case DCDResult.NO_RESULT:
                editor.setFocus();
                return null;
            case DCDResult.SUCCESS:
                auto doc = output.docComments;
                Log.d("Doc comments: ", doc);
                return doc;
            default:
                return null;
        }
    }

    override bool goToDefinition(DSourceEdit editor, TextPosition caretPosition) {
        string[] importPaths = editor.importPaths();

        string content = toUTF8(editor.text);
        auto byteOffset = caretPositionToByteOffset(content, caretPosition);
        FindDeclarationResultSet output = _frame.dcdInterface.goToDefinition(importPaths, editor.filename, content, byteOffset);


        switch(output.result) {
            //TODO: Show dialog
            case DCDResult.FAIL:
            case DCDResult.NO_RESULT:
                editor.setFocus();
                return false;
            case DCDResult.SUCCESS:
		        auto fileName = output.fileName;
                if(fileName.indexOf("stdin") == 0) {
                    Log.d("Declaration is in current file. Jumping to it.");
                } else {
                    //Must open file first to get the content for finding the correct caret position.
                    if (!_frame.openSourceFile(to!string(fileName)))
                        return false;
                    if (_frame.currentEditor.parent)
                        _frame.currentEditor.parent.layout(_frame.currentEditor.parent.pos);
                    content = toUTF8(_frame.currentEditor.text);
                }
                auto target = to!int(output.offset);
                auto destPos = byteOffsetToCaret(content, target);
                _frame.currentEditor.setCaretPos(destPos.line,destPos.pos, true, true);
                _frame.currentEditor.setFocus();
                return true;
            default:
                return false;
        }
    }

    override dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition) {
        string[] importPaths = editor.importPaths();

        string content = toUTF8(editor.text);
        auto byteOffset = caretPositionToByteOffset(content, caretPosition);
        ResultSet output = _frame.dcdInterface.getCompletions(importPaths, editor.filename, content, byteOffset);
        switch(output.result) {
            //TODO: Show dialog
            case DCDResult.FAIL:
            case DCDResult.NO_RESULT:
            case DCDResult.SUCCESS:
            default:
                return output.output;
        }
    }

private:

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
