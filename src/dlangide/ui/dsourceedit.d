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
import dlangide.ui.settings;
import dlangide.tools.d.dsyntax;

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
		editPopupItem.add(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT, ACTION_EDIT_TOGGLE_LINE_COMMENT, ACTION_GET_COMPLETIONS, ACTION_GO_TO_DEFINITION);
        //ACTION_GO_TO_DEFINITION, ACTION_GET_COMPLETIONS
        popupMenu = editPopupItem;
        showIcons = true;
        showFolding = true;
	}
	this() {
		this("SRCEDIT");
	}
    protected IDESettings _settings;
    @property DSourceEdit settings(IDESettings s) {
        _settings = s;
        return this;
    }
    @property IDESettings settings() {
        return _settings;
    }
    void applySettings() {
        if (!_settings)
            return;
        tabSize = _settings.tabSize;
        useSpacesForTabs = _settings.useSpacesForTabs;
        smartIndents = _settings.smartIndents;
        smartIndentsAfterPaste = _settings.smartIndentsAfterPaste;
    }
    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile projectSourceFile() { return _projectSourceFile; }
    /// load by filename
    override bool load(string fn) {
        _projectSourceFile = null;
        bool res = super.load(fn);
        setSyntaxSupport();
        return res;
    }

    @property bool isDSourceFile() {
        return filename.endsWith(".d") || filename.endsWith(".dd") || filename.endsWith(".dh") || filename.endsWith(".ddoc");
    }

    void setSyntaxSupport() {
        if (isDSourceFile) {
            content.syntaxSupport = new SimpleDSyntaxSupport(filename);
        } else {
            content.syntaxSupport = null;
        }
    }

    /// returns project import paths - if file from project is opened in current editor
    string[] importPaths() {
        if (_projectSourceFile)
            return _projectSourceFile.project.importPaths;
        return null;
    }

    /// load by project item
    bool load(ProjectSourceFile f) {
        if (!load(f.filename)) {
            _projectSourceFile = null;
            return false;
        }
        _projectSourceFile = f;
        setSyntaxSupport();
        return true;
    }

    /// save to the same file
    bool save() {
        return _content.save();
    }

    void insertCompletion(dstring completionText) {
        TextRange range;
        TextPosition p = getCaretPosition;
        range.start = range.end = p;
        dstring lineText = content.line(p.line);
        dchar prevChar = p.pos > 0 ? lineText[p.pos - 1] : 0;
        dchar nextChar = p.pos < lineText.length ? lineText[p.pos] : 0;
        if (isIdentMiddleChar(prevChar)) {
            while(range.start.pos > 0 && isIdentMiddleChar(lineText[range.start.pos - 1]))
                range.start.pos--;
            if (isIdentMiddleChar(nextChar)) {
                while(range.end.pos < lineText.length && isIdentMiddleChar(lineText[range.end.pos]))
                    range.end.pos++;
            }
        }
        EditOperation edit = new EditOperation(EditAction.Replace, range, completionText);
        _content.performOperation(edit, this);
        setFocus();
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        import ddc.lexer.tokenizer;
        if (a) {
            switch (a.id) {
                case IDEActions.FileSave:
                    save();
                    return true;
                case IDEActions.InsertCompletion:
                    insertCompletion(a.label);
                    return true;
                default:
                    break;
            }
        }
        return super.handleAction(a);
    }

	/// override to handle specific actions state (e.g. change enabled state for supported actions)
	override bool handleActionStateRequest(const Action a) {
		switch (a.id) {
			case IDEActions.GoToDefinition:
			case IDEActions.GetCompletionSuggestions:
                if (isDSourceFile)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
			default:
				return super.handleActionStateRequest(a);
		}
	}

    void showCompletionPopup(dstring[] suggestions) {

        if(suggestions.length == 0) {
            setFocus();
            return;
        }

        if (suggestions.length == 1) {
            insertCompletion(suggestions[0]);
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
        popup.onPopupCloseListener = delegate(PopupWidget source) { setFocus(); };
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
