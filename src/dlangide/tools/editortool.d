module dlangide.tools.editortool;



import dlangui.widgets.editors;
import dlangui.core.types;
import dlangide.ui.frame;
import dlangide.ui.dsourceedit;

public import dlangide.tools.d.deditortool;

enum CompletionTypes : int {
    IdentifierList,
    CallTips,
}

class EditorTool
{
    this(IDEFrame frame) {
        _frame = frame;
    }
    //Since files might be unsaved, we must send all the text content.
    abstract void goToDefinition(DSourceEdit editor, TextPosition caretPosition);
    abstract void getDocComments(DSourceEdit editor, TextPosition caretPosition, void delegate(string[]) callback);
    abstract void getCompletions(DSourceEdit editor, TextPosition caretPosition, void delegate(dstring[] labels, string[] icons, CompletionTypes type) callback);

    void cancelGoToDefinition() {}
    void cancelGetDocComments() {}
    void cancelGetCompletions() {}

    protected IDEFrame _frame;
    
}

class DefaultEditorTool : EditorTool
{
    this(IDEFrame frame) {
        super(frame);
    }
    
    override void goToDefinition(DSourceEdit editor, TextPosition caretPosition) {
        //assert(0); //Go To Definition should not be called for normal files.
    }
    
    override void getCompletions(DSourceEdit editor, TextPosition caretPosition, void delegate(dstring[] labels, string[] icons, CompletionTypes type) callback) {
        //assert(0);
    }

    override void getDocComments(DSourceEdit editor, TextPosition caretPosition, void delegate(string[]) callback) {
        //assert(0);
    }
}
