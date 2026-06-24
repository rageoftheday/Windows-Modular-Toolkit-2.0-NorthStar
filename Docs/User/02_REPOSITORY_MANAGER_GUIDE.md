# Repository Manager Guide

## What Is It?
Repository Manager imports, stores, organizes, and reports on toolkit repository content.

## Why Does It Exist?
It separates raw incoming files from managed toolkit storage.

Incoming is the drop box.
Repository is managed storage.

## Main Paths
Incoming\
Repository\Software\
Repository\Packages\
Repository\Scripts\
Repository\Documents\
Repository\Archives\
Repository\Disk Images\
Repository\Custom\

## What Goes Where?
Software: EXE, MSI, portable apps.
Packages: APPX, APPXBUNDLE, MSIX, MSIXBUNDLE.
Scripts: PS1, BAT, CMD.
Documents: TXT, MD, PDF, DOCX, XLSX, PPTX, and other office/reference files.
Archives: ZIP, 7Z, RAR, TAR, GZ, XZ, and related compressed files.
Disk Images: ISO, IMG, WIM, ESD, FFU, VHD, VHDX.
Custom: Detection Library matches and user-defined types.

## How To Import A File
1. Copy the file into Incoming\.
2. Open Main Menu -> [R] Repository Manager.
3. Open [1] Repository Manager.
4. Choose [1] Scan Incoming.
5. Review the detected type and suggested destination.
6. Choose [A] Process Supported Items or select the specific item if available.
7. Confirm the import.

## Success Looks Like
Full Repository Report shows the item under the correct section.
Search Center can find the item.
The file is stored under Repository\.

## If Something Is Misclassified
1. Check Repository Formats.
2. Check Detection Library.
3. Add or fix learned format/detection.
4. Rescan Incoming.

## Reset / Repair
Use Repository Builder to recreate folder structure.
Use Library Recovery to restore Repository Formats or Detection Library if classification breaks.
Use Release Candidate Audit to check for legacy paths or missing structure.


## Winget Puller

Path: Main Menu -> [R] Repository Manager -> [3] Winget Puller

Winget Puller searches Windows Package Manager, generates install commands, creates Winget install modules, and can save package records to the Repository.
