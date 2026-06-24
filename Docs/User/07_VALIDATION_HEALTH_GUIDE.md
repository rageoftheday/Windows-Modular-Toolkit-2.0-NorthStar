# Validation & Health Guide

## What Is It?
Validation and health tools check whether the toolkit, modules, repository, metadata, and framework structure are working.

## When To Use It
Use validation before release builds, after importing many items, after editing metadata, or when something feels broken.

## Common Checks
Module validation: confirms module metadata and entry files.
Repository audit: checks repository structure and records.
Library health: checks metadata, formats, and detection libraries.
Framework repair: checks framework components.
Release Candidate Audit: checks release readiness.

## What To Do With Errors
Read the error message.
Check the affected section.
Use repair/recovery tools if available.
Re-test after repair.

## Success Looks Like
No syntax errors.
No missing critical folders.
No corrupt libraries.
No legacy repository paths.
No hidden QA leftovers in release builds.
