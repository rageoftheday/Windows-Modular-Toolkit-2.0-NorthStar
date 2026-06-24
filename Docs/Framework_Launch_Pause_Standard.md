# Framework 2.0 Launch Pause Standard

Every launchable Framework or Module folder uses the triplet standard:

- `run.ps1`
- `run.bat`
- `tool.json`

`tool.json` must use:

```json
"entry": "run.bat"
```

`run.bat` launches `run.ps1` from its own folder and pauses when run directly.
When launched from inside the toolkit, the toolkit sets `TOOLKIT_LAUNCHED=1` and handles the return pause itself.

This prevents output from flashing/disappearing while avoiding duplicate pauses inside the toolkit.
