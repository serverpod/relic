# How to publish Relic

To publish this package, simply create a new tag and push it to the repository. The GitHub action will automatically build and publish the package to pub.dev.

The tag needs to be in the format `vX.Y.Z`, where `X`, `Y`, and `Z` are integers. The version number should be incremented according to the [Semantic Versioning](https://semver.org/) rules.

It is also possible to publish a pre-release version by adding a suffix to the version number. For example, `v1.0.0-dev.1` is a pre-release version of `v1.0.0`.

## Create a new tag

The preferred way to create a new tag is to use GitHub's interface to create a new release.

The automatically generated changelogs for the github release do not need to be modified. Instead, the `CHANGELOG.md` is our source of truth on pub.dev.
