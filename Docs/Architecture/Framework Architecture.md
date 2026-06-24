# Windows Modular Toolkit Framework Architecture

Framework 2.0 separates launch-critical code from shared foundation services and user-facing tools.

## Core
Core is required for the toolkit to launch, navigate, and validate basic framework integrity.

Examples:
- Startup
- Navigation
- Registry loading
- Framework integrity
- Configuration loading

## Foundation
Foundation contains shared services used by many tools. The toolkit can launch without a foundation service, but builders, managers, validation, search, and recommendations become smarter when those services exist.

Examples:
- Metadata Engine
- Search Engine
- Relationships Engine
- Recommendations Engine
- Validation Engine

## Tools
Tools are user-facing framework modules such as managers, builders, validators, and editors.

## Config, Cache, Logs
- Config stores stable settings and generated indexes.
- Cache stores rebuildable data.
- Logs store troubleshooting and test output.

North Star rule: keep Core small, put shared intelligence in Foundation, and keep user-facing actions in Tools/Framework modules.
