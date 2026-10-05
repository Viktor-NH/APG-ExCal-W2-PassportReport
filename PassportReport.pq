let
    Source = StaffRightReport,

    #"Selected Columns" =
        Table.SelectColumns(
            Table.TransformColumnTypes(
                Source,
                {
                    {"Resource", type text},
                    {"Position ID", type text}
                }
            ),
            {"Date","Resource","Shift","Occupation","Hours","Units","Project","Project#(lf)Description","Category","Category#(lf)Description","Activity#(lf)Description","Task","Piece"}
        ),
    
    #"Renamed Resource" = Table.RenameColumns(#"Selected Columns",{{"Resource", "SourceID"}}),
    #"Filtered Piece = Mile" = Table.SelectRows(#"Renamed Resource", each ([Piece] <> "Miles")),
    #"Replaced StandbyAmt to OnCallPay" = Table.ReplaceValue(#"Filtered Piece = Mile","Standby Amount","On Call Pay",Replacer.ReplaceText,{"Piece"}),
    #"Merged w. DataLake" = Table.NestedJoin(#"Replaced StandbyAmt to OnCallPay", {"SourceID"}, DataLake, {"SourceEmployeeID"}, "DataLake", JoinKind.LeftOuter),
    #"Expanded DataLake" = Table.ExpandTableColumn(#"Merged w. DataLake", "DataLake", {"EmployeeUniqueID"}, {"EmployeeUniqueID"}),
    #"Reordered Columns" = Table.ReorderColumns(#"Expanded DataLake",{"SourceID", "EmployeeUniqueID", "Date", "Shift", "Occupation", "Hours", "Project", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description"}),
    #"Renamed Date" = Table.RenameColumns(#"Reordered Columns",{{"Date", "TransactionDate"}}),

    #"Filtered Shift = HOLIDAY" = Table.SelectRows(
        #"Renamed Date", 
        each Text.Upper(Text.Trim([Shift])) <> "HOLIDAY"        
            ),

    #"Inserted CompanyID" = Table.AddColumn(#"Filtered Shift = HOLIDAY", "CompanyID", each Text.BeforeDelimiter([Project], "-"), type text),
    #"Reordered Columns1" = Table.ReorderColumns(#"Inserted CompanyID",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "Occupation", "Hours", "Project", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description"}),
    #"Merged w. OracleReport" = Table.NestedJoin(#"Reordered Columns1", {"Project"}, OracleReport, {"Trimmed-Project"}, "OracleReport", JoinKind.LeftOuter),
    #"Expanded OracleReport" = Table.ExpandTableColumn(#"Merged w. OracleReport", "OracleReport", {"ORGANIZATION NAME", "TASK NUMBER", "TASK NAME"}, {"ORGANIZATION NAME", "TASK NUMBER", "TASK NAME"}),
    #"Renamed Organization Name" = Table.RenameColumns(#"Expanded OracleReport",{{"ORGANIZATION NAME", "ProjectDepartment"}}),
    #"Reordered Columns2" = Table.ReorderColumns(#"Renamed Organization Name",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "ProjectDepartment", "Project", "Task", "Occupation", "Hours", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description"}),

    #"Added Amount" =
        Table.AddColumn(
            #"Reordered Columns2",
            "Amount",
            each
                if [Hours] <> null
                then [Hours]
                else [Units],
            type number
        ),

    #"Reordered Columns4" = Table.ReorderColumns(#"Added Amount",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "Units", "Hours", "Amount", "ProjectDepartment", "Project", "Task", "Occupation", "Project#(lf)Description", "Piece", "Category", "Category#(lf)Description", "Activity#(lf)Description", "TASK NUMBER", "TASK NAME"}),
    #"Reordered Columns3" = Table.ReorderColumns(#"Reordered Columns4",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "Occupation", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description"}),
    #"Merged w. UnionClassCode_Xref" = Table.NestedJoin(#"Reordered Columns3", {"Occupation"}, UnionClassCode_Xref, {"SourceUnionClassCode"}, "UnionClassCode_Xref", JoinKind.LeftOuter),
    #"Expanded UnionClassCode_Xref" = Table.ExpandTableColumn(#"Merged w. UnionClassCode_Xref", "UnionClassCode_Xref", {"UnionClassCode"}, {"UnionClassCode_Xref.UnionClassCode"}),
    #"Renamed Columns4" = Table.RenameColumns(#"Expanded UnionClassCode_Xref",{{"UnionClassCode_Xref.UnionClassCode", "JobClass"}}),
    #"Reordered Columns5" = Table.ReorderColumns(#"Renamed Columns4",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "JobClass", "Occupation", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description"}),
    #"Removed Columns1" = Table.RemoveColumns(#"Reordered Columns5",{"Occupation"}),

    #"Merged w. JobCode_Xref" = Table.NestedJoin(#"Removed Columns1", {"EmployeeUniqueID"}, JobCode_Xref, {"EmployeeUniqueID"}, "JobCode_Xref", JoinKind.LeftOuter),

    #"Expanded JobCode_Xref" = Table.ExpandTableColumn(#"Merged w. JobCode_Xref", "JobCode_Xref", {"JobCode"}, {"JobCode_Xref.JobCode"}),

    #"Merged w. HCMJobCode_Xref" = Table.NestedJoin(#"Expanded JobCode_Xref", {"JobCode_Xref.JobCode"}, HCMJobCode_Xref, {"JobCode"}, "HCMJobCode_Xref", JoinKind.LeftOuter),

    #"Expanded HCMJobCode_Xref" = Table.ExpandTableColumn(#"Merged w. HCMJobCode_Xref", "HCMJobCode_Xref", {"ShortDescription"}, {"HCMJobCode_Xref.ShortDescription"}),

    #"Renamed Columns5" = Table.RenameColumns(#"Expanded HCMJobCode_Xref",{{"HCMJobCode_Xref.ShortDescription", "JobType"}}),

    #"Reordered Columns6" = Table.ReorderColumns(#"Renamed Columns5",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    
    #"Added WorkRule" =
        Table.AddColumn(
            #"Reordered Columns6",
            "WorkRule",
            each "",     // Business has requested WorkRule be blank for now
            type text
        ),

    /*
    Previous WorkRule logic retained for future use:

    #"Added WorkRule" =
        Table.AddColumn(
            #"Reordered Columns6",
            "WorkRule",
            each
                if [Shift] = "1DT" then "EXCEPTION DOUBLE TIME"
                else if [Shift] = "1OT" then "EXCEPTION OVERTIME"
                else if [Shift] = "1ST" then "EXCEPTION STRAIGHT TIME"

                else if [Shift] = "2DT" then "EXCEPTION DOUBLE TIME S2"
                else if [Shift] = "2OT" then "EXCEPTION OVERTIME S2"
                else if [Shift] = "2ST" then "EXCEPTION STRAIGHT TIME S2"

                else if [Shift] = "3DT" then "EXCEPTION DOUBLE TIME S3"
                else if [Shift] = "3OT" then "EXCEPTION OVERTIME S3"
                else if [Shift] = "3ST" then "EXCEPTION STRAIGHT TIME S3"

                else "",
            type text
        ),
    */
    #"Reordered WorkRule" = Table.ReorderColumns(#"Added WorkRule",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "WorkRule", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    #"Replaced Value" = Table.ReplaceValue(#"Reordered WorkRule","","Hours",Replacer.ReplaceValue,{"Piece"}),

    #"Inserted ShiftType" = Table.AddColumn(#"Replaced Value", "ShiftType", each "5X8", type text),

    #"Reordered ShiftType" = Table.ReorderColumns(#"Inserted ShiftType",{"SourceID", "EmployeeUniqueID", "TransactionDate", "Shift", "ShiftType", "WorkRule", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    #"Renamed Shift" = Table.RenameColumns(#"Reordered ShiftType",{{"Shift", "StaffRight - Shift"}}),

    #"Added Shift" = Table.AddColumn(#"Renamed Shift", "Shift", each Text.Select([#"StaffRight - Shift"], {"1".."9"})),

    #"Changed Shift" = Table.TransformColumnTypes(#"Added Shift",{{"Shift", Int64.Type}}),

    #"Reordered Shift" = Table.ReorderColumns(#"Changed Shift",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", "WorkRule", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    #"Added TaxLocation" = Table.AddColumn(#"Reordered Shift", "TaxLocation", each "On site"),

    #"Reordered TaxLocation" = Table.ReorderColumns(#"Added TaxLocation",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", "WorkRule", "CompanyID", "ProjectDepartment", "Project", "Task", "Amount", "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    #"Changed TaxLocation Type" = Table.TransformColumnTypes(#"Reordered TaxLocation",{{"TaxLocation", type text}}),

    #"Inserted UKGIndirectActivity" =
        Table.AddColumn(
            #"Changed TaxLocation Type",
            "UKGIndirectActivity",
            each
                if [ProjectDepartment] = null
                    or Text.Trim(Text.From([ProjectDepartment])) = ""
                then "INDIRECT"
                else "",
            type text
        ),
    
    #"Reordered UKGIndirectActivity" = Table.ReorderColumns(#"Inserted UKGIndirectActivity",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", "WorkRule", "CompanyID", "ProjectDepartment", "UKGIndirectActivity", "Project", "Task", "Amount", "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}),
    
    #"Added UKGPayCodeDesc" =
        Table.AddColumn(
            #"Reordered UKGIndirectActivity",
            "UKGPayCodeDesc",
                each
                    let
                        ShiftValue =
                            if [#"StaffRight - Shift"] = null then
                                ""
                            else
                                Text.Trim(Text.From([#"StaffRight - Shift"]))
                    in

                        if ShiftValue = "" and [Piece] = "On Call Pay" then "ONCAL"
                        else if ShiftValue = "" and [Piece] = "Subsistence NT" then "SubNT"
                        else if ShiftValue = "" and [Piece] = "Subsistence" then "SubTa"
                        else if ShiftValue = "Floating Holiday" then "Absn-Floating"
                        else if ShiftValue = "Funeral Pay" then "JURY"
                        else if ShiftValue = "Holiday" then "HOLDY"
                        else if ShiftValue = "MI ESTA" then "Absn-Sick Hours"
                        else if ShiftValue = "MN ESST" then "Absn-Sick Hours"
                        else if ShiftValue = "NE Erned Sick" then "Absn-Sick Hours"
                        else if ShiftValue = "PTO" then "Absn-PTO"
                        else if ShiftValue = "Unpaid Leave" then "Unpaid Leave"
                        else if ShiftValue = "Unpaid Time" then "UNPAID"
                        else "",
                type text
            ),

    #"Added TransType" =
        Table.AddColumn(
            #"Added UKGPayCodeDesc",
            "TransType",
            each
                if List.Contains(
                    {"1ST", "1OT", "1DT",
                     "2ST", "2OT", "2DT",
                     "3ST", "3OT", "3DT"},
                    Text.Trim(Text.From([#"StaffRight - Shift"]))
                )
                then "Hours"
                else "PayCodeEdit",
            type text
        ),

    #"Reordered UKGPayCodeDesc" = Table.ReorderColumns(#"Added TransType",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", 
                                                                            "WorkRule", "CompanyID", "ProjectDepartment", "UKGIndirectActivity", "Project", "Task", "TransType", "Amount", "UKGPayCodeDesc", 
                                                                            "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}
                                                    ),
    
    #"Added PayCodeType" = Table.AddColumn(
        #"Reordered UKGPayCodeDesc", 
        "PayCodeType", 
        each 
            if [Piece] = "Subsistence" then "MONEY" 
            else if [Piece] = "Subsistence NT" then "MONEY"
            else if [Piece] = "On Call Pay" then "MONEY" 
            else "HOUR",
        type text
            ),

    #"Reordered PayCodeType" = Table.ReorderColumns(#"Added PayCodeType",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", 
                                                                            "WorkRule", "CompanyID", "ProjectDepartment", "UKGIndirectActivity", "Project", "Task", "TransType", "Amount", "PayCodeType", "UKGPayCodeDesc", 
                                                                            "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}
                                                    ),
    
    #"Added WorkType" =
        Table.AddColumn(#"Reordered PayCodeType", "WorkType", each if [ProjectDepartment] = null
                    or Text.Trim(Text.From([ProjectDepartment])) = ""
                then "Indirect"
                else "Project"),

    #"Reordered WorkType" = Table.ReorderColumns(#"Added WorkType",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", 
                                                                    "WorkRule", "CompanyID", "ProjectDepartment", "WorkType", "UKGIndirectActivity", "Project", "Task", "TransType", "Amount", "PayCodeType", "UKGPayCodeDesc", 
                                                                    "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}
                                                ),
    
    #"Added ProjectClean" =
        Table.AddColumn(
            #"Reordered WorkType",
            "ProjectClean",
            each
                if [ProjectDepartment] = null
                    or Text.Trim(Text.From([ProjectDepartment])) = ""
                then null
                else [Project],
            type text
        ),

    #"Removed Project" =
        Table.RemoveColumns(
            #"Added ProjectClean",
            {"Project"}
        ),

    #"Renamed ProjectClean" =
        Table.RenameColumns(
            #"Removed Project",
            {{"ProjectClean","Project"}}
        ),
    #"Reordered ProjectClean" = Table.ReorderColumns(#"Renamed ProjectClean",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", 
                                                                            "WorkRule", "CompanyID", "ProjectDepartment", "Piece", "WorkType", "UKGIndirectActivity", "Project", 
                                                                            "Task", "TASK NUMBER", "TASK NAME", "TransType", "Amount", "PayCodeType", "UKGPayCodeDesc", "TaxLocation", 
                                                                            "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}
                                                    ),
                                                    
    #"Renamed Columns" = Table.RenameColumns(#"Reordered ProjectClean",{{"TASK NUMBER", "TaskNumber"}, {"TASK NAME", "TaskName"}}),

    #"Added ClearProjectFields" =
        Table.AddColumn(
            #"Renamed Columns",
            "ClearProjectFields",
            each
                [TransType] = "PayCodeEdit"
                    and not List.Contains(
                        {"SubTa", "SubNT"},
                        [UKGPayCodeDesc]
                    ),
            type logical
        ),

    #"Added ProjectClean2" =
        Table.AddColumn(
            #"Added ClearProjectFields",
            "ProjectClean",
            each
                if [ClearProjectFields]
                then null
                else [Project],
            type text
        ),

    #"Added TaskClean" =
        Table.AddColumn(
            #"Added ProjectClean2",
            "TaskClean",
            each
                if [ClearProjectFields]
                then null
                else [Task],
            type text
        ),

    #"Added TaskNumberClean" =
        Table.AddColumn(
            #"Added TaskClean",
            "TaskNumberClean",
            each
                if [ClearProjectFields]
                then null
                else [TaskNumber],
            type text
        ),

    #"Removed Original Project Fields" =
        Table.RemoveColumns(
            #"Added TaskNumberClean",
            {
                "Project",
                "Task",
                "TaskNumber"
            }
        ),

    #"Renamed Clean Project Fields" =
        Table.RenameColumns(
            #"Removed Original Project Fields",
            {
                {"ProjectClean", "Project"},
                {"TaskClean", "Task"},
                {"TaskNumberClean", "TaskNumber"}
            }
        ),

    #"Removed ClearProjectFields" =
        Table.RemoveColumns(
            #"Renamed Clean Project Fields",
            {"ClearProjectFields"}
        ),

    #"Reordered ProjectClean2" = 
        Table.ReorderColumns(
            #"Removed ClearProjectFields",{"SourceID", "EmployeeUniqueID", "TransactionDate", "StaffRight - Shift", "Shift", "ShiftType", 
                                    "WorkRule", "CompanyID", "ProjectDepartment", "Piece", "WorkType", "UKGIndirectActivity", 
                                    "Project", "Task", "TaskNumber", "TaskName", "TransType", "Amount", "PayCodeType", "UKGPayCodeDesc", 
                                    "TaxLocation", "JobClass", "JobType", "Project#(lf)Description", "Category", "Category#(lf)Description", "Activity#(lf)Description", "JobCode_Xref.JobCode"}
        ),

    #"Updated Project" = Table.TransformColumns(
        #"Reordered ProjectClean2",
        {
            {"Project", 
            each 
                if _ = null or Text.Trim(Text.From(_)) = "" then null 
                else "L" & Text.From(_), 
                type text}
        }
    ),

    // ---------------------------------------------------------
    // 1. Independent source and lookup counts
    // These counts should not be compared with one another.
    // ---------------------------------------------------------
    SourceAudit =
        #table(
            type table
            [
                Category = text,
                Step = text,
                RowCount = Int64.Type,
                PreviousCount = nullable number,
                Difference = nullable number,
                Status = text
            ],
            {
                {
                    "Source",
                    "StaffRight PayrollHour",
                    Table.RowCount(StaffRightReport),
                    null,
                    null,
                    "SOURCE COUNT"
                },
                {
                    "Source",
                    "DataLake",
                    Table.RowCount(DataLake),
                    null,
                    null,
                    "SOURCE COUNT"
                },
                {
                    "Source",
                    "OracleReport",
                    Table.RowCount(OracleReport),
                    null,
                    null,
                    "SOURCE COUNT"
                },
                {
                    "Xref",
                    "UnionClassCode_Xref",
                    Table.RowCount(UnionClassCode_Xref),
                    null,
                    null,
                    "Xref COUNT"
                },
                {
                    "Xref",
                    "JobCode_Xref",
                    Table.RowCount(JobCode_Xref),
                    null,
                    null,
                    "Xref COUNT"
                },
                {
                    "Xref",
                    "HCMJobCode_Xref",
                    Table.RowCount(HCMJobCode_Xref),
                    null,
                    null,
                    "Xref COUNT"
                }
            }
        ),

    // ---------------------------------------------------------
    // 2. Sequential transformation counts
    // Difference is meaningful within this section.
    // ---------------------------------------------------------
    TransformationCounts =
        #table(
            type table
            [
                Category = text,
                Step = text,
                RowCount = Int64.Type
            ],
            {
                {
                    "Transformation",
                    "Initial StaffRight Rows",
                    Table.RowCount(#"Replaced StandbyAmt to OnCallPay")
                },

                {
                    "Transformation",
                    "Merged w. DataLake",
                    Table.RowCount(#"Merged w. DataLake")
                },
                {
                    "Transformation",
                    "Expanded DataLake",
                    Table.RowCount(#"Expanded DataLake")
                },
                {
                    "Filter",
                    "Before Holiday Filter",
                    Table.RowCount(#"Renamed Date")
                },
                {
                    "Filter",
                    "After Holiday Filter",
                    Table.RowCount(#"Filtered Shift = HOLIDAY")
                },
                {
                    "Transformation",
                    "Merged w. OracleReport",
                    Table.RowCount(#"Merged w. OracleReport")
                },
                {
                    "Transformation",
                    "Expanded OracleReport",
                    Table.RowCount(#"Expanded OracleReport")
                },
                {
                    "Transformation",
                    "Merged w. UnionClassCode_Xref",
                    Table.RowCount(#"Merged w. UnionClassCode_Xref")
                },
                {
                    "Transformation",
                    "Expanded UnionClassCode_Xref",
                    Table.RowCount(#"Expanded UnionClassCode_Xref")
                },
                {
                    "Transformation",
                    "Merged w. JobCode_Xref",
                    Table.RowCount(#"Merged w. JobCode_Xref")
                },
                {
                    "Transformation",
                    "Expanded JobCode_Xref",
                    Table.RowCount(#"Expanded JobCode_Xref")
                },
                {
                    "Transformation",
                    "Merged w. HCMJobCode_Xref",
                    Table.RowCount(#"Merged w. HCMJobCode_Xref")
                },
                {
                    "Transformation",
                    "Expanded HCMJobCode_Xref",
                    Table.RowCount(#"Expanded HCMJobCode_Xref")
                },
                {
                    "Transformation",
                    "Final",
                    Table.RowCount(#"Updated Project")
                }
            }
        ),

    AddIndex =
        Table.AddIndexColumn(
            TransformationCounts,
            "Index",
            0,
            1,
            Int64.Type
        ),

    AddPreviousCount =
        Table.AddColumn(
            AddIndex,
            "PreviousCount",
            each
                if [Index] = 0 then
                    null
                else
                    AddIndex[RowCount]{[Index] - 1},
            type nullable number
        ),

    AddDifference =
        Table.AddColumn(
            AddPreviousCount,
            "Difference",
            each
                if [PreviousCount] = null then
                    null
                else
                    [RowCount] - [PreviousCount],
            type nullable number
        ),

    AddStatus =
        Table.AddColumn(
            AddDifference,
            "Status",
            each
                if [Difference] = null then "START"
                else if [Category] = "Filter" and [Difference] < 0 then "FILTERED OUT"
                else if [Category] = "Filter" and [Difference] = 0 then "NO ROWS FILTERED"
                else if [Category] = "Filter" and [Difference] > 0 then "CHECK: FILTER ADDED ROWS"
                else if [Difference] = 0 then "OK"
                else if Text.StartsWith([Step], "Expanded") and [Difference] > 0 then "CHECK: DUPLICATE MATCHES"
                else if [Difference] > 0 then "ROWS ADDED"
                else "ROWS REMOVED",
            type text
        ),

    TransformationAudit =
        Table.RemoveColumns(
            AddStatus,
            {"Index"}
        ),

    Audit =
        Table.Combine(
            {
                SourceAudit,
                TransformationAudit
            }
        ),

    Output =
        [
            Final = #"Updated Project",
            QC = Audit
        ]
in
    Output