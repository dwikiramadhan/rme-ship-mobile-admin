---
name: cleanup-code-inspections
description: Reduce technical debt and improve code quality by systematically resolving static analysis warnings.
---

# Skill: Code Inspection & Cleanup

You are tasked with reducing technical debt and improving code quality by systematically resolving static analysis warnings.

## Objective
Reduce technical debt and improve code quality by systematically resolving static analysis warnings.

## Workflow Instructions

### 1. Baseline
- Run `flutter test` (or `./gradlew test`) to ensure the project is stable before making changes.

### 2. Run Inspection
- Execute `flutter analyze` or `dart analyze` on the project (or a specific module) to locate all analysis errors, warnings, and linter notices.

### 3. Prioritize
- Focus first on "Probable bugs", dead code, unused fields/methods, and unawaited futures.

### 4. Refactor
- Apply fixes for obvious issues (e.g., missing awaits, unused fields, dead code, redundant arguments).

### 5. Suppress
- Explicitly suppress false positives or intentional exceptions with a comment and reason (e.g., `// ignore: [lint_rule] // Reason`).

### 6. Verify
- Run `flutter analyze` to ensure issues are resolved.
- Run `flutter test` to ensure no regressions were introduced.

### 7. Report & Review
- Summarize the inspections resolved.
- Provide clear diffs and rationale for fixes.
- Do not commit or push without user request.
- Provide a suggested Git commit message.
