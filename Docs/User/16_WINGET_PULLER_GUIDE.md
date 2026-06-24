# Winget Puller Guide

Winget Puller helps users find Windows Package Manager packages and turn them into install commands, repository records, or reusable toolkit modules.

## What is Winget?

Winget is the Windows Package Manager command-line tool. It can search software packages and install packages by exact package ID.

Winget Puller is a framework acquisition tool, similar to GitHub Puller. It helps users acquire software in a predictable way without keeping dozens of hardcoded installer modules in the release.

## Where is it?

Main Menu -> [R] Repository Manager -> [3] Winget Puller

## Before you start

Winget Puller checks whether Winget is available.

If Winget is found, the tool shows the Winget path and version.

If Winget is missing, the tool offers help links for Microsoft App Installer / Winget setup. It does not silently install anything.

## What can I search for?

Examples:

- PowerShell
- Visual Studio Code
- 7-Zip
- Git
- Notepad++
- Google Chrome
- Mozilla Firefox
- VLC
- OBS Studio
- PuTTY
- WinSCP

## Recommended RC workflow

1. Main Menu -> [R] Repository Manager.
2. Choose [3] Winget Puller.
3. Choose [1] Search Winget Packages.
4. Type an app name, such as PowerShell or 7-Zip.
5. Review the raw Winget results.
6. Copy the exact Package ID you want.
7. Paste the Package ID when prompted.

Examples of package IDs:

- Microsoft.PowerShell
- Microsoft.PowerShell.Preview
- Microsoft.VisualStudioCode
- 7zip.7zip

## Why does it show raw Winget results?

Winget output can vary by version, source, package name, and terminal width.

For release stability, Winget Puller displays the raw Winget search results and asks the user to enter the exact Package ID. This avoids fragile parsing and makes the tool more reliable.

## How do I install a package?

1. Search for a package or choose Install/Create By Package ID.
2. Enter the exact Package ID.
3. Choose [1] Install Now.
4. Confirm the install when prompted.

Success looks like:

- The generated command is shown.
- Winget runs only after confirmation.

Example command:

winget install -e --id Microsoft.PowerShell --source winget

## How do I copy the install command?

1. Enter or select a Package ID.
2. Choose [2] Copy Command.

Success looks like:

- The command is copied to the clipboard.
- If clipboard copy fails, the command is displayed.

## How do I create a Winget module?

1. Search for a package or choose Install/Create By Package ID.
2. Enter the exact Package ID.
3. Choose [3] Create Module.

The toolkit automatically creates:

- run.ps1
- run.bat
- tool.json

No module wizard is required.

Example:

Package ID:

Microsoft.PowerShell

Created module:

Modules\WINGET_INSTALL_POWERSHELL\

Module name:

Winget Install PowerShell

Category:

Software

Subcategory:

Winget

The created module still asks for confirmation before installing.

## How do I save a package to Repository?

1. Enter or select a Package ID.
2. Choose [4] Save To Repository.

The toolkit saves a repository note under:

Repository\Software\

The note includes:

- Package name
- Package ID
- Install command
- Source
- Saved date

## Useful Winget websites

Winget package search:

https://winget.run

Winstall package/bundle helper:

https://winstall.app

Microsoft Winget documentation:

https://learn.microsoft.com/windows/package-manager/

## Common problems

### Winget not found

Winget is not available on the current system.

Try:

- Install or repair Microsoft App Installer.
- Open Microsoft Winget documentation from the Winget Puller missing-winget screen.

### Package not found

Try a different search term.

Examples:

- Search 7zip instead of 7-Zip.
- Search vscode instead of Visual Studio Code.

You can also search online:

https://winget.run

https://winstall.app

### Install failed

Possible causes:

- Internet unavailable.
- Package requires admin rights.
- Package ID changed.
- Winget source problem.
- Installer failed outside the toolkit.

Try copying the command and running it manually in PowerShell to see the full Winget output.

## Safety notes

Winget Puller can install software, but it does not install silently.

Install Now asks before running.

Created modules also ask before running.

This makes Winget Puller safer than hardcoded installer modules while still giving users an easy way to acquire software.
