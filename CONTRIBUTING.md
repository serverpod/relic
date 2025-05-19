# Contributing to Relic

First off, thank you for considering contributing to Relic! We value contributions from everyone, whether you're a seasoned developer or new to open source. This document provides guidelines to ensure a smooth and effective contribution process.

## Table of Contents

- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Pull Requests](#pull-requests)
- [Development Process](#development-process)
  - [Branching](#branching)
  - [Code Style](#code-style)
  - [Commit Messages](#commit-messages)
  - [Testing Guidelines](#testing-guidelines)
- [Code of Conduct](#code-of-conduct)
- [Questions?](#questions)

## Getting Started

Before you begin:

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally: `git clone https://github.com/YOUR_USERNAME/relic.git`
3.  **Set up your development environment**:
    - Ensure you have the Dart SDK installed. See [Dart installation guide](https://dart.dev/get-dart).
    - Fetch dependencies: `dart pub get`
4.  **Read this doc**:
    Please read through all relevant sections. Pay special attention to the "Code Style" and "Testing Guidelines" sections to ensure your generated code aligns with the project's standards. If you are generating code based on an issue, ensure your output fully addresses the issue requirements.

## How to Contribute

### Reporting Bugs

If you encounter a bug, please:

1.  **Search the [issue tracker](https://github.com/serverpod/relic/issues)** to see if it has already been reported.
2.  If not, **open a new issue**.
3.  Provide a **clear title and description**, including:
    - Steps to reproduce the bug.
    - Expected behavior.
    - Actual behavior.
    - Relic version, Dart version, and OS.
    - Relevant code snippets or a minimal reproducible example.

### Suggesting Enhancements

We welcome suggestions for new features or improvements:

1.  **Search the [issue tracker](https://github.com/serverpod/relic/issues)** to see if a similar enhancement has already been suggested.
2.  If not, **open a new issue**.
3.  Provide a **clear title and description**, explaining:
    - The problem you're trying to solve.
    - Your proposed solution or enhancement.
    - Any alternative solutions you've considered.

### Your First Code Contribution

If you're new to contributing, look for issues tagged with `good first issue` or `help wanted`. These are typically more straightforward and a great way to get started.

### Pull Requests

When you're ready to submit code:

1.  Create a new branch from `main` for your changes: `git checkout -b feature/your-feature-name` or `fix/your-bug-fix-name`.
2.  Make your changes, adhering to the [Development Process](#development-process) guidelines below.
3.  Ensure all tests pass: `dart test`.
4.  Commit your changes with a descriptive commit message (see [Commit Messages](#commit-messages)).
5.  Push your branch to your fork: `git push origin feature/your-feature-name`.
6.  Open a pull request (PR) against the `main` branch of the `serverpod/relic` repository.
7.  In your PR description:
    - Clearly describe the problem and solution.
    - Link to any relevant issues (e.g., "Fixes #123" or "Resolves #456").
    - Explain any significant design choices.
8.  Be prepared to discuss your changes and make adjustments based on feedback from maintainers.

## Development Process

### Branching

- **`main`**: This branch represents the latest stable state. PRs should be targeted here.
- **Feature/Fix Branches**: Create branches from `main` for your work (e.g., `feature/new-widget`, `fix/login-bug`).

### Code Style

- **Dart Style**: Follow the official [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
- **Formatting**: Use `dart format .` to format your code before committing.
- **Analysis**: Ensure your code passes static analysis: `dart analyze`. Address any reported lints or errors.
- **Readability**: Write clear, concise, and well-commented code where necessary. This is crucial understanding and maintenance.

### Commit Messages

Please follow a conventional commit message format for clarity and to help with automated changelog generation (though not strictly enforced, it's highly encouraged):

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

- **`type`**: `feat` (new feature), `fix` (bug fix), `docs` (documentation), `style` (formatting, linting), `refactor`, `test`, `chore` (build changes, etc.).
- **Example**: `feat(router): add support for wildcard routes`

### Testing Guidelines

Comprehensive testing is crucial for maintaining the quality and stability of Relic. All new features and bug fixes should be accompanied by tests. The project primarily uses the `package:test/test.dart` framework. If using mocks, `package:mockito` is preferred. Follow its conventions for mock generation and usage.

**1. Structure and Naming:**

- **Grouping:** Tests should be organized into files and `group()` blocks. The name of the file and the description of the group should clearly state the component or functionality being tested (e.g., file `normalized_path_test.dart` with groups, such as `'Normalization Logic'`, `'Request Parsing'`).
- **Test Descriptions (Given-When-Then):** Individual `test()` descriptions should follow a Given-When-Then format. This structure gives clarity for all contributors.

  - Start with `'Given ...,'` describing the initial state, context, or preconditions.
  - Follow with `'when ...,'` describing the action, event, or operation being performed.
  - End with `'then ...,'` describing the expected outcome, result, or state after the action.
  - **Example:**

    ```dart
    // In a file like relic/test/some_feature_test.dart
    import 'package:test/test.dart';
    // Import your feature here

    void main() {
      group('My Feature Logic', () {
        test(
            'Given a specific input string, '
            'when the processing function is called, '
            'then the output should be correctly formatted', () {
          // Arrange: Set up preconditions
          final input = 'test_input';
          final expectedOutput = 'TEST_INPUT_PROCESSED';

          // Act: Perform the action
          final actualOutput = processMyFeature(input);

          // Assert: Verify the outcome
          expect(actualOutput, equals(expectedOutput));
        });
      });
    }
    ```

It is okay to split the `Given ...` and `When ...` descriptions into groups as well.

- **File Naming:** Test files must end with `_test.dart` (e.g., `my_feature_test.dart`) and should generally mirror the name of the file they are testing, placed in a corresponding directory structure under `test/`. They can also be names after scenarios being tested. There may be multiple test files for the same feature, but try to keep closely related tests grouped together in the same file.

**2. Test Body (Arrange-Act-Assert):**

- **Arrange (Given):**
  - Set up all necessary objects, mocks, stubs, or initial state required for the test case.
  - Clearly define the inputs and preconditions stated in the 'Given' part of your test description.
- **Act (When):**
  - Execute the specific function, method, or code path that is being tested. This corresponds to the 'When' part of your test description.
- **Assert (Then):**
  - Use `expect()` from `package:test/test.dart` to verify that the actual outcome matches the expected outcome.
  - The assertions should directly correspond to the 'Then' part of your test description.
  - Use appropriate matchers (e.g., `equals()`, `isTrue`, `isFalse`, `throwsA<ExceptionType>()`, `isEmpty`, `contains`).

**4. General Testing Principles:**

- **Clarity and Readability:** Tests are documentation. They should be easy to understand. The Given-When-Then structure is key.
- **Isolation:** Each test should verify a single, specific aspect of behavior. Avoid testing multiple unrelated things in one test.
- **Repeatability:** Tests must be deterministic and produce the same results every time they are run.
- **Thoroughness:** Aim for good test coverage. Consider:
  - Happy paths (valid inputs, expected behavior).
  - Edge cases (empty inputs, nulls, boundaries, extremes).
  - Error conditions (invalid inputs, exceptions).
- **Maintainability:** Write tests that are robust to minor, unrelated code changes in the SUT (System Under Test). Focus on the public interface, so test are likely to remain valid despite internal rewrites.

**Example (revisiting `normalized_path_test.dart` style):**
Based on `relic/test/router/normalized_path_test.dart`:

```dart
// relic/test/router/normalized_path_test.dart
group('Normalization Logic', () {
  test(
      'Given a simple path, '
      'when normalized, '
      'then segments are correct and toString is canonical', () {
    // Arrange
    final pathString = 'a/b/c';

    // Act
    final normalized = NormalizedPath(pathString);

    // Assert
    expect(normalized.segments, equals(['a', 'b', 'c']));
    expect(normalized.toString(), equals('/a/b/c'));
  });

  test(
      'Given path with ".." segments, '
      'when normalized, '
      'then ".." navigates up correctly', () {
    // Arrange
    final pathString = '/a/b/../c';

    // Act
    final normalized = NormalizedPath(pathString);

    // Assert
    expect(normalized.segments, equals(['a', 'c']));
    expect(normalized.toString(), equals('/a/c'));
  });
});
```

## Code of Conduct

This project and everyone participating in it is governed by the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior.

## Questions?

If you have questions about contributing, feel free to:

- Open an issue on the [issue tracker](https://github.com/serverpod/relic/issues) with the "question" label.

Thank you for contributing to Relic!
