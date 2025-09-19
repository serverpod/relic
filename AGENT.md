## Planning

When given a task, always iterate on a plan with the user, before commencing.
Setup clear goals for "definition of done".

## Revision control

- This repository uses jj (jujutsu). Avoid using git commands, despite it being co-located.

- Make sure to make small incremental commits.

- Make sure that each commit leaves repo in a correct state, this can be checked with:
  - dart fix --apply .
  - dart analyze . --fatal-infos
  - dart format .
  - dart test
  before commiting.

- Make sure use [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) messages, of the form:
  ```
  <type>[optional scope]: <description>

  [optional body]

  [optional footer(s)]
  ```
  he commit contains the following structural elements, to communicate intent to the consumers of your library:

  1) fix: a commit of the type fix patches a bug in your codebase (this correlates with PATCH in Semantic Versioning).
  2) feat: a commit of the type feat introduces a new feature to the codebase (this correlates with MINOR in Semantic Versioning).
  3) BREAKING CHANGE: a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR in Semantic Versioning). A BREAKING CHANGE can be part of commits of any type.
  4) types other than fix: and feat: are allowed, for example build:, chore:, ci:, docs:, style:, refactor:, perf:, and test:.
  5) footers other than BREAKING CHANGE: <description> may be provided and follow a convention similar to git trailer format.

  An [optional scope] may be provided to a commit’s type, to provide additional contextual information and is contained within parenthesis, e.g., feat(parser): add ability to parse arrays.

  Ensure <description> starts with a capital letter.

## Definition of done

- New code must be tested Given-When-Then style

  Given:
  Sets the stage by describing the initial state, preconditions, or context before the test begins.

  When:
  Details the specific action or event that the user or system performs.

  Then:
  Outlines the expected outcome or the verifiable consequences that should occur as a result of the "When" action.

- No tests can fail

- Coverage cannot decrease.

  To test coverage run:
  - dart pub global run coverage:test_with_coverage --branch-coverage
  - format_coverage --packages=.dart_tool/package_config.json --report-on=lib/ --in=coverage/coverage.json --pretty-print
