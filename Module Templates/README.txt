WINDOWS MODULAR TOOLKIT
Framework Edition 2.0

MODULE TEMPLATE README
============================================================

This folder contains blank files for manually creating user modules.
The preferred method is still:

Toolkit Management -> Builders -> Add Module Builder

Use these templates when you want to create a module by hand.

Template files
------------------------------------------------------------

run.bat
- Launches run.ps1 from the same module folder.
- Usually does not need to be changed.
- Keeps the module easy to run from File Explorer or the toolkit.

run.ps1
- Main PowerShell script for the module.
- Replace the example text with your own PowerShell commands.
- This is where the tool actually does its work.

tool.json
- Metadata file used by the framework.
- Controls how the module appears in menus, search, dashboards, validation, and Toolkit Management.
- The framework reads this file; users should not need to edit toolkit framework code.

Recommended module layout
------------------------------------------------------------

Modules\Your_Module_Name\
  run.bat
  run.ps1
  tool.json

Metadata limits
============================================================

These limits keep menus clean, search useful, and metadata easy to read.

name
- Required: Yes
- Length: 3-40 characters
- Current longest built-in value checked during development: 31 characters
- Example: DNS Flush

category
- Required: Yes
- Length: 1-35 characters
- Current longest built-in value checked during development: 22 characters
- Example: Network Tools

subcategory
- Required: No
- Length: 0-35 characters
- Current longest built-in value checked during development: 23 characters
- Example: Diagnostics

description
- Required: No
- Length: 0-250 characters
- Current longest built-in value checked during development: 112 characters
- Example: Clears the Windows DNS resolver cache.

keywords
- Required: Yes
- Minimum: 1 keyword
- Maximum: 10 keywords
- Purpose: Improves search, suggestions, and future recommendations.
- Example: ["dns", "flush", "network"]

dependencies
- Required: No
- Minimum: 0 dependencies
- Maximum: 15 dependencies
- Purpose: Tells the framework what the module needs to run correctly.
- Example: ["PowerShell", "Winget"]

Field descriptions for tool.json
============================================================

name
- Display name shown in the toolkit.
- Keep it short and clear.
- Avoid using a full sentence as the name.

category
- Main section where the module appears under Browse Modules.
- Users can create any category name they want.
- The framework does not require fixed categories.

Common category examples:
- Activation Tools
- Boot and Recovery
- Cleanup Tools
- Disk and Storage
- Drivers and Kernel
- Network Tools
- Printer Tools
- Process and Services
- Security Tools
- Setup and Dependencies
- System Information
- Windows Features
- Windows Repair
- Custom Tools

subcategory
- Optional second-level grouping under category.
- Leave blank if not needed.
- Example: Diagnostics, Repair, Reports, Installers.

description
- Short explanation of what the module does.
- Used in search results and menus.
- Can be blank, but a clear description is recommended.

keywords
- Search words that help users find the module.
- Must contain at least 1 keyword.
- Maximum 10 keywords.
- Enter as a JSON list.
- Example:
  "keywords": ["dns", "flush", "network"]

risk
- Helps users understand the impact of running the module.

Allowed values:
- Safe
  Information-only or low-impact actions.

- Moderate
  Changes settings or runs repair actions that are usually reversible.

- Dangerous
  Can delete data, reset services, change system configuration, install software, or make high-impact changes.

requires_admin
- true means the module should run with Administrator rights.
- false means normal user permissions are acceptable.

Use true for tools that:
- Install software
- Modify Windows settings
- Run DISM or SFC
- Manage services
- Change drivers
- Enable/disable Windows features

supports_logs
- true means the module was written to create logs or use framework logging.
- false means it does not create logs.

Important:
Setting this to true does not magically add logging unless the script supports it.
Future builders may add logging helpers automatically.

supports_export
- true means the module can export results to a file.
- false means it does not export results.

Important:
Setting this to true does not magically export data unless the script supports it.
Future builders may add export helpers automatically.

export_types
- List of supported export formats.
- Leave empty if supports_export is false.
- Examples:
  "export_types": ["TXT"]
  "export_types": ["CSV", "HTML"]
  "export_types": ["CSV", "HTML", "JSON"]

Common export types:
- TXT
- CSV
- HTML
- JSON
- XML
- XLSX

Note:
XLSX exports usually require the ImportExcel PowerShell module.

entry
- File the toolkit launches.
- For this template, keep it as:
  "entry": "run.ps1"

The run.bat file launches run.ps1, but the framework can also launch run.ps1 directly.

dependencies
- Requirements needed for the module to run correctly.
- Leave empty if there are no special requirements.
- Maximum 15 dependencies.

Examples:
- PowerShell
- ActiveDirectory
- RSAT
- Winget
- ImportExcel
- PrintManagement
- Hyper-V
- WSL

Example:
  "dependencies": ["PowerShell", "Winget"]

hidden
- true hides the module from normal Browse Modules and normal search.
- false shows the module normally.

Hidden modules should still be manageable later through Toolkit Management.

Removed fields
============================================================

These fields are not used in normal Framework Edition 2.0 user modules:

version
- Removed. Normal modules do not need a version field.

author
- Removed. The framework does not need to know who created a normal module.

estimated_time
- Removed. It is usually a guess and adds maintenance without much value.

important
- Removed. Favorites, Quick Actions, Search, and future recommendation features handle visibility better.

Framework vs Modules
============================================================

Framework\
- Protected toolkit engine/components.
- Users should not delete, rename, or move these through the toolkit.

Modules\
- User-controlled content.
- Users can create, rename, move, hide, clone, and delete these.

Module Templates\
- Blank manual templates.
- These are not active modules until copied into Modules\ and completed.

Design rule
============================================================

The framework manages the toolkit.
The user manages the modules.

Users should not need to edit core framework scripts to build their own toolkit.
