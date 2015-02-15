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
