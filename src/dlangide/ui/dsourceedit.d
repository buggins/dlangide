module dlangide.ui.dsourceedit;

import dlangui.core.logger;
import dlangui.widgets.editors;
import dlangui.widgets.srcedit;
import dlangui.widgets.menu;
import dlangui.widgets.popup;

import ddc.lexer.textsource;
import ddc.lexer.exceptions;
import ddc.lexer.tokenizer;

import dlangide.workspace.workspace;
import dlangide.workspace.project;
import dlangide.ui.commands;
import dlangide.tools.d.simpledsyntaxhighlighter;

import std.algorithm;


/// DIDE source file editor
class DSourceEdit : SourceEdit {
	this(string ID) {
		super(ID);
		styleId = null;
		backgroundColor = 0xFFFFFF;
        setTokenHightlightColor(TokenCategory.Comment, 0x008000); // green
        setTokenHightlightColor(TokenCategory.Keyword, 0x0000FF); // blue
        setTokenHightlightColor(TokenCategory.String, 0xA31515);  // brown
        setTokenHightlightColor(TokenCategory.Character, 0xA31515);  // brown
        setTokenHightlightColor(TokenCategory.Error, 0xFF0000);  // red
        setTokenHightlightColor(TokenCategory.Comment_Documentation, 0x206000);
        //setTokenHightlightColor(TokenCategory.Identifier, 0x206000);  // no colors
		MenuItem editPopupItem = new MenuItem(null);
		editPopupItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT, ACTION_GET_COMPLETIONS);
        popupMenu = editPopupItem;
        showIcons = true;
        showFolding = true;
	}
	this() {
		this("SRCEDIT");
	}
    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile projectSourceFile() { return _projectSourceFile; }
    /// load by filename
    override bool load(string fn) {
        _projectSourceFile = null;
        bool res = super.load(fn);
        setHighlighter();
        return res;
    }

    void setHighlighter() {
        if (filename.endsWith(".d") || filename.endsWith(".dd") || filename.endsWith(".dh") || filename.endsWith(".ddoc")) {
            content.syntaxHighlighter = new SimpleDSyntaxHighlighter(filename);
        } else {
            content.syntaxHighlighter = null;
        }
    }

    /// load by project item
    bool load(ProjectSourceFile f) {
        if (!load(f.filename)) {
            _projectSourceFile = null;
            return false;
        }
        _projectSourceFile = f;
        setHighlighter();
        return true;
    }

    /// save to the same file
    bool save() {
        return _content.save();
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case IDEActions.FileSave:
                    save();
                    return true;
                case IDEActions.InsertCompletion:
                    EditOperation edit = new EditOperation(EditAction.Replace, getCaretPosition, a.label);
                    _content.performOperation(edit, this);
                    setFocus();
                    return true;
                default:
                    break;
            }
        }
        return super.handleAction(a);
    }



    void showCompletionPopup(dstring[] suggestions) {

        if(suggestions.length == 0) {
            return;
        }

        MenuItem completionPopupItems = new MenuItem(null);
        //Add all the suggestions.
        foreach(int i, dstring suggestion ; suggestions) {
            auto action = new Action(IDEActions.InsertCompletion, suggestion);
            completionPopupItems.add(action);
        }
        completionPopupItems.updateActionState(this);

        PopupMenu popupMenu = new PopupMenu(completionPopupItems);
        popupMenu.onMenuItemActionListener = this;
        popupMenu.maxHeight(400);
        popupMenu.selectItem(0);

        PopupWidget popup = window.showPopup(popupMenu, this, PopupAlign.Point | PopupAlign.Right, textPosToClient(_caretPos).left + left + _leftPaneWidth, textPosToClient(_caretPos).top + top + margins.top);
        popup.setFocus();
        popup.flags = PopupFlags.CloseOnClickOutside;

        Log.d("Showing popup at ", textPosToClient(_caretPos).left, " ", textPosToClient(_caretPos).top);
    }

    TextPosition getCaretPosition() {
        return _caretPos;
    }

	/// change caret position and ensure it is visible
	void setCaretPos(int line, int column)
	{
		_caretPos = TextPosition(line,column);
		invalidate();
		ensureCaretVisible();
	}
}
