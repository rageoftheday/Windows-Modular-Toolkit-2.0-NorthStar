# Framework Module Builder Standard

The legacy Enhanced Add Tool Wizard is retired before release.

Replacement: Add Module Builder.

Purpose:
- Create modules from pasted PowerShell scripts.
- Create modules from pasted Batch/CMD scripts.
- Import existing PS1/BAT/CMD files.
- Create empty module templates.
- Create module launchers for websites or installer paths.

Rules:
- Module Builder may create or modify modules only.
- Module Builder may not modify framework/core files.
- Framework suggests metadata; user decides final values.
- Generated modules must include tool.json and a run entry.
