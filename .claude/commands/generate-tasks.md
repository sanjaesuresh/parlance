---
description: Break down a feature spec into step-by-step implementation tasks
argument-hint: <feature-name>
allowed-tools: Read, Write
---

# Generate Task Breakdown

Read `_docs/specs/$ARGUMENTS.md` and `CLAUDE.md`, then create a detailed implementation task list at `_docs/plans/$ARGUMENTS-tasks.md`.

Structure:

```
# Tasks: [Feature Name]

**Feature Spec**: `_docs/specs/[feature].md`
**Status**: Not Started

## Progress Summary
- Total Steps: X
- Completed: 0
- Current: Step 1

## Steps

### Step 1: [Task Name]
- [ ] Subtask 1
- [ ] Subtask 2
**Notes**: [Implementation guidance, gotchas, dependencies]

## Changes Log
| Date | Step | Changes |
|------|------|---------|
```

Rules for good task breakdowns:
- Each step should be completable in one focused session
- Order by dependency — foundational work before feature work
- Call out which layer each task touches (Model, Service, Repository, ViewModel, View)
- Flag any tasks that require API changes or new dependencies
- Note reuse opportunities from existing `Services/`, `Components/`, `Utilities/`
