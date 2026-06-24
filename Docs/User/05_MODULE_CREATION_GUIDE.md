# How To Make A Module

## What Is A Module?
A module is a user tool that the toolkit can search, browse, launch, validate, and describe.

A typical module contains:
Modules\Your_Module_Name\run.ps1
Modules\Your_Module_Name\tool.json

Some modules may use BAT, CMD, websites, installers, or other launcher files depending on type.

## Step By Step
1. Open Main Menu.
2. Open [M] Module Tool Manager.
3. Choose the Add Module or Module Builder option.
4. Choose module type.
5. Enter the module name.
6. Add or paste the script/launcher/content.
7. Choose category.
8. Choose subcategory.
9. Add description.
10. Add keywords.
11. Add dependencies.
12. Review metadata.
13. Create the module.
14. Test it from Search Center or Launch Center.

## Metadata Fields Explained
Name: display name of the module.
Category: where the module appears.
Subcategory: optional smaller grouping.
Description: what the module does.
Keywords: alternate search terms.
Dependencies: requirements needed before running.
Risk: expected safety level.
Requires Admin: whether elevation may be needed.
Entry: script or launcher file.

## Success Looks Like
The module appears in Search Center.
The module appears under its category.
The module launches from the toolkit.
Module Validator reports no critical errors.

## If It Does Not Appear
1. Run Module Validator.
2. Check tool.json.
3. Confirm category and subcategory.
4. Confirm entry file exists.
5. Rebuild cache/search if available.

## If It Fails To Run
1. Open the module folder.
2. Run run.ps1 manually in PowerShell.
3. Check execution policy.
4. Check dependencies.
5. Review Logs\.
