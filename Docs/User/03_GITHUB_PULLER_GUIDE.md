# GitHub Puller Guide

## What Is It?
GitHub Puller acquires software, releases, source code, and project files from GitHub.

## Supported URL Types
Repository URL:
https://github.com/owner/repository

Release URL:
https://github.com/owner/repository/releases

Release asset URL:
https://github.com/owner/repository/releases/download/version/file.zip

Source ZIP URL:
https://github.com/owner/repository/archive/refs/heads/main.zip

Git clone URL:
https://github.com/owner/repository.git

## How To Download A GitHub Release Asset
1. Open Main Menu -> [R] Repository Manager.
2. Open GitHub Puller.
3. Paste a GitHub repository or release asset URL.
4. Choose the release asset or import option.
5. Choose destination.

## Download Destinations
Downloads\GitHub\
Temporary download staging.

Incoming\
Used when preparing the file for Repository import.

Save To Computer
Opens a folder picker and saves outside the toolkit.

Repository + Module
Downloads/imports content and starts module creation unless you choose N when prompted.

## Source Code Note
The toolkit can download source ZIP files or clone repositories, but it does not compile source code.
If you download source code, use the proper development tools for that project.

## Common Problems
Repository not found: check spelling and confirm it is public.
Git missing: use Source ZIP or install Git.
Download failed: check internet connection and URL.

## Recovery
Downloaded files can be removed from Downloads\GitHub\.
Imported files can be managed through Repository Manager.
If detection is wrong, check Detection Library and Repository Formats.
