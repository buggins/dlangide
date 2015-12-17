module dlangide.ui.stackpanel;

import dlangui;

class StackPanel : DockWindow {

    this(string id) {
        super(id);
        _caption.text = "Stack"d;
    }

    override protected Widget createBodyWidget() {
        VerticalLayout root = new VerticalLayout();
        root.layoutWeight = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        ComboBox comboBox = new ComboBox("threadComboBox", ["Thread1"d]);
        comboBox.layoutWidth = FILL_PARENT;
        comboBox.selectedItemIndex = 0;
        StringGridWidget grid = new StringGridWidget("stackGrid");
        grid.resize(2, 20);
        grid.showColHeaders = true;
        grid.showRowHeaders = false;
        grid.layoutHeight = FILL_PARENT;
        grid.layoutWidth = FILL_PARENT;
        grid.setColTitle(0, "Function"d);
        grid.setColTitle(1, "Address"d);
        grid.setCellText(0, 0, "main()"d);
        root.addChild(comboBox);
        root.addChild(grid);
        return root;
    }

    protected void onPopupMenuItem(MenuItem item) {
        if (item.action)
            handleAction(item.action);
    }

    /// override to handle specific actions
	override bool handleAction(const Action a) {
        return super.handleAction(a);
    }
}

