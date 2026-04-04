---
description: Generate a detailed feature specification from the PRD
argument-hint: <feature-name>
allowed-tools: Read, Write
---

# Generate Feature Specification

Read `_docs/PRD.md` and `CLAUDE.md`, then create a detailed spec for: $ARGUMENTS

Create the spec at `_docs/specs/$ARGUMENTS.md` with this structure:

```
# Feature Specification: [Feature Name]

**Status**: Draft
**Priority**: P0 | P1 | P2
**PRD Reference**: Section [X]

## Overview
[What this feature does and why it matters]

## User Stories
- As a [user], I want [action] so that [benefit]

## Acceptance Criteria
- [ ] Specific, testable criterion

## Technical Design
- Architecture approach
- Key data models
- API surface / service layer changes
- SwiftUI view hierarchy

## States to Handle
- Empty state
- Loading state (prefer skeletons over spinners)
- Error state (via shared ErrorHandler)
- Populated state

## Testing Plan
- Unit tests (ViewModels, Services)
- UI tests for critical paths

## Edge Cases
[Scenarios and how to handle them]

## Open Questions
[Unresolved items before implementation]
```

Use ultrathink for the technical design section.
