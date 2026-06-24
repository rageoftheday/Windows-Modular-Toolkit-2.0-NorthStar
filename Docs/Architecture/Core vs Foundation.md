# Core vs Foundation

## Core
Core is launch-critical. If Core breaks, the toolkit may not start.

Core should stay small and protected.

## Foundation
Foundation is shared infrastructure. It supports tools but is not normally opened directly by users.

The first Framework 2.0 foundation service is the Metadata Engine.

## Rule
If it is required to launch the toolkit, it belongs near Core.
If it helps many tools work smarter, it belongs in Foundation.
If a user opens it to do work, it is a Tool.
