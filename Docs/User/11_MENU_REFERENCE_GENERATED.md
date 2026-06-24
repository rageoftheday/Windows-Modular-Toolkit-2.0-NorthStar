# Generated Menu Reference

This file was generated from PowerShell scripts in the release build. It is useful for verifying menu paths and support documentation.

## Framework/Add_Module_Builder/run.ps1
Options:
- [$($i+1)] $($Items[$i])
- [N] None
- [C] Custom
- [Enter] $Default
- [Enter] Accept suggested: $($Default -join ', ')
- [$($i+1)] $($items[$i])
- [B] Back
- [$($items.Count)] $v
- [M] Browse All Subcategories
- [Enter] Continue anyway
- [E] Return to paste editor
- [C] Cancel
- [C] Cancel module creation
- [A] Create anyway
- [Enter] Continue
- [E] Return to module source selection
- [P] Return to paste editor
- [T] Use Blank Template instead
- [1] Open Module Folder
- [2] Modify PowerShell Script
- [3] Modify Batch Script
- [$($i+1)] $($modules[$i].Name)
- [C] Choose folder manually
- [1] Replace file by pasting content
- [2] Append pasted content
- [3] Open in Notepad
- [4] Open module folder
- [5] Validate Script
- [6] Add/Repair standard header
- [1] Paste PowerShell Script
- [2] Import Existing Script
- [3] Use Blank Template
- [$($i+1)] $rel
- [M] Manual path
- [R] Rescan
- [1] Enter installer path manually
- [2] Open Incoming folder
- [$($i+1)] $label
- [C] Custom arguments
- [?] Help
- [1] Create Empty Module Template
- [4] Create From Installer
- [5] Create From Website
- [6] Open Modules Folder
- [7] Open Module Blanks Folder

## Framework/Advanced_Search_Tools/run.ps1
Headers: ADVANCED SEARCH TOOLS
Options:
- [B] Back
- [$Index] $($Result.name)
- [S] Search Again

## Framework/Audit_Center/run.ps1
Options:
- [1] Module Inventory Report
- [2] Deleted Items History
- [3] Duplicate Tool Scanner
- [4] Legacy Menu Auditor
- [5] Module Rationalization Engine
- [6] Migrated Module Cleanup Manager
- [7] Export Center
- [B] Back

## Framework/Backup_File_Cleanup/run.ps1
Headers: BACKUP FILE CLEANUP
Options:
- [D] Delete backup files
- [B] Back

## Framework/Bootstrap_Integration_Manager/run.ps1
Options:
- [B] Back

## Framework/Capability_Audit/run.ps1
Options:
- [$($i+1)] $($Families[$i])
- [B] Back
- [1] Run Capability Audit
- [2] View Summary
- [3] Review Families
- [4] Open Consolidation Report
- [5] Open Audit JSON

## Framework/Category_Architecture_Manager/run.ps1
Options:
- [MOVED] $($Module.Name) -> $Suggested
- [1] Show Category Stats
- [2] Analyze Suggested Moves
- [3] Apply Suggested Moves
- [B] Back

## Framework/Category_Browser/run.ps1
Headers: BROWSE MODULES
Options:
- [B] Back

## Framework/Category_Manager/run.ps1
Options:
- [B] Back
- [N] New Category
- [Y] Yes
- [N] No
- [!] $Warn
- [1] Create Category
- [2] Rename Category
- [3] Merge Categories
- [4] Move Modules
- [5] Delete Category
- [6] View Categories
- [7] Category Health
- [8] Category History
- [9] Debug Log / Diagnostics

## Framework/Compatibility_Center/run.ps1
Options:
- [B] Back
- [O] Open Report
- [1] Run Compatibility Check
- [2] Detailed Results
- [3] Generate Compatibility Report

## Framework/Core_Integration_Manager/run.ps1
Options:
- [B] Back

## Framework/Dashboard_Health_Center/run.ps1
Options:
- [$i] Low disk space on $($d.DeviceID)
- [1] Open Health Center
- [2] Open Smart Recommendations
- [3] Open Validation Center
- [R] Refresh
- [B] Back

## Framework/Deleted_Items_History/run.ps1
Headers: DELETED ITEMS HISTORY
Options:
- [$Index] $Line
- [C] Clear History
- [B] Back

## Framework/Download_Manager/run.ps1
Options:
- [PASS] Downloaded to $OutFile

## Framework/Dry_Run_Module_Validator/run.ps1
Headers: DRY RUN MODULE VALIDATOR
Options:
- [PASS] No blocking dry-run errors found.
- [B] Back

## Framework/Enhanced_Add_Tool_Wizard/run.ps1
Headers: SELECT CATEGORY, SELECT RISK LEVEL, KEYWORDS, DEPENDENCIES, CREATE NEW TOOL, CONFIRM NEW TOOL, ENHANCED ADD TOOL WIZARD
Options:
- [B] Back / Cancel
- [$($i+1)] $($Categories[$i])
- [N] New Category
- [1] Safe
- [2] Moderate
- [3] High Impact
- [Y] True
- [N] False
- [Y] Create Tool
- [CREATED] $ToolName
- [1] Create New Tool
- [2] Open Toolkit Registry Builder
- [3] Open Dry Run Validator
- [4] Open Modules Folder
- [B] Back

## Framework/Enhanced_Dashboard/run.ps1
Headers: ENHANCED DASHBOARD
Options:
- [PASS] No major recommendations at this time.
- [$Index] $($Item.Issue)
- [B] Back

## Framework/Export_Center/run.ps1
Headers: EXPORT CENTER

## Framework/Framework_Integrity_Check/run.ps1
Headers: FRAMEWORK INTEGRITY CHECK
Options:
- [B] Back

## Framework/Framework_Repair/run.ps1
Options:
- [B] Back
- [O] Open Report
- [1] Run Framework Repair
- [2] Check Only
- [3] Detailed Results
- [4] Generate Repair Report
- [Y] Yes, run repair

## Framework/GitHub_Puller/run.ps1
Options:
- [A] Download All Assets
- [B] Back

## Framework/Header_Normalization_Manager/run.ps1
Options:
- [B] Back

## Framework/How_To_Guide/run.ps1
Headers: HOW TO GUIDE
Options:
- [B] Back

## Framework/Installer_Repository_Builder/run.ps1
Options:
- [CREATED] $Rel
- [PASS] No legacy repository folders found.

## Framework/Legacy_Menu_Auditor/run.ps1
Options:
- [1] Scan Legacy BAT Files
- [2] Export Full Audit Report
- [3] Show Hub Candidates
- [4] Show Broken Menu References
- [B] Back
- [PASS] Audit report exported:

## Framework/Menu_Consistency_Normalizer/run.ps1
Options:
- [UPDATED] $Relative
- [B] Back

## Framework/Metadata_Description_Fixer/run.ps1
Options:
- [SKIP] Invalid JSON: $($File.FullName)
- [FIXED] $($Json.name)
- [B] Back

## Framework/Metadata_Library_Manager/run.ps1
Options:
- [$($i+1)] $($vals[$i])
- [B] Back
- [A] Add
- [D] Delete
- [$($i+1)] $($pairs[$i].Category) -> $($pairs[$i].Value)
- [C] Core (Read Only)
- [U] User (Editable)
- [$($i+1)] $($Items[$i].extension) -> $($Items[$i].type) ($($Items[$i].format))
- [$n] $($Items[$i].extension) -> $($Items[$i].type) ($($Items[$i].format))
- [$n] $($Items[$i].name)
- [1] Restore Previous Backup
- [2] Restore Older Backup
- [3] Restore Framework Defaults
- [4] Create Manual Backup

## Framework/Metadata_Manager/run.ps1
Options:
- [1] Metadata Repair Tool
- [2] Fix / Improve Descriptions
- [3] Review Risk Classification
- [4] Normalize Headers
- [5] Normalize Menu Consistency
- [6] Category Architecture Review
- [B] Back

## Framework/Metadata_Repair_Tool/run.ps1
Options:
- [B] Back

## Framework/Migrated_Module_Cleanup_Manager/run.ps1
Options:
- [1] Audit Migrated Modules
- [2] Export Cleanup Report
- [3] Apply Safe Metadata Fixes
- [4] Show Weak Metadata Summary
- [B] Back
- [PASS] Report exported:
- [FIXED] $($Module.Name)

## Framework/Module_Audit/run.ps1
Options:
- [PASS] $Message
- [$Status] $Message
- [E] Edit failed module run.ps1 in Notepad
- [F] Open failed module folder
- [Enter] Continue
- [$($i+1)] $($failed[$i].Module)
- [B] Back

## Framework/Module_Health_Check/run.ps1
Options:
- [PASS] $Message
- [$Status] $Message
- [E] Edit failed module run.ps1 in Notepad
- [F] Open failed module folder
- [Enter] Continue
- [$($i+1)] $($failed[$i].Module)
- [B] Back

## Framework/Module_Manager/run.ps1
Options:
- [$i] $Icon $($Group.Name) ($($Group.Count))
- [$Number] $Label (Current)
- [$Number] $Label
- [$Number] $($Matches[$i])

## Framework/Module_Rationalization_Engine/run.ps1
Options:
- [1] Full Classification Audit
- [2] Show KEEP Modules
- [3] Show REMOVE Candidates
- [4] Show REBUILD Candidates
- [5] Show REVIEW Candidates
- [6] Export Classification Report
- [B] Back
- [PASS] Report exported:

## Framework/Quick_Actions_Hub/run.ps1
Headers: QUICK ACTIONS HUB
Options:
- [1] Post-change validation
- [2] Stability check
- [3] Usage review
- [4] Export snapshot
- [5] Smart Recommendations
- [6] Tool Chain Runner
- [B] Back

## Framework/RC1_Validation/run.ps1
Options:
- [B] Back
- [O] Open Report
- [1] Run Full RC Audit
- [2] View Audit Results
- [3] Export RC Audit Report

## Framework/Registry_Manager/run.ps1
Options:
- [1] Toolkit Registry Builder
- [2] Rebuild Toolkit Cache
- [3] Bootstrap Integration Manager
- [4] Core Integration Manager
- [5] Framework Integrity Check
- [B] Back

## Framework/Release_Notes/run.ps1
Headers: RELEASE NOTES

## Framework/Remove_Tool_Wizard/run.ps1
Headers: DELETE MODULE - CATEGORIES, DELETE MODULE - SEARCH, DELETE MODULE, REMOVE MODULE WIZARD
Options:
- [B] Back
- [$i] $Icon $($Group.Name) ($($Group.Count))
- [1] Browse By Category
- [2] Search Modules
- [3] List All Modules

## Framework/Repository_Manager/run.ps1
Options:
- [N] New Custom Type
- [B] Back
- [1] Software
- [2] Packages
- [3] Scripts
- [4] Documents
- [5] Archives
- [6] Disk Images
- [7] Custom
- [N] None
- [C] Custom
- [A] Import Script
- [1] Browse Scripts
- [2] Import Script From Incoming
- [3] Create Module From Script
- [4] Script Report
- [5] Open Scripts Repository
- [6] Script Help
- [A] Import All Scripts
- [1] Open Folder
- [2] Open Script
- [3] Create Module
- [4] Delete Script Record
- [V] View Script List
- [A] Import Document
- [1] Browse Documents
- [2] Import Documents From Incoming
- [3] Document Report
- [4] Open Documents Repository
- [5] Document Help
- [A] Import All Documents
- [2] Open Document
- [3] Delete Document Record
- [V] View Document List
- [1] Software Report
- [2] Script Report
- [4] Package List
- [5] Archive List
- [6] Disk Image List
- [7] Custom List
- [F] Full Repository Report
- [A] Accept Recommendation
- [1] Choose Another Destination
- [C] Create Custom Destination
- [1] Overwrite
- [2] Keep Both
- [3] Set Incoming as Current, Keep Old as Previous
- [4] Import as Specific Version Only
- [5] Skip
- [A] Process Supported Items
- [V] View Software List
- [M] Missing Software Report
- [MISSING] $($R.name)
- [1] Open Offline Software Deployment Guide
- [2] Open Offline Supported Formats Guide
- [3] Winget Search Helper
- [4] Open Winstall.app
- [5] Open Microsoft Winget Documentation
- [1] Search Winget Repository
- [2] List Installed Apps

## Framework/Risk_Classification_Assistant/run.ps1
Options:
- [1] Analyze Risk Suggestions
- [2] Apply Suggested Risk Fixes
- [3] Apply Suggested Subcategories
- [4] Full Metadata Intelligence Pass
- [B] Back
- [FIXED] $($_.Name) -> $Suggested
- [UPDATED] $($_.Name)

## Framework/Search_Foundation/run.ps1
Options:
- [$Number] $($R.name)

## Framework/Smart_Module_Validator/run.ps1
Options:
- [B] Back

## Framework/Smart_Recommendations_Engine/run.ps1
Headers: SMART RECOMMENDATIONS ENGINE, RUN RECOMMENDED TOOLS
Options:
- [SKIP] Empty tool reference.
- [MISSING] $RunPath
- [SKIP] Tool not found: $ToolName
- [PASS] No issues found.
- [$Index] $($Recommendation.Issue)
- [number] Pick a recommendation
- [A] Run ALL tools from all recommendations
- [C] Run BEST suggested chain
- [R] Refresh recommendations
- [B] Back
- [$ToolIndex] $($Tool.name)
- [missing] $ToolName
- [A] Run all listed tools
- [C] Run suggested chain

## Framework/Test_Log_Viewer/run.ps1
Options:
- [O] Open Log
- [C] Clear Log
- [F] Open Logs Folder
- [B] Back

## Framework/Tool_Chain_Runner/run.ps1
Headers: TOOL CHAIN - $ChainName, TOOL CHAIN RUNNER
Options:
- [MISSING] $RunPath
- [FOUND] $($Tool.name)
- [MISSING] $Name
- [Y] Yes
- [N] No
- [1] Repair Pack
- [2] Cleanup Pack
- [3] Network Pack
- [4] Toolkit Health Pack
- [B] Back

## Framework/Tool_Manager/run.ps1
Options:
- [1] Add Module Builder
- [2] Modify Tool Metadata
- [3] Category Manager
- [4] Module Manager
- [5] Remove/Delete Module
- [B] Back

## Framework/Tool_Modifier/run.ps1
Headers: ADD $Title, REMOVE $Title
Options:
- [$i] $Icon $($Group.Name) ($($Group.Count))
- [$Number] $Label (Current)
- [$($i+1)] $($Matches[$i])
- [$($i+1)] $Label (Current)
- [$($i+1)] $($Items[$i])
- [$($i+1)] $($Suggested[$i])

## Framework/Toolkit_Dashboard/run.ps1
Options:
- [R] Refresh
- [B] Back

## Framework/Toolkit_Health_Center/run.ps1
Headers: TOOLKIT HEALTH CENTER
Options:
- [PASS] Registry exists.
- [PASS] Modules folder exists.
- [PASS] Core folder exists.
- [PASS] Logs folder exists.
- [B] Back

## Framework/Toolkit_Registry/run.ps1
Options:
- [PASS] Registry JSON valid
- [PASS] Registry cache deleted.
- [1] Build Registry
- [2] View Registry
- [3] Registry Statistics
- [4] Validate Registry
- [5] Delete Registry Cache
- [B] Back

## Framework/Validation_Center/run.ps1
Options:
- [1] Quick Validation
- [2] Dry Run Validation
- [3] Runtime Validation
- [4] Smart Validation
- [5] Static Code Analysis
- [6] Framework Integrity Check
- [B] Back

## Framework/Workspace/run.ps1
Options:
- [$Index] $Label
- [C] $CustomLabel
- [$Index] $Mark $Name
- [$Index] $Name
- [$Index] Custom
- [$Index] $($Item.Name)
- [$Index] $($File.Name) -> Suggested: $Suggested

## Toolkit.ps1
Headers: REGISTRY NOT FOUND, IMPORTANT TOOLS, IMPORTANT - $SelectedCategory, VALIDATORS AND HEALTH, TOOLKIT MAINTENANCE, DIAGNOSTICS EXPORTED, DIAGNOSTICS EXPORT FAILED, HELP & SUPPORT
Options:
- [$Index] $Category ($Count)
- [B] Back
- [1] Quick Start
- [2] Framework Concepts
- [3] Troubleshooting
- [4] Metadata Reference
- [5] Open Logs Folder
- [6] Export Diagnostics
- [7] Open Toolkit Folder
- [8] Project Information
- [9] Open GitHub Repository
- [10] Open Discussions & Feedback
- [1] Validation Center
- [2] Tool Manager
- [3] Category Manager
- [4] Dashboard & Health
- [5] Registry Manager
- [6] Metadata Engine
- [7] Search Foundation
- [7] Audit Center
- [9] Compatibility Center
- [10] Framework Repair
- [11] Release Candidate Validation
- [12] Repository Manager
- [13] Validation & Health
- [14] Backup & Recovery
- [15] Compatibility & Requirements
- [16] Builders
- [17] Configuration
- [18] Import & Export
- [19] Audit & Reporting
- [20] Support & Documentation
- [23] Development & Testing
- [21] Search Toolkit Management Tools
- [22] View Test Log
- [24] Capability Audit
- [S] Search Again
- [A] Add Favorite
- [R] Remove Favorite
- [1] Repair Now
- [2] Continue Anyway
- [1] Search Everything
- [2] Browse Module Categories
- [3] Browse Repository
- [1] Browse by Category
- [2] All Modules
- [$($i + 1)] $Category ($Count)
- [$Index] $DisplayName$AdminText
- [1] Dashboard Overview
- [2] Smart Recommendations
- [1] Generate All Repository / Detection QA Files
- [2] Remove Repository QA Pack
- [3] Clear Repository Test Data
- [1] Framework Integrity Check
- [2] Toolkit Health Center
- [3] Compatibility Center
- [4] Framework Repair
- [6] Rebuild Toolkit Cache
- [8] Capability Audit
- [9] Core Integration Manager
