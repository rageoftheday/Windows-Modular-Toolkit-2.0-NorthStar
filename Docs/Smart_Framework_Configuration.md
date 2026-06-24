# Smart Framework Configuration

Framework 2.0 should hardcode the foundation and configure behavior.

## Rule

Hardcode stable framework contracts such as `Core`, `Framework`, `Modules`, `Config`, `Cache`, `Logs`, `Exports`, and `Docs`.

Configure behavior that may evolve, including installer categories, compatibility profiles, search sources, dependency names, report formats, and module packs.

## Smart Rule

The framework should suggest. The user should decide.

Smart behavior should reduce effort without silently moving, installing, deleting, or replacing user content without confirmation.

## Current Config Files

- `Config\installer_categories.json`
- `Config\compatibility_profiles.json`

These files make future upgrades easier because the framework can adjust behavior by updating data instead of rewriting logic.
