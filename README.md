# Windows Space Agent

Find large files worth reviewing when a Windows drive needs a specific amount of free space. Returns local JSON and measures the remaining gap in bytes.

## For AI agents

Start with [AGENTS.md](AGENTS.md). Run the scripts as the signed-in user in Windows PowerShell 5.1. Keep reports local unless the owner chooses to share them.

## Usage

```powershell
.\Review-Space.ps1 -Folder "$env:USERPROFILE\Downloads" -TargetFreeGiB 20
```

The target means total desired free space on the volume. Choose a local folder to inspect. If the target is already met, the scan ends immediately. To use an existing scan, supply -ScanCsv files.csv -DriveRoot C:\ with one file per row and columns Path and Bytes (logical file length). Normalize other tools' exports to that format first. The scan excludes reparse points and reports access errors. The default report includes the largest 20 files; adjust -Limit if needed.
