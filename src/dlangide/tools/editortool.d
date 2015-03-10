module dlangide.tools.editorTool;



import dlangui.widgets.editors;
import dlangui.core.types;
import dlangide.ui.frame;
import dlangide.ui.dsourceedit;

public import dlangide.tools.d.deditorTool;

class EditorTool
{
	this(IDEFrame frame) {
		_frame = frame;
	}
	//Since files might be unsaved, we must send all the text content.
	abstract bool goToDefinition(DSourceEdit editor, TextPosition caretPosition);
	abstract dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition);

	protected IDEFrame _frame;
	
}

class DefaultEditorTool : EditorTool
{
    this(IDEFrame frame) {
        super(frame);
    }
    
    override bool goToDefinition(DSourceEdit editor, TextPosition caretPosition) {
        assert(0); //Go To Definition should not be called for normal files.
    }
    
    override dstring[] getCompletions(DSourceEdit editor, TextPosition caretPosition) {
        assert(0);
    }
}
