# Workspace 2.0 Design

Workspace is a personal area for files, folders, scripts, websites, notes, module links, and category links.

## Source of Truth

Workspace folders are the source of truth.

```text
Workspace\<Section>\<Item>.workspace.json
```

`Config\workspace_items.json` is only a generated cache/index.

## First Run

On first use, Workspace asks the user to choose a starter workspace template. The selected template creates the folders. After setup, Workspace Manager no longer shows template creation as a normal menu item.

## Section Order

Workspace sections display in this order:

1. Quick Access
2. Work
3. Personal
4. Everything else alphabetically

## Runtime Ignore Rules

`.keep` and `.gitkeep` files are ignored by Workspace Center, sorting, search, and indexing.

## North Star Rules

- Selection over typing.
- Show examples when typing is required.
- Description instead of Purpose.
- Framework generates keywords where possible.
- Error means no success message.
