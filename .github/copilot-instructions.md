# WealthsimpleDownloader

WealthsimpleDownloader is a Swift Package Manager library for downloading financial data from Wealthsimple. It provides read-only API access to accounts, positions, and transactions. The library does not support Wealthsimple Trade and requires 2FA-enabled accounts.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

- Bootstrap, build, and test the repository:
  - Install Swift if not available: `curl -s https://swift.org/install/install.sh | bash` or use swift-actions/setup-swift
  - `swift build` -- takes 8 seconds. NEVER CANCEL. Set timeout to 60+ seconds.
  - `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` -- CI command, takes 7 seconds. NEVER CANCEL. Set timeout to 30+ seconds.

- Install and run SwiftLint:
  - Check the `Install SwiftLint` step in `.github/workflows/ci.yml` for the exact path and version to curl and unzip
  - Run `./swiftlint/swiftlint --strict` -- CI-style strict linting

- Clean build artifacts:
  - `swift package clean` -- removes .build directory

## Validation

- ALWAYS run through these complete validation steps after making changes:
  1. `swift build` -- ensure library compiles
  2. `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` -- run all tests with coverage and strict warnings. All tests MUST pass - no skipping or ignoring failed tests
  3. `./swiftlint/swiftlint --strict` -- ensure code style compliance. Lint MUST return 0 warning and 0 errors.

- You can build and test the library, but there is no runnable application to execute.
- Always run `swift test -Xswiftc -warnings-as-errors` and `./swiftlint/swiftlint --strict` before you are done or the CI (.github/workflows/ci.yml) will fail.
- NEVER CANCEL builds or tests - they complete quickly (under 10 seconds each) but use 30-60 second timeouts to be safe.
- New code MUST be accompanied by tests. NEVER do external network calls in the test, everything must be mocked.

## Project Details

- **Language**: Swift 6.1.2 (works with Swift 5.2+)
- **Package Manager**: Swift Package Manager
- **Platforms**: linux, macOS, iOS, watchOS, tvOS
- **Dependencies**: None (pure Swift implementation)
- **Documentation**: Available at https://nef10.github.io/WealthsimpleDownloader/
- **CI**: GitHub Actions with ubuntu-latest and macOS-latest runners

## Important Notes

- This is a library-only project - no executable applications or CLI tools
- Requires implementing `CredentialStorage` and `AuthenticationCallback` protocols for external usage of the library
- SwiftLint configuration is comprehensive with 100+ enabled rules
- Code coverage enforcement is enabled in CI
- No network access required for building/testing
