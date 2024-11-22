pageextension 50020 "PTEARV Whse Employee Ext" extends "Warehouse Employee List"
{
    layout
    {
        addafter("Location Code")
        {
            field(PTEARVItemJrnlTemplateCtrl; Rec."PTEARV Item Jnl Template")
            {
                Caption = 'Item Journal Template';
                ToolTip = 'Select the Item Journal Template. This Info will be used for the ARVA Tech Whse. Webservice Function.';
                ApplicationArea = All;
            }
            field(PTEARVItemJnlBatchCtrl; Rec."PTEARV  Transfer Jnl Template")
            {
                Caption = 'Item Journal Batch';
                ToolTip = 'Select the Item Journal Batch. This Info will be used for the ARVA Tech Whse. Webservice Function.';
                ApplicationArea = All;
            }
            field(PTEARVTransferJnlTemplateCtrl; Rec."PTEARV  Item Jnl Batch")
            {
                Caption = 'Item Journal Template';
                ToolTip = 'Select the Transfer Journal Template. This Info will be used for the ARVA Tech Whse. Webservice Function.';
                ApplicationArea = All;
            }
            field(PTEARVTransferJnlBatchCtrl; Rec."PTEARV Transfer Jnl Batch")
            {
                Caption = 'Transfer Journal Batch';
                ToolTip = 'Select the Transfer Journal Batch. This Info will be used for the ARVA Tech Whse. Webservice Function.';
                ApplicationArea = All;
            }
        }
    }
}