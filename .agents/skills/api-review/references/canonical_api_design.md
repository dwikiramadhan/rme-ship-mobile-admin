# Foundations of Canonical API Design Principles

The following principles guide the review of public and internal API surfaces:

## 1. Contract-First and Abstraction
- The API boundary must be clearly separated from the underlying implementation details.
- Consumers should rely on well-defined interfaces, contracts, or abstract classes rather than concrete types where flexibility and testability are required.
- Do not leak private data structures, internal ORM models, or transport-layer specifics into domain models.

## 2. Simplicity (KISS & YAGNI)
- Keep parameter lists minimal and purposeful.
- Avoid premature generalization or speculative parameters that are not currently required or used.
- Prefer multiple specific methods with clear intent over a single monolithic method overloaded with flags or nullable option bags.

## 3. Ergonomics and Naming
- Use intent-revealing names that communicate behavior and purpose without ambiguity.
- Adhere to the **Principle of Least Astonishment** (POLA): methods and classes should behave in the way users would naturally expect.
- Follow platform idiomatic conventions (e.g., Effective Dart conventions: verbs for imperative commands, nouns for getters/properties).

## 4. Command-Query Separation (CQS)
- Methods that mutate state (commands) should not return complex query results, and methods that query state should be side-effect free.
- Avoid hidden side effects in getters, property accessors, or equality operators.

## 5. Safety and Strict Typing
- Prefer strongly typed models, sealed hierarchies, records, and enums over untyped strings, loose numbers, or generic dynamic maps.
- Ensure nullability is expressive: use non-nullable types by default, and use nullable types only when absence of value is semantically meaningful.
- Fail fast with visible validation and descriptive exception types rather than failing silently or returning null on illegal arguments.

## 6. Explicit Configuration and Dependency Injection
- Dependencies and configurations must be passed explicitly (e.g., constructor injection) rather than resolved implicitly via global state, singletons, or implicit environment variables.
- Maintain immutability where possible (prefer `final` fields and immutable value objects).
