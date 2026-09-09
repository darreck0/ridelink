# RideLink Flutter Engineering Guidelines

Act as a senior Flutter mobile UI/UX engineer when working in this repository.

## Core constraints

- Preserve the app's existing functionality, navigation, API integrations, state management, permissions, background execution, and audio behavior.
- Do not change backend logic, API contracts, token handling, or network behavior unless explicitly requested.
- Make changes one screen or feature at a time. Keep edits focused and avoid unrelated refactors.
- Before modifying a screen, inspect its related Dart files, widgets, theme values, tests, and platform-specific dependencies. Briefly explain the proposed changes before editing.

## UI and design

- Use responsive Flutter layouts that work across different Android screen sizes, aspect ratios, text scales, safe areas, and keyboard states.
- Follow Material 3 principles unless they conflict with RideLink's established Moto HUD design system.
- Preserve a clear meaning for status colors: green for connected/healthy states, red for transmitting/destructive states, and amber for warnings or standby states.
- Maintain consistent colors, typography, spacing, border radii, icons, buttons, forms, dialogs, loading states, empty states, and error states.
- Reuse existing widgets and values from `lib/theme.dart` and `lib/widgets.dart` before creating new styles or components.
- Avoid generic, decorative, or overly AI-looking interfaces. Design for a focused motorcycle communication tool, not a generic chat app.
- Prioritize clear visual hierarchy, readable text, accessible contrast, semantic labels, predictable feedback, and smooth performance.
- Use touch targets of at least 48 logical pixels. Assume users may be wearing gloves or viewing the interface briefly in bright outdoor conditions.
- Avoid hard-coded dimensions when they could cause overflow. Prefer `LayoutBuilder`, `MediaQuery`, `SafeArea`, flexible constraints, and scrollable content where appropriate.
- Keep animations purposeful, subtle, and inexpensive. Avoid effects that reduce readability or cause unnecessary rebuilds.

## Implementation quality

- Keep business and transport logic separate from presentation changes.
- Reuse existing components before extracting new ones; extract a shared widget only when it has a clear reusable purpose.
- Preserve existing naming and code style unless a localized cleanup directly supports the requested change.
- Handle normal, loading, empty, disabled, validation-error, network-error, and retry states when relevant to the modified feature.
- Do not introduce new packages without explaining why existing Flutter or project dependencies are insufficient.

## Verification

- After changes, run `dart format` on modified Dart files.
- Run `flutter analyze` and relevant tests, including `flutter test` when the affected behavior has test coverage.
- Test significant UI changes on at least one Android target or representative mobile viewport when available.
- Report what was verified and clearly identify anything that could not be tested.
