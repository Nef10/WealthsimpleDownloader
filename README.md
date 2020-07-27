# WealthsimpleDownloader

[![CI Status](https://github.com/Nef10/WealthsimpleDownloader/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/WealthsimpleDownloader/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/WealthsimpleDownloader/badge.svg)](https://nef10.github.io/WealthsimpleDownloader/) [![License: MIT](https://img.shields.io/github/license/Nef10/WealthsimpleDownloader)](https://github.com/Nef10/WealthsimpleDownloader/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/WealthsimpleDownloader?label=SemVer&sort=semver)](https://github.com/Nef10/WealthsimpleDownloader/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

## What

This is a small library to download data from Wealthsimple. It does not support Wealthsimple Trade and currently only supports downloading positions. The documentation of the Wealthsimple API I am using can be found at https://developers.wealthsimple.com/. To authenticate I am using the same client id as their web site, which uses the same API as backend.

## How

1) Implement a `CredentialStore` 
<details>
  <summary>Example using the KeychainAccess library</summary>
  
  ```swift
import KeychainAccess
    
class KeyChainCredentialStorage: CredentialStorage {

    let keychain = Keychain(service: "XYZ")

    func save(_ value: String, for key: String) {
        keychain[key] = value
    }

    func read(_ key: String) -> String? {
        keychain[key]
    }

}
  ```
</details>

2) Implement an `AuthenticationCallback` which will ask the user for their username, password and one time password.
3) Initialize `WealthsimpleDownloader` with your two implementations: `let wealthsimpleDownloader = WealthsimpleDownloader(authenticationCallback: myAuthenticationCallback, credentialStorage: myCredentialStorage)`
4) Call `wealthsimpleDownloader.authenticate() { }` and wait for the callback
5) Now you can start retreiving data with the other methods provided on `WealthsimpleDownloader` like `getAccounts` or `getPositions`

Please check out the complete documentation [here](https://nef10.github.io/WealthsimpleDownloader/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/WealthsimpleDownloader.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/WealthsimpleDownloader/blob/main/LICENSE), the source repository may include names or other trademarks of Wealthsimple or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affilliated with Wealthsimple other than beeing customer.
