# Recovery & Reset Guide

## Purpose
This guide explains what to do when part of the toolkit becomes corrupted, missing, or misconfigured.

## Metadata Corruption
Symptoms:
- categories missing
- keywords gone
- dependencies missing
- metadata screens fail

Fix:
Main Menu -> [F] Framework Center -> Metadata Library Manager -> Library Recovery
Restore Metadata Library backup or defaults.

## Repository Format Corruption
Symptoms:
- files stop sorting correctly
- learned formats disappear
- unknown extensions behave incorrectly

Fix:
Metadata Library Manager -> Repository Formats -> restore backup/defaults.

## Detection Library Corruption
Symptoms:
- Python/NodeJS/Photoshop/etc. are not detected
- folder projects become Portable Folder unexpectedly

Fix:
Metadata Library Manager -> Detection Library or Library Recovery.
Restore Detection Library backup/defaults.

## Repository Folder Problems
Symptoms:
- Repository folders missing
- imports fail
- reports show missing paths

Fix:
Repository Manager -> Repository Builder / Repair Repository.

## Search Problems
Symptoms:
- items import but search cannot find them

Fix:
Rebuild cache/search if available.
Re-scan repository.
Check keywords and metadata.

## Framework Problems
Symptoms:
- framework tools fail
- menu paths missing
- protected tools missing

Fix:
Run Framework Repair / Release Candidate Audit.
Use a clean release ZIP if framework files were manually changed.

## Emergency Rule
Do not manually edit core framework files unless you know exactly why.
Restore from backup or clean ZIP first.
