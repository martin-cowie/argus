<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Sources/Argus/Resources/Logo-dark.svg">
    <img src="Sources/Argus/Resources/Logo.svg" alt="Argus" width="320">
  </picture>
</h1>

[![CI](https://github.com/martin-cowie/argus/actions/workflows/ci.yml/badge.svg)](https://github.com/martin-cowie/argus/actions/workflows/ci.yml)

A macOS app for monitoring remote hosts over SSH.

Requires macOS 26 and Swift 6.2.

```sh
make build   # build
make test    # run the tests
make run     # launch the app
make app     # package dist/Argus.app
```
