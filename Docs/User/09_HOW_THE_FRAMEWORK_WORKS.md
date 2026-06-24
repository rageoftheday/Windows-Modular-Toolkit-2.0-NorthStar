# How The Framework Works

## Big Picture
The toolkit is built around reusable framework knowledge.

Core rule:
Learn once. Use everywhere.

## Main Systems
Repository Manager stores and organizes files.
Metadata Library Manager stores categories, keywords, dependencies, descriptions, repository formats, and detections.
Detection Library identifies projects, design files, source folders, CAD files, game mods, and future user-defined types.
Search Center uses metadata and records to find things.
Reports summarize what exists.
Recovery restores corrupted libraries or structures.

## Framework vs Content
Framework files are protected.
User content is managed by the user.

Framework includes Core and Framework tools.
User content includes Modules, Repository items, Workspace links, categories, learned formats, and detections.

## Why This Matters
The toolkit can grow without rewriting code.

If a new extension appears, add a repository format.
If a new project type appears, add a detection.
If a new search term is needed, add keywords.

## Example
A user adds .foo as Custom\Work.
The toolkit can then scan it, import it, search it, report it, and route it.

## Another Example
A folder contains package.json.
Detection Library identifies it as NodeJS Project.
Repository imports it under Custom\NodeJS Project and reports it in Detection Summary.
