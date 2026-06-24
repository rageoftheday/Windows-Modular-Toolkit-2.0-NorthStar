# Framework Design Notes

## Core Principle
Framework owns framework. Users own content.

## Update Boundary
Framework updates must not modify user Modules, Installers, Packs, Downloads, or user-created tools.

## Capability Rule
Tools may be renamed, merged, hidden, or retired, but protected capabilities must survive.

Protected capabilities include registry building, validation, health checks, search, smart recommendations, tool chaining, backups, exports, tool creation, category management, and framework repair.

## Navigation Rule
The Main Menu may quit. Submenus go back. Back should always move one level up.

## Menu Rule
Most-used actions go first. Management actions go in the middle. Help and quit go at the bottom.
