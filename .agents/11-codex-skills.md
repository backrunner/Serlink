# Codex Skills Installed For Serlink

This document records Flutter, Dart, and design-related Codex skills installed for this workspace environment. Newly installed skills require restarting Codex before they appear in the active skills list.

## Official Flutter Skills

Source: https://github.com/flutter/skills

Installed:

- `flutter-add-integration-test`
- `flutter-add-widget-preview`
- `flutter-add-widget-test`
- `flutter-apply-architecture-best-practices`
- `flutter-build-responsive-layout`
- `flutter-fix-layout-issues`
- `flutter-implement-json-serialization`
- `flutter-setup-declarative-routing`
- `flutter-setup-localization`
- `flutter-use-http-package`

Recommended Serlink usage:

- Use architecture guidance for layered UI/logic/data separation, but keep Serlink's documented Riverpod/service/repository design as the project authority.
- Use responsive layout and layout-fix skills when implementing the desktop shell, terminal workspace, and SFTP file manager.
- Use widget and integration test skills when building host forms, terminal chrome, SFTP UI, and sync settings.
- Use localization skill before strings spread across the app.

## Official Dart Skills

Source: https://github.com/dart-lang/skills

Installed:

- `dart-add-unit-test`
- `dart-build-cli-app`
- `dart-collect-coverage`
- `dart-fix-runtime-errors`
- `dart-generate-test-mocks`
- `dart-migrate-to-checks-package`
- `dart-resolve-package-conflicts`
- `dart-run-static-analysis`
- `dart-use-pattern-matching`

Recommended Serlink usage:

- Use Dart static analysis and coverage skills in every implementation phase.
- Use mocks for SSH/SFTP/sync/vault fakes before real integration tests.
- Use pattern matching for sealed error/result types and auth method models.
- Use CLI skill for internal tooling such as fixture generation, vault test vectors, or sync inspection tools.

## Design And Figma Skills

Already available or installed:

- `figma`
- `figma-use`
- `figma-create-new-file`
- `figma-create-design-system-rules`
- `figma-generate-design`
- `figma-implement-design`
- `figma-code-connect-components`
- `figma-generate-library`
- `frontend-design`
- `frontend-skill`
- `oh-my-codex-designer`
- `ui-ux-pro-max`

Recommended Serlink usage:

- Use design skills for the cross-platform desktop design system, terminal theme previews, host inventory layout, SFTP file manager, and settings surfaces.
- Use Figma library/design-system skills if a formal component library is created before or during implementation.

## Restart Note

Restart Codex to pick up newly installed skills.

