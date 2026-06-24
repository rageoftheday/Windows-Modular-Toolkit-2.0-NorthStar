# Public Contracts

These are the structures future versions should avoid breaking without a migration path.

## User Module Layout
Modules/<ToolFolder>/tool.json
Modules/<ToolFolder>/run.ps1
Modules/<ToolFolder>/run.bat optional

## User Module Metadata
The normal user module schema includes:
- name
- category
- subcategory
- description
- keywords
- risk
- requires_admin
- supports_logs
- supports_export
- entry
- dependencies
- hidden

## Ownership Boundary
Framework and Core are framework-owned.
Modules are user-owned.
Cache is generated.
Logs are diagnostic/history.
Config is persistent state.
