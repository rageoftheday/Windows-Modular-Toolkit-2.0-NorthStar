# Framework Essential Menu Standard

Framework 2.0 keeps the root menu focused on essential actions. Nice-to-have items should not appear on the main menu unless they are reliable and clearly useful.

## Main Menu Rule

The root menu should prioritize:

1. Run tools
2. Search tools
3. Common actions
4. Dashboard / insight
5. Management
6. Help
7. Quit

## Purpose Text

Menu items may include short purpose text directly under the item. The purpose is not full documentation. It is a navigation hint that helps users find the right place quickly.

Example:

```text
[M] Tool Manager
    Create, edit, organize, clone, hide, and remove modules.
```

## Removed From Root Menu

Favorites and Recently Used are not mandatory Framework 2.0 essentials. They should be hidden from the root menu until they are reliable and object-reference based.

Recent Tools was removed because it depended on runtime logging that may not exist or may not match the current registry.

Favorites should only return later if it stores stable object references instead of fragile paths or folder names.

## Design Principle

Make it smarter. Make it easier. Do not make unfinished convenience features part of the main experience.
