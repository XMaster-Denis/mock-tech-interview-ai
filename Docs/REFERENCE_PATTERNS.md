# Reference Patterns

Defines canonical behaviors and invariants.

## Networking
- All requests go through HTTPClient
- No URLSession outside Data layer

## State
- enum-based state
- No boolean-driven UI logic
