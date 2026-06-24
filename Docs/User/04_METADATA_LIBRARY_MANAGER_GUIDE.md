# Metadata Library Manager Guide

## What Is It?
Metadata Library Manager controls the framework knowledge used for organization, search, detection, dependencies, descriptions, and recovery.

## Path
Main Menu -> [F] Framework Center -> Metadata Library Manager

## Categories
Purpose: top-level organization groups for modules and toolkit content.

Use when: a tool or item needs a main home such as Printer Tools, Security, Software, or Development Tools.

## Subcategories
Purpose: smaller groups inside categories.

Example: Development Tools -> Python.

Use when: a category becomes crowded or needs better organization.

## Keywords
Purpose: search terms and aliases.

Example: CrowdStrike can have keywords falcon, antivirus, edr, security.

Use when: users may search for a tool using different words.

## Dependencies
Purpose: requirements needed before running a tool.

Examples: Administrator Rights, Internet Connection, PowerShell 5.1, Git.

Use when: a module needs a condition or external tool to work.

## Description Templates
Purpose: reusable descriptions for module creation.

Use when: you want consistent module descriptions.

## Repository Formats
Purpose: teaches the repository how to sort file extensions.

Example: .zip -> Archives.

Use when: an unknown extension should become supported toolkit-wide.

## Detection Library
Purpose: teaches the framework how to recognize projects, design files, folders, and custom asset types.

Example: package.json -> NodeJS Project.

Use when: content should be recognized by structure or indicators, not just extension.

## Library Recovery
Purpose: restore damaged or corrupted libraries.

Use when: categories disappear, formats stop detecting, detections are wrong, or JSON becomes corrupted.

## Backup Standard
Editable libraries should keep backups.
Core defaults are read-only.
User learned entries are editable.

## Success Looks Like
New metadata appears in creation workflows, Search Center, Repository Manager, and reports without needing code changes.
