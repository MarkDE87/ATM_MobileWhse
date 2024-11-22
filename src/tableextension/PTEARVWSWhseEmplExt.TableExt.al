/// <summary>
/// TableExtension ARV Whse Employee Ext (ID 50012) extends Record Warehouse Employee.
/// </summary>
tableextension 50020 "PTEARV WS Whse Empl. Ext" extends "Warehouse Employee"
{
    fields
    {
        field(50010; "PTEARV Item Jnl Template"; Code[10])
        {
            DataClassification = SystemMetadata;
            Caption = 'Item Journal Template';
            TableRelation = "Item Journal Template".Name where(Type = const(Item));
        }
        field(50011; "PTEARV  Transfer Jnl Template"; Code[10])
        {
            DataClassification = SystemMetadata;
            Caption = 'Transfer Journal Template';
            TableRelation = "Item Journal Template".Name where(Type = const(Transfer));
        }
        field(50012; "PTEARV  Item Jnl Batch"; Code[10])
        {
            DataClassification = SystemMetadata;
            Caption = 'Item Journal Batchname';
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("PTEARV Item Jnl Template"));
        }
        field(50013; "PTEARV Transfer Jnl Batch"; Code[10])
        {
            DataClassification = SystemMetadata;
            Caption = 'Transfer Journal Batchname';
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("PTEARV Item Jnl Template"));
        }
    }

}