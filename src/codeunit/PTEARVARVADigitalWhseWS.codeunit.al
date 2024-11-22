codeunit 50022 "PTEARV ARVA Digital Whse WS"
{
    // ---------------------------------------------------------------
    // ARVA Digital GmbH
    // Kundenanpassung
    // ---------------------------------------------------------------
    // Dev  Name
    // ---------------------------------------------------------------
    // MAL  Markus Albrecht
    // ---------------------------------------------------------------
    // No. Date        DEV  ToDo         Description
    // ---------------------------------------------------------------
    // 001 2023-08-12  MAL               Created V1.0


    trigger OnRun()
    begin

        // Testfälle
        // Zugang:
        //AdjustItemInventory('00000797','HL','H1',10,'',FALSE);
        //AdjustItemInventory('00000797','','H1',10,'',false);

        //AdjustItemInventory('00000797','HL','H1',10,'',true);
        //AdjustItemInventory('00000797','','H1',10,'',true);

        // Abgang:
        //AdjustItemInventory('00000797','HL','H1',-10,'',false);
        //AdjustItemInventory('00000797','','H1',-10,'',false);

        //AdjustItemInventory('00000797','HL','H1',-10,'',true);
        //AdjustItemInventory('00000797','','H1',-10,'',true);

        // Umlagerung:
        //ReclassItemInventory('00000797','HL','H1','HL','H2',true,10,'',true);
        //ReclassItemInventory('00000797','','H2','','H1',false,10,'',true);

        // Testfälle mit Serien Nr.:
        // Zugang:
        //AdjustItemInventory('DU','HL','H1',3,'MAL001|MAL002|MAL003',true);

        // Umlagerung:
        //ReclassItemInventory('DU','HL','H1','HL','H2',true,3,'MAL001|MAL002|MAL003',true);
        //ReclassItemInventory('DU','HL','H2','HL','H1',true,3,'MAL001|MAL002|MAL003',true);

        // Abgang:
        //AdjustItemInventory('DU','HL','H1',-3,'MAL001|MAL002|MAL003',true);
    end;

    var
        TransferType: Option "Item Jnl","Transfer Jrnl";

    /// <summary>
    /// AdjustItemInventory.
    /// </summary>
    /// <param name="ItemNo">Code[20].</param>
    /// <param name="FromLocationCode">Code[10].</param>
    /// <param name="FromBinCode">Code[10].</param>
    /// <param name="Quantity">Decimal.</param>
    /// <param name="SerialNumber">Text.</param>
    /// <param name="PostNow">Boolean.</param>
    procedure AdjustItemInventory(ItemNo: Code[20]; FromLocationCode: Code[10]; FromBinCode: Code[10]; Quantity: Decimal; SerialNumber: Text; PostNow: Boolean)
    var
        BinLoc: Record Bin;
        ItemJnlBatchLoc: Record "Item Journal Batch";
        ItemJournalLineLoc: Record "Item Journal Line";
    begin
        // Buchblatt anhand von Mitarbeiter ermitteln
        GetJnlBatchFromEmployee(ItemJnlBatchLoc, TransferType::"Item Jnl");

        InitNewItemJournalLine(ItemJnlBatchLoc, ItemJournalLineLoc);

        if Quantity < 0 then
            ItemJournalLineLoc.Validate("Entry Type", ItemJournalLineLoc."Entry Type"::"Negative Adjmt.")
        else
            ItemJournalLineLoc.Validate("Entry Type", ItemJournalLineLoc."Entry Type"::"Positive Adjmt.");

        // Wenn kein Lagerortcode gesetzt ist aber ein Bin code,
        // dann lagerortcode ermitteln von Bin-Tabelle
        if (FromLocationCode = '') and (FromBinCode <> '') then begin
            BinLoc.SetRange(BinLoc.Code);
            if BinLoc.FindFirst() then begin
                FromLocationCode := BinLoc."Location Code"
            end;
        end;

        InsertItemJournalLine(ItemJournalLineLoc, '', ItemNo, FromLocationCode, FromBinCode, '', '', Abs(Quantity), SerialNumber);

        if PostNow then begin
            ItemJournalLineLoc.SetRecFilter();
            CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post Batch", ItemJournalLineLoc)
        end;
    end;

    /// <summary>
    /// ReclassItemInventory.
    /// </summary>
    /// <param name="ItemNo">Code[20].</param>
    /// <param name="FromLocationCode">Code[10].</param>
    /// <param name="FromBinCode">Code[10].</param>
    /// <param name="ToLocationCode">Code[10].</param>
    /// <param name="ToBinCode">Code[10].</param>
    /// <param name="MakeTargetBinAsDefault">Boolean.</param>
    /// <param name="Quantity">Decimal.</param>
    /// <param name="LotNumbers">Text.</param>
    /// <param name="PostNow">Boolean.</param>
    procedure ReclassItemInventory(ItemNo: Code[20]; FromLocationCode: Code[10]; FromBinCode: Code[10]; ToLocationCode: Code[10]; ToBinCode: Code[10]; MakeTargetBinAsDefault: Boolean; Quantity: Decimal; LotNumbers: Text; PostNow: Boolean)
    var
        BinContentLoc: Record "Bin Content";
        BinLoc: Record Bin;
        ItemJnlBatchLoc: Record "Item Journal Batch";
        ItemJournalLineLoc: Record "Item Journal Line";
        LocationLoc: Record Location;
        CheckDirectPutErr: Label 'Function "Move Bin Content" not possible with location %1. "Directed Put-away and Pick" activated.', Comment = '%1=Location Code';
    begin
        // Buchblatt anhand von Mitarbeiter ermitteln
        GetJnlBatchFromEmployee(ItemJnlBatchLoc, TransferType::"Transfer Jrnl");

        InitNewItemJournalLine(ItemJnlBatchLoc, ItemJournalLineLoc);
        ItemJournalLineLoc.Validate("Entry Type", ItemJournalLineLoc."Entry Type"::Transfer);

        // Wenn kein Lagerortcode gesetzt ist aber ein Bin code,
        // dann lagerortcode ermitteln von Bin-Tabelle
        if (FromLocationCode = '') and (FromBinCode <> '') then begin
            BinLoc.SetRange(Code, FromBinCode);
            if BinLoc.FindFirst() then begin
                FromLocationCode := BinLoc."Location Code"
            end;
        end;

        // Not for locations with activ. "Directed Put-away and Pick"
        LocationLoc.Get(FromLocationCode);
        if LocationLoc."Directed Put-away and Pick" then
            Error(CheckDirectPutErr, FromLocationCode);

        if (ToLocationCode = '') and (ToBinCode <> '') then begin
            BinLoc.Reset();
            BinLoc.SetRange(Code, ToBinCode);
            if BinLoc.FindFirst() then begin
                ToLocationCode := BinLoc."Location Code"
            end;
        end;

        // Neue Lagerplatz als Standard für den Artikel definieren
        if MakeTargetBinAsDefault then begin
            // Reset
            BinContentLoc.Reset();
            BinContentLoc.SetCurrentKey(Default);
            BinContentLoc.SetRange(Default, true);
            BinContentLoc.SetRange("Location Code", FromLocationCode);
            BinContentLoc.SetRange("Item No.", ItemNo);
            BinContentLoc.SetRange("Variant Code", '');
            BinContentLoc.SetFilter("Bin Code", '<>%1', ToBinCode);
            if BinContentLoc.FindFirst() then begin
                BinContentLoc.Validate(Default, false);
                BinContentLoc.Modify(true);
            end;

            // Neuen Default setzen
            BinContentLoc.Reset();
            BinContentLoc.SetCurrentKey(Default);
            BinContentLoc.SetRange(Default, false);
            BinContentLoc.SetRange("Location Code", ToLocationCode);
            BinContentLoc.SetRange("Item No.", ItemNo);
            BinContentLoc.SetRange("Variant Code", '');
            BinContentLoc.SetRange("Bin Code", ToBinCode);
            if BinContentLoc.FindFirst() then begin
                BinContentLoc.Validate(Default, true);
                BinContentLoc.Modify(true);
            end;
        end;

        InsertItemJournalLine(ItemJournalLineLoc, '', ItemNo, FromLocationCode, FromBinCode, ToLocationCode, ToBinCode, Abs(Quantity), LotNumbers);

        if PostNow then begin
            ItemJournalLineLoc.SetRecFilter();
            CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post Batch", ItemJournalLineLoc)
        end;
    end;

    local procedure InitNewItemJournalLine(ItemJnlBatchPar: Record "Item Journal Batch"; var ItemJournalLineVar: Record "Item Journal Line")
    var
        LasItemJournalLineLoc: Record "Item Journal Line";
        NewLine: Integer;
    begin

        // Get Last Journal Line for increment Line No.
        LasItemJournalLineLoc.Reset();
        LasItemJournalLineLoc.SetRange("Journal Template Name", ItemJnlBatchPar."Journal Template Name");
        LasItemJournalLineLoc.SetRange("Journal Batch Name", ItemJnlBatchPar.Name);
        NewLine := 10000;
        if LasItemJournalLineLoc.FindLast() then begin
            NewLine += LasItemJournalLineLoc."Line No.";
        end;

        ItemJournalLineVar.Init();
        ItemJournalLineVar."Journal Template Name" := ItemJnlBatchPar."Journal Template Name";
        ItemJournalLineVar."Journal Batch Name" := ItemJnlBatchPar.Name;
        // SetupNewLine to assign Document No. from No. Series
        ItemJournalLineVar.SetUpNewLine(LasItemJournalLineLoc);

        ItemJournalLineVar.Validate("Journal Template Name", ItemJnlBatchPar."Journal Template Name");
        ItemJournalLineVar.Validate("Journal Batch Name", ItemJnlBatchPar.Name);
        ItemJournalLineVar.Validate("Line No.", NewLine);
        ItemJournalLineVar.Insert(true);
    end;

    local procedure InsertItemJournalLine(var ItemJournalLineVar: Record "Item Journal Line"; DocNo: Code[20]; ItemNo: Code[20]; Location: Code[10]; BinCode: Code[20]; NewLocation: Code[10]; NewBinCode: Code[20]; Quantity: Decimal; LotNumberPar: Text)
    var
        ItemJnlTemplateLoc: Record "Item Journal Template";
        ItemLoc: Record Item;
        ItemTrackingCodeLoc: Record "Item Tracking Code";
        CreateSNInfoLoc: Boolean;
        TrackingQtyLoc: Decimal;
        SourceSubTypeLoc: Integer;
        ItemNotExistErr: Label 'Item with Number "%1" not exist.', Comment = '%1=UserID';
    begin
        ItemJournalLineVar.Validate("Posting Date", WorkDate());

        if DocNo <> '' then begin
            ItemJournalLineVar.Validate("Document No.", DocNo);
        end;

        ItemJournalLineVar.Validate("Item No.", ItemNo);
        ItemJournalLineVar.Validate("Location Code", Location);
        ItemJournalLineVar.Validate("Bin Code", BinCode);

        if NewLocation <> '' then
            ItemJournalLineVar.Validate("New Location Code", NewLocation);

        if NewBinCode <> '' then
            ItemJournalLineVar.Validate("New Bin Code", NewBinCode);

        ItemJournalLineVar.Validate(Quantity, Quantity);
        ItemJournalLineVar.Modify(true);

        if LotNumberPar <> '' then begin
            if not ItemLoc.Get(ItemNo) then begin
                Error(ItemNotExistErr, ItemNo);
            end;

            ItemJnlTemplateLoc.Get(ItemJournalLineVar."Journal Template Name");
            if ItemTrackingCodeLoc.Get(ItemLoc."Item Tracking Code") then begin
                // Artikelbuchblatt
                if ItemJnlTemplateLoc.Type = ItemJnlTemplateLoc.Type::Item then begin

                    if ItemJournalLineVar."Entry Type" = ItemJournalLineVar."Entry Type"::"Positive Adjmt." then begin
                        SourceSubTypeLoc := 2;
                        TrackingQtyLoc := 1;
                        if ItemTrackingCodeLoc."SN Info. Inbound Must Exist" then begin
                            CreateSNInfoLoc := true;
                        end;
                    end;

                    if ItemJournalLineVar."Entry Type" = ItemJournalLineVar."Entry Type"::"Negative Adjmt." then begin
                        SourceSubTypeLoc := 3;
                        TrackingQtyLoc := -1;
                        if ItemTrackingCodeLoc."SN Info. Outbound Must Exist" then begin
                            CreateSNInfoLoc := true;
                        end;
                    end;
                end;

                // Umlagerung
                if ItemJnlTemplateLoc.Type = ItemJnlTemplateLoc.Type::Transfer then begin
                    SourceSubTypeLoc := 4;
                    TrackingQtyLoc := -1;
                end;

                if IsSnTrackingEnabled(ItemTrackingCodeLoc) then begin
                    InsertItemJournalLineSerialNos(ItemJournalLineVar."Journal Template Name", ItemJournalLineVar."Journal Batch Name", SourceSubTypeLoc, ItemNo, Location, ItemJournalLineVar."Line No.", LotNumberPar, TrackingQtyLoc, CreateSNInfoLoc);
                end;

                if IsLotTrackingEnabled(ItemTrackingCodeLoc) then begin
                    InsertItemJournalLineLotNos(ItemJournalLineVar."Journal Template Name", ItemJournalLineVar."Journal Batch Name", SourceSubTypeLoc, ItemNo, Location, ItemJournalLineVar."Line No.", LotNumberPar);
                end;
            end;
        end;
    end;

    local procedure InsertItemJournalLineSerialNos(Template: Code[10]; Batch: Code[10]; SourceSubTypePar: Integer; ItemNo: Code[20]; Location: Code[10]; NewLine: Integer; SerialNos: Text; QtyPar: Integer; CreasteSerialNoInfo: Boolean)
    var
        Item: Record Item;
        ReservEntry: Record "Reservation Entry";
        SerialNoInfoLoc: Record "Serial No. Information";
        LastEntryNo: Integer;
        n: Integer;
        SerialNo: Text;
        SerialNoNew: Text;
    begin
        // Write Item Journal Serial Number.
        Item.Get(ItemNo);
        if (SerialNos <> '') and (Item."Item Tracking Code" <> '') then begin

            // SN-0001;SN-0001-NEU|SN-0002
            repeat
                n := StrPos(SerialNos, '|');
                if n > 0 then begin
                    SerialNo := CopyStr(SerialNos, 1, n - 1);
                    SerialNos := CopyStr(SerialNos, n + 1);
                end
                else begin
                    SerialNo := SerialNos;
                    SerialNos := '';
                end;

                // Seriennummernpaar(alt;neu): SN-0001;SN-0001-NEU
                SerialNoNew := '';
                n := StrPos(SerialNo, ';');
                if n > 0 then begin
                    SerialNoNew := CopyStr(SerialNo, n + 1);
                    SerialNo := CopyStr(SerialNo, 1, n - 1);
                end;

                if (SerialNoNew = '') and (SerialNo <> '') then SerialNoNew := SerialNo;
                if (SerialNo = '') and (SerialNoNew <> '') then SerialNo := SerialNoNew;

                ReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code",
                                          "Source Type", "Source Subtype", "Lot No.", "Serial No.");
                ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Prospect);
                ReservEntry.SetRange("Item No.", ItemNo);
                ReservEntry.SetRange("Variant Code", '');
                ReservEntry.SetRange("Location Code", Location);
                ReservEntry.SetRange("Source Type", DATABASE::"Item Journal Line");
                ReservEntry.SetRange("Source ID", Template);
                ReservEntry.SetRange("Source Batch Name", Batch);
                ReservEntry.SetRange("Source Ref. No.", NewLine);
                ReservEntry.SetRange("Source Subtype", SourceSubTypePar);
                ReservEntry.SetRange("Lot No.", '');
                ReservEntry.SetRange("Serial No.", SerialNo);

                if not ReservEntry.Find('>') then begin
                    Clear(ReservEntry);
                    ReservEntry.LockTable();
                    if ReservEntry.FindLast() then LastEntryNo := ReservEntry."Entry No.";

                    ReservEntry.Init();
                    ReservEntry."Entry No." := LastEntryNo + 1;
                    ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Prospect;
                    ReservEntry."Source Type" := DATABASE::"Item Journal Line";

                    ReservEntry."Source Subtype" := SourceSubTypePar;
                    ReservEntry."Source ID" := Template;
                    ReservEntry."Source Batch Name" := Batch;
                    ReservEntry."Source Prod. Order Line" := 0;
                    ReservEntry."Source Ref. No." := NewLine;
                    ReservEntry.Validate("Quantity (Base)", QtyPar);
                    ReservEntry."Qty. to Handle (Base)" := QtyPar;
                    ReservEntry."Qty. to Invoice (Base)" := QtyPar;
                    ReservEntry.Positive := (ReservEntry."Quantity (Base)" > 0);
                    ReservEntry."Item No." := ItemNo;
                    ReservEntry."Location Code" := Location;
                    ReservEntry."Serial No." := CopysTr(SerialNo, 1, MaxStrLen(ReservEntry."Serial No."));
                    ReservEntry."Creation Date" := WorkDate();
                    ReservEntry."Shipment Date" := WorkDate();
                    ReservEntry."New Serial No." := CopyStr(SerialNoNew, 1, MaxStrLen(ReservEntry."New Serial No."));
                    ReservEntry."Item Tracking" := ReservEntry."Item Tracking"::"Serial No.";
                    ReservEntry."Created By" := Copystr(UserId, 1, MaxStrLen(ReservEntry."Created By"));
                    ReservEntry.Insert();

                    if CreasteSerialNoInfo then begin
                        if not SerialNoInfoLoc.Get(ItemNo, '', SerialNo) then begin
                            SerialNoInfoLoc.Init();
                            SerialNoInfoLoc."Item No." := ItemNo;
                            SerialNoInfoLoc."Variant Code" := '';
                            SerialNoInfoLoc."Serial No." := CopyStr(SerialNo, 1, MaxStrLen(SerialNoInfoLoc."Serial No."));
                            SerialNoInfoLoc.Insert();
                        end;
                    end;

                end;
            until SerialNos = '';
        end;
    end;

    local procedure InsertItemJournalLineLotNos(Template: Code[10]; Batch: Code[10]; SourceSubTypePar: Integer; ItemNo: Code[20]; Location: Code[10]; NewLine: Integer; LotNos: Text)
    var
        Item: Record Item;
        ReservEntry: Record "Reservation Entry";
        Qty: Decimal;
        LastEntryNo: Integer;
        n: Integer;
        LotNo: Text;
        LotPair: Text;
        LotQty: Text;
    begin
        Item.Get(ItemNo);
        if (LotNos <> '') and (Item."Item Tracking Code" <> '') then begin

            // "C-001;2|C-002;1"
            repeat
                n := StrPos(LotNos, '|');
                if n > 0 then begin
                    LotPair := CopyStr(LotNos, 1, n - 1);
                    LotNos := CopyStr(LotNos, n + 1);
                end
                else begin
                    LotPair := LotNos;
                    LotNos := '';
                end;

                if LotPair <> '' then begin
                    n := StrPos(LotPair, ';');
                    LotNo := CopyStr(LotPair, 1, n - 1);
                    LotQty := CopyStr(LotPair, n + 1);
                end;

                ReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code",
                                          "Source Type", "Source Subtype", "Lot No.", "Serial No.");
                ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Prospect);
                ReservEntry.SetRange("Item No.", ItemNo);
                ReservEntry.SetRange("Variant Code", '');
                ReservEntry.SetRange("Location Code", Location);
                ReservEntry.SetRange("Source Type", DATABASE::"Item Journal Line");
                ReservEntry.SetRange("Source Subtype", 4);
                ReservEntry.SetRange("Lot No.", LotNo);
                ReservEntry.SetRange("Serial No.", '');

                if not ReservEntry.Find('>') then begin
                    Clear(ReservEntry);
                    ReservEntry.LockTable();
                    if ReservEntry.FindLast() then LastEntryNo := ReservEntry."Entry No.";

                    Evaluate(Qty, LotQty);
                    Qty := Qty * (-1);

                    ReservEntry.Init();
                    ReservEntry."Entry No." := LastEntryNo + 1;
                    ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Prospect;
                    ReservEntry."Source Type" := DATABASE::"Item Journal Line";
                    ReservEntry."Source Subtype" := SourceSubTypePar;
                    ReservEntry."Source ID" := Template;
                    ReservEntry."Source Batch Name" := Batch;
                    ReservEntry."Source Prod. Order Line" := 0;
                    ReservEntry."Source Ref. No." := NewLine;
                    ReservEntry.Validate("Quantity (Base)", Qty);
                    ReservEntry."Qty. to Handle (Base)" := Qty;
                    ReservEntry."Qty. to Invoice (Base)" := Qty;
                    ReservEntry.Positive := (ReservEntry."Quantity (Base)" > 0);
                    ReservEntry."Item No." := ItemNo;
                    ReservEntry."Location Code" := Location;
                    ReservEntry."Lot No." := CopyStr(LotNo, 1, MaxStrLen(ReservEntry."Lot No."));
                    ReservEntry."Creation Date" := WorkDate();
                    ReservEntry."Shipment Date" := WorkDate();
                    ReservEntry."New Lot No." := CopyStr(LotNo, 1, MaxStrLen(ReservEntry."New Lot No."));
                    ReservEntry."Item Tracking" := ReservEntry."Item Tracking"::"Lot No.";
                    ReservEntry."Created By" := CopyStr(UserId, 1, MaxStrLen(ReservEntry."Created By"));
                    ReservEntry.Insert();
                end;
            until LotNos = '';
        end;
    end;

    local procedure GetJnlBatchFromEmployee(var ItemJnlBatchVar: Record "Item Journal Batch"; JournalTypePar: Option "Item Jnl","Transfer Jrnl")
    var
        ItemJnlBatchLoc: Record "Item Journal Batch";
        ItemJnlTemplateLoc: Record "Item Journal Template";
        WhseEmployLoc: Record "Warehouse Employee";
        BatchNameLoc: Code[10];
        TemplateNameLoc: Code[10];
        WhseEmployeeForUseNotExistErr: Label 'Inventory Employee Setup for user "%1" not found.', Comment = '%1=UserID';
    begin
        ItemJnlTemplateLoc.SetRange(Recurring, false);

        case JournalTypePar of
            JournalTypePar::"Item Jnl":
                ItemJnlTemplateLoc.SetRange(Type, ItemJnlTemplateLoc.Type::Item);
            JournalTypePar::"Transfer Jrnl":
                ItemJnlTemplateLoc.SetRange(Type, ItemJnlTemplateLoc.Type::Transfer);
        end;

        if not ItemJnlTemplateLoc.FindFirst() then begin
            ItemJnlTemplateLoc.Init();
        end;

        WhseEmployLoc.SetRange("User ID", UserId());
        WhseEmployLoc.SetRange(Default, true);
        if WhseEmployLoc.IsEmpty() then begin
            Error(WhseEmployeeForUseNotExistErr, UserId);
        end;

        TemplateNameLoc := ItemJnlTemplateLoc.Name;

        // KUMA Electronic Branche: Branchenanpassung, Der Buchblattname kann auf dem Lagermitarbeiter
        // definiert sein.
        CASE JournalTypePar OF
            JournalTypePar::"Item Jnl":
                BEGIN
                    BatchNameLoc := WhseEmployLoc."PTEARV  Item Jnl Batch";
                END;
            JournalTypePar::"Transfer Jrnl":
                BEGIN
                    BatchNameLoc := WhseEmployLoc."PTEARV Transfer Jnl Batch";
                END;
        END;

        // Wenn kein spezielles Buchblatt gesetzt ist, dann das erste verwenden.
        ItemJnlBatchLoc.SetRange("Journal Template Name", TemplateNameLoc);
        if BatchNameLoc <> '' then begin
            ItemJnlBatchLoc.SetRange(Name, BatchNameLoc);
        end;

        if ItemJnlBatchLoc.FindFirst() then begin
            ItemJnlBatchVar := ItemJnlBatchLoc;
            exit;
        end;

        ItemJnlBatchLoc.Init();
        exit;
    end;

    // local procedure PostItemJournal()
    // var
    //     ItemJournalLineLoc: Record "Item Journal Line";
    //     EmptyItemJnlLineErr: Label 'Item Journal is empty. Journal Template: %1, Batchname: %2';
    //     ItemJnlBatchLoc: Record "Item Journal Batch";
    // begin
    //     // GetJnlBatchFromEmployee(ItemJnlBatchLoc,TransferType::"Item Jnl");
    //     //
    //     // ItemJournalLineLoc.RESET();
    //     // ItemJournalLineLoc.SETRANGE("Journal Template Name", ItemJnlBatchLoc."Journal Template Name");
    //     // ItemJournalLineLoc.SETRANGE("Journal Batch Name", ItemJnlBatchLoc.Name);
    //     // IF ItemJournalLineLoc.FINDFIRST() THEN
    //     //  CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post Batch", ItemJournalLineLoc)
    //     // ELSE
    //     //  ERROR(STRSUBSTNO(EmptyItemJnlLineErr,ItemJnlBatchLoc."Journal Template Name",ItemJnlBatchLoc.Name));
    // end;

    local procedure IsSnTrackingEnabled(ItemTrackingCodePar: Record "Item Tracking Code"): Boolean
    begin

        if ItemTrackingCodePar."SN Specific Tracking" then exit(true);
        if ItemTrackingCodePar."SN Info. Inbound Must Exist" then exit(true);
        if ItemTrackingCodePar."SN Info. Outbound Must Exist" then exit(true);
        if ItemTrackingCodePar."SN Warehouse Tracking" then exit(true);
        if ItemTrackingCodePar."SN Purchase Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Purchase Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Purchase Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Sales Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Sales Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Pos. Adjmt. Inb. Tracking" then exit(true);
        if ItemTrackingCodePar."SN Pos. Adjmt. Outb. Tracking" then exit(true);
        if ItemTrackingCodePar."SN Neg. Adjmt. Inb. Tracking" then exit(true);
        if ItemTrackingCodePar."SN Neg. Adjmt. Outb. Tracking" then exit(true);
        if ItemTrackingCodePar."SN Transfer Tracking" then exit(true);
        if ItemTrackingCodePar."SN Manuf. Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Manuf. Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Assembly Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."SN Assembly Outbound Tracking" then exit(true);

        exit(false);
    end;

    local procedure IsLotTrackingEnabled(ItemTrackingCodePar: Record "Item Tracking Code"): Boolean
    begin

        if ItemTrackingCodePar."Lot Specific Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Info. Inbound Must Exist" then exit(true);
        if ItemTrackingCodePar."Lot Info. Outbound Must Exist" then exit(true);
        if ItemTrackingCodePar."Lot Warehouse Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Purchase Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Purchase Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Sales Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Sales Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Pos. Adjmt. Inb. Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Pos. Adjmt. Outb. Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Neg. Adjmt. Inb. Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Neg. Adjmt. Outb. Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Transfer Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Manuf. Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Manuf. Outbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Assembly Inbound Tracking" then exit(true);
        if ItemTrackingCodePar."Lot Assembly Outbound Tracking" then exit(true);

        exit(false);
    end;

    // local procedure GetLocationCodeFromBin(BinCodePar: Code[20]): Code[10]
    // var
    //     BinLoc: Record Bin;
    // begin
    //     BinLoc.SetRange(BinLoc.Code);
    //     if BinLoc.FindFirst() then
    //         exit(BinLoc."Location Code")
    //     else
    //         exit('');
    // end;
}

