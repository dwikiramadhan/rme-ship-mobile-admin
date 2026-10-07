# Project Agent Rules

- Architecture: Clean Architecture, feature-based folder structure
- State management: Riverpod (prefer AsyncNotifier over FutureProvider)
- Never hardcode colors, always use ThemeData tokens
- Run `flutter analyze` before suggesting any code change
- Target Flutter 3.44+, Dart 3.4+
- Localization: use flutter_localizations, never raw strings in widgets
