WINDOWS MODULAR TOOLKIT - MODULE SIDE PATCH
===========================================

Purpose:
This pack contains cleaned alpha-era modules converted to the current Framework 2.0 module metadata format.

What was done:
- Updated tool.json metadata to current release schema.
- Removed legacy wrapper backup files.
- Removed obvious redundant modules already included in the release build.
- Removed activation/external-code modules.
- Removed program download/install/update modules, especially Winget install/download modules.

Kept modules: 139
Excluded modules: 25

Install as side patch:
Copy the Modules folder into the toolkit root and allow it to merge with the existing Modules folder.
Do not overwrite Framework or Core folders.

Important:
This is a side patch, not the protected framework. Test modules before public release.
