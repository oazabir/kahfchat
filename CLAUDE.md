# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Element X Android is the next-generation Matrix client, a total rewrite from Element Classic. It uses:
- **Matrix Rust SDK** via FFI layer for core Matrix functionality
- **Jetpack Compose** for the entire UI layer
- **Appyx** for navigation state management
- **Metro** for dependency injection
- **Kotlin** exclusively (no Java)

Minimum SDK: API 24 (Android 7.0) for Element X, API 33 (Android 13) for Enterprise.

## Build Commands

### Building and Testing

```bash
# Build the project
./gradlew assembleGplayDebug

# Run all unit tests
./gradlew test

# Run specific module tests
./gradlew :features/login:impl:test

# Run all quality checks (before PR)
./tools/quality/check.sh

# Run individual quality tools
./gradlew detekt
./gradlew ktlintCheck --continue
./gradlew ktlintFormat
./gradlew knit           # Update markdown TOCs
./gradlew knitCheck
./gradlew lint
./gradlew runQualityChecks

# Build with warnings as errors (CI enforcement)
./gradlew check -PallWarningsAsErrors=true
```

### Code Coverage

```bash
# Generate coverage report
./gradlew :app:koverHtmlReport
# Report at: app/build/reports/kover/html/index.html

# Verify coverage thresholds
./gradlew :app:koverVerify
```

### Screenshot Tests

```bash
# Record screenshots (requires Git LFS)
./gradlew recordPaparazziDebug

# Verify screenshots
./gradlew verifyPaparazziDebug
```

### Integration Tests

Integration tests require a local Synapse homeserver. See `docs/integration_tests.md` for setup.

## Architecture

### Module Structure

The project follows a multi-module architecture:

- `app/` - Main application module
- `features/` - Feature modules (UI screens/flows), each with `api` and `impl` submodules
- `libraries/` - Reusable libraries
- `services/` - Cross-cutting services
- `appnav/` - Navigation glue between features

### Key Architecture Patterns

**MVI-inspired with Presenter/State separation:**

1. **Presenter** - Compose-first, single `present(): State` method. Emits State over time using Molecule.
2. **View** - Compose function that renders `State` and emits `Event`s
3. **State** - Immutable data class holding UI state
4. **Event** - Sealed interface/class for user actions

```kotlin
// Presenter interface
fun interface Presenter<State> {
    @Composable
    fun present(): State
}

// Testing pattern with Molecule + Turbine
@Test
fun `present - initial state`() = runTest {
    createPresenter().test {
        val initialState = awaitItem()
        assertThat(initialState.someValue).isEqualTo(expected)
    }
}
```

**Navigation with Appyx:**

- **Node** - Navigation unit, owns DI graph, manages lifecycle
- **ParentNode** - Has child Nodes, manages their navModels
- **NodeFactory** - Creates Nodes with dependencies injected
- Navigation is model-driven, not imperative

**Dependency Injection with Metro:**

- Three-level hierarchy: `AppGraph` → `SessionGraph` → `RoomGraph`
- Graphs are created/destroyed with lifecycle
- Use `@DependencyGraph` annotations, not Dagger

```kotlin
@DependencyGraph(AppScope::class)
interface AppGraph {
    val sessionGraphFactory: SessionGraph.Factory

    @DependencyGraph.Factory
    interface Factory {
        fun create(@ApplicationContext context: Context): AppGraph
    }
}
```

### Module Dependencies

- Feature modules should not depend on other feature modules
- Navigation glue is in `app` module
- `libraries-core` has utilities
- `libraries-matrix` wraps Rust SDK

## Feature Module Template

When creating new features, use the provided templates:

1. Install Android Studio plugin "Generate Module from Template"
2. Run `./tools/templates/generate_templates.sh`
3. Import templates from `tmp/file_templates.zip`
4. Use Feature Module template and Presentation Classes template

**Naming conventions (important for coverage):**
- Presenters: suffix `Presenter`
- States: suffix `State`
- Views: suffix `View`
- Tests: suffix `Test`

## Code Quality

### Quality Checks

Run `./tools/quality/check.sh` before submitting PRs. This runs:
1. `./tools/check/check_code_quality.sh`
2. `./gradlew runQualityChecks` (detekt, ktlint, konsist, lint, knit)
3. `./gradlew check -PallWarningsAsErrors=true`

### Android Studio Settings

- Set hard wrap to 160 characters
- Use project code styles in `.idea/codeStyles/`
- Format files before committing

### Logging

Use Timber, never Android Log class. **NEVER log private user data.**

```kotlin
Timber.tag(loggerTag.value).d("my log")
Timber.e(exception, "error occurred")
```

### Testing Philosophy

- Prefer Fake implementations over mocking (no mockk for business logic)
- Mock only Android framework classes
- Use Molecule + Turbine for presenter tests
- Use Paparazzi for screenshot tests (automated via `@Preview`)
- Use Maestro for E2E navigation tests

## Strings and Translations

- Strings are managed externally via Localazy
- Core team manages English strings
- Contributors: add temporary `temporary.xml` file, reviewer will integrate
- Use Compound design tokens for colors/text/icons
- Design system: https://compound.element.io

## Feature Flags

Feature flags are managed through `libraries/featureflag`. Use them to gate incomplete features.

## Known Pain Points

- Gradle cache may misbehave; use `--no-build-cache` if needed
- Screenshot tests are disabled by default, enable with paparazzi gradle tasks
- For local SDK development, see `docs/_developer_onboarding.md` section on building SDK locally

## JDK Requirements

This project requires **Java 21 (JDK 21)** for building. The build will fail if using an older JDK version (like Java 17).

### Setting JAVA_HOME

Before building, ensure JAVA_HOME points to JDK 21:

```bash
# On macOS (Homebrew):
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export ORG_GRADLE_JAVA_HOME=$JAVA_HOME

# Verify:
java -version

# Or check all available Java versions:
/usr/libexec/java_home -V
```

### Installing Java 21

If Java 21 is not installed:

```bash
# macOS with Homebrew:
brew install openjdk@21

# Then set JAVA_HOME:
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

## Building and Deploying to Android Emulator

### Prerequisites

1. Install Java 21 (JDK 21) and set JAVA_HOME
2. Start an Android emulator (e.g., via Android Studio AVD Manager)

### Check Running Emulator

```bash
# List connected devices/emulators
adb devices
```

### Build and Install

```bash
# Set JAVA_HOME to Java 21
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

# Build and install the debug APK on connected emulator/device
./gradlew :app:installGplayDebug

# Or build APK only without installing
./gradlew :app:assembleGplayDebug
```

### Quick Dev Build (Single-ABI, Faster)

```bash
# Fast dev install (single ABI, auto-detects emulator ABI on macOS)
./tools/dev/install_dev.sh

# Optional: override ABI or pass extra Gradle args
./tools/dev/install_dev.sh x86_64
./tools/dev/install_dev.sh -- --stacktrace
```

### Troubleshooting

If you encounter a "Cannot find a Java installation" error:
1. Ensure JDK 21 is installed: `brew install openjdk@21`
2. Set JAVA_HOME: `export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
3. Verify: `java -version` should show version 21

If the build fails with configuration cache issues:
```bash
# Clear configuration cache and retry
./gradlew clean --no-configuration-cache
./gradlew :app:installGplayDebug
```
