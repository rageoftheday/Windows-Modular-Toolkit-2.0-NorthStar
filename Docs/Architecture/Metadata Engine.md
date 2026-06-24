# Metadata Engine

Metadata Engine is a Foundation service.

It does not create standalone metadata records. Metadata is generated and stored with real toolkit objects such as tools, modules, workspace items, installers, websites, folders, and scripts.

## Metadata v1 Fields

```json
{
  "name": "",
  "description": "",
  "type": "",
  "category": "",
  "keywords": [],
  "important": false
}
```

## Responsibilities

- Auto-generate metadata from name and description.
- Auto-store metadata with the object being created.
- Validate existing metadata.
- Repair or regenerate missing metadata.
- Provide an editor for existing object metadata.

## Rule
Framework suggests. User decides.

Users should not have to create orphan metadata and hope it attaches to the correct item later.
