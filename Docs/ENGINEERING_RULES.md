# Engineering Rules

## Core Principles
- Correctness > speed
- Clarity > cleverness
- Architecture > implementation details
- Tests define behavior
- Documentation is a source of truth

## Architecture
- SwiftUI + MVVM
- Views contain no business logic
- State must be explicit
- Core and Domain do not depend on SwiftUI

## Coding Rules
- Use async/await
- Avoid force unwrap (!)
- Avoid Any
- Avoid string-based errors

## Git Rules
- Every completed task must result in a commit
- Do not commit broken builds
