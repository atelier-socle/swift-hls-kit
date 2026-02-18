# Contributing to swift-hls-kit

Thank you for your interest in contributing. This document explains the process and expectations.

## How to Contribute

1. **Fork** the repository on GitHub
2. **Create a branch** from `main` for your changes (`feat/my-feature`, `fix/my-fix`)
3. **Make your changes** following the guidelines below
4. **Push** your branch to your fork
5. **Open a Pull Request** against `main`

## Development Setup

### Requirements

- **Swift 6.2+** (Xcode 26.2 or later)
- **macOS 14+**
- **SwiftLint** — `brew install swiftlint`
- **swift-format** — `brew install swift-format`

### Build and Test

```bash
# Build
swift build

# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage
```

### Lint

The CI enforces linting before build. Run these locally to catch issues early:

```bash
# SwiftLint — must pass with zero violations in strict mode
swiftlint lint --strict

# swift-format — must pass with zero violations
swift-format lint -r Sources/ Tests/
```

Configuration files are included in the repository (`.swiftlint.yml` and `.swift-format`).

## Code Style

- **4 spaces** indentation, **150 character** max line width
- Explicit access control on all public API (`public`, `package` for cross-module internal)
- Prefer `struct` over `class`
- `///` doc comments on all public API with `Parameters`, `Returns`, and `Throws` sections
- No force unwraps (`!`), no `try!`, no `as!`
- No `@preconcurrency` imports, no `nonisolated(unsafe)`
- All public types must be `Sendable`

## Testing Requirements

- All tests must pass: `swift test` with zero failures
- Code coverage must not decrease — new code should include tests
- Use **Swift Testing** (`import Testing`) for all new tests, not XCTest
- Test files go in `Tests/HLSKitTests/`
- Use `#expect` and `#require` for assertions

## Pull Request Guidelines

- **Clear title** describing the change (e.g., "Add ID3v2 chapter reader")
- **Description** explaining what changed and why
- **Tests** for new features and bug fixes
- **One concern per PR** — avoid mixing unrelated changes
- PRs must pass CI (lint + build + test on all platforms)
- Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `perf:`, `chore:`

## Reporting Issues

Open an issue on GitHub with:

- A clear, descriptive title
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Swift version and platform
- Minimal code sample or test audio file if applicable

## Project Structure

- `Sources/HLSKit/` — core library (model, ID3, MP4, validator, encoder, exporter, streaming, batch)
- `Sources/CLI/` — command-line tool (swift-argument-parser)
- `Tests/HLSKitTests/` — unit and integration tests
- `Tests/Fixtures/` — test audio files (small media samples)

## License

By contributing to this project, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
