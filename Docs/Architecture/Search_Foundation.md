# Search Foundation

Search Foundation is a Framework Foundation service that uses metadata and object files to find toolkit items.

Search is user-facing, but the reusable search logic lives in:

```text
Framework\Foundation\Search\Search.Engine.ps1
```

The user-facing tool lives in:

```text
Framework\Search_Foundation\
```

Search Foundation depends on Metadata Engine output but can also scan physical object files directly.
