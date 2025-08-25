# WealthsimpleDownloader

WealthsimpleDownloader is a Swift Package Manager library for downloading financial data from Wealthsimple. It provides read-only API access to accounts, positions, and transactions. The library does not support Wealthsimple Trade and requires 2FA-enabled accounts.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

- Bootstrap, build, and test the repository:
  - `swift build` -- takes 8 seconds. NEVER CANCEL. Set timeout to 60+ seconds.
  - `swift test` -- takes 7 seconds. NEVER CANCEL. Set timeout to 30+ seconds.
  - `swift test --enable-code-coverage` -- takes 7 seconds. NEVER CANCEL. Set timeout to 30+ seconds.
  - `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` -- CI command, takes 7 seconds. NEVER CANCEL. Set timeout to 30+ seconds.

- Install and run SwiftLint:
  - `curl -L https://github.com/realm/SwiftLint/releases/download/0.59.1/swiftlint_linux.zip -o swiftlint.zip`
  - `unzip swiftlint.zip -d swiftlint`
  - `./swiftlint/swiftlint lint` -- basic linting
  - `./swiftlint/swiftlint --strict --reporter github-actions-logging` -- CI-style strict linting

- Clean build artifacts:
  - `swift package clean` -- removes .build directory

## Validation

- ALWAYS run through these complete validation steps after making changes:
  1. `swift build` -- ensure library compiles
  2. `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` -- run all tests with coverage and strict warnings
  3. `./swiftlint/swiftlint --strict --reporter github-actions-logging` -- ensure code style compliance
  4. Manual library validation: Create a simple test that imports the library and instantiates basic classes

- You can build and test the library, but there is no runnable application to execute.
- Always run `swift test` and `./swiftlint/swiftlint --strict` before you are done or the CI (.github/workflows/ci.yml) will fail.
- NEVER CANCEL builds or tests - they complete quickly (under 10 seconds each) but use 30-60 second timeouts to be safe.

## Manual Library Validation

After making changes, always validate that the library works by creating a simple test:

```swift
import Wealthsimple

class TestCredentialStorage: CredentialStorage {
    func save(_ value: String, for key: String) {}
    func read(_ key: String) -> String? { return nil }
}

let callback: WealthsimpleDownloader.AuthenticationCallback = { completion in
    completion("user", "pass", "123456")
}

let downloader = WealthsimpleDownloader(
    authenticationCallback: callback,
    credentialStorage: TestCredentialStorage()
)
```

This ensures your changes don't break the library's public API.

## Common Tasks

The following are outputs from frequently run commands. Reference them instead of viewing, searching, or running bash commands to save time.

### Repository root
```
ls -la
total 48
drwxr-xr-x 6 runner docker 4096 .
drwxr-xr-x 3 runner docker 4096 ..
drwxr-xr-x 7 runner docker 4096 .git
drwxr-xr-x 3 runner docker 4096 .github
-rw-r--r-- 1 runner docker   71 .gitignore
-rw-r--r-- 1 runner docker  351 .jazzy.yaml
-rw-r--r-- 1 runner docker 2955 .swiftlint.yml
-rw-r--r-- 1 runner docker 1087 LICENSE
-rw-r--r-- 1 runner docker  466 Package.swift
-rw-r--r-- 1 runner docker 3721 README.md
drwxr-xr-x 3 runner docker 4096 Sources
drwxr-xr-x 3 runner docker 4096 Tests
```

### Sources structure
```
Sources/Wealthsimple/
├── Extensions/
│   └── String+CamelCase.swift
├── Token.swift
├── TransactionError.swift
├── WealthsimpleAccount.swift
├── WealthsimpleAsset.swift
├── WealthsimpleDownloader.swift
├── WealthsimplePosition.swift
└── WealthsimpleTransaction.swift
```

### Tests structure
```
Tests/WealthsimpleTests/
├── Extensions/
│   └── StringCamelCaseTests.swift
└── WealthsimpleDownloaderTests.swift
```

### Key Package.swift content
```swift
// swift-tools-version:5.2
let package = Package(
    name: "WealthsimpleDownloader",
    products: [
        .library(
            name: "Wealthsimple",
            targets: ["Wealthsimple"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Wealthsimple",
            dependencies: []),
        .testTarget(
            name: "WealthsimpleTests",
            dependencies: ["Wealthsimple"]),
    ]
)
```

## Project Details

- **Language**: Swift 6.1.2 (works with Swift 5.2+)
- **Package Manager**: Swift Package Manager
- **Platforms**: linux, macOS, iOS, watchOS, tvOS
- **Dependencies**: None (pure Swift implementation)
- **Documentation**: Available at https://nef10.github.io/WealthsimpleDownloader/
- **CI**: GitHub Actions with ubuntu-latest and macOS-latest runners

## Important Notes

- This is a library-only project - no executable applications or CLI tools
- All API calls are read-only for safety (uses read-only scopes)
- Requires implementing `CredentialStorage` and `AuthenticationCallback` protocols
- Only works with 2FA-enabled Wealthsimple accounts
- Does not support Wealthsimple Trade
- Documentation generation via jazzy currently fails due to sourcekitten issues, but this is not critical
- SwiftLint configuration is comprehensive with 100+ enabled rules
- Code coverage enforcement is enabled in CI
- No network access required for building/testing (mocked API interactions)