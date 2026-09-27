# Skill: Project-Wide Typography Refactor

## Objective
Scan the ENTIRE Flutter project (`lib/` directory) and automatically refactor all hardcoded `fontSize` values inside `TextStyle` or custom text widgets to use a centralized Design System or Material 3 `TextTheme`.

## System Constraints & Anti-Hallucination Rules
1. **NO CODE TRUNCATION:** Do not use `// ... rest of the code` or `// TODO: copy the rest`. You MUST rewrite the entire modified file from top to bottom without omitting anything.
2. **NO HALLEUCINATIONS:** Only replace the `fontSize` and its corresponding typography properties. Do not alter business logic, state management, or UI layout structures.
3. **CONTEXT AWARENESS:** 
   - If a widget has access to `BuildContext`, use `Theme.of(context).textTheme.<token>`.
   - If a file or class does NOT have access to `BuildContext` (e.g., constant files, static themes, or background helpers), DO NOT use `Theme.of(context)`. Instead, use a fallback static design system token or skip context-dependent refactoring for that specific file.
4. **IMPORT CHECK:** If you introduce a centralized typography class, ensure the correct `import` statement is automatically added to the top of every modified file.

## Mapping Blueprint (Reference Guide)
When you find a hardcoded font size, map it to the closest Material 3 standard token:
- `fontSize: 28` to `32` -> `displayMedium` / `headlineLarge`
- `fontSize: 22` to `26` -> `headlineMedium` / `titleLarge`
- `fontSize: 18` to `20` -> `titleMedium`
- `fontSize: 15` to `17` -> `bodyLarge`
- `fontSize: 13` to `14` -> `bodyMedium`
- `fontSize: 10` to `12` -> `bodySmall` / `labelLarge`

## Execution Steps for Agent
1. **Global Scan:** Identify every single `.dart` file inside the `lib/` directory that contains `fontSize:`.
2. **Batch Generation:** Process the files systematically. Ensure each file is generated fully.
3. **Property Preservation:** If the original `TextStyle` has other properties (like `color`, `fontWeight`, `letterSpacing`), preserve them using the `.copyWith()` method.

## Conversion Code Examples

### Example 1: Standard Widget with Context
#### Before:
```dart
Text(
  'Welcome to the App',
  style: TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  ),
)
```
#### After:
```dart
Text(
  'Welcome to the App',
  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
    color: Colors.blue,
    fontWeight: FontWeight.bold, // Kept original weight if different from token
  ),
)
```

### Example 2: Maintaining Custom Properties
#### Before:
```dart
Text(
  'Subtitle text here',
  style: TextStyle(fontSize: 14, color: Colors.grey),
)
```
#### After:
```dart
Text(
  'Subtitle text here',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Colors.grey,
  ),
)
```

## Execution Prompt Trigger
When this skill is called via `/clean-typography`, initiate a full workspace scan on `lib/` immediately. Do not ask for confirmation per file, execute all files sequentially until the entire project is clean and compliant.
