# MisarMail SDKs

Official SDKs for the [MisarMail](https://mail.misar.io) transactional + marketing email API.

## SDKs

| Language | Directory | Registry | Package |
|----------|-----------|----------|---------|
| TypeScript / JavaScript | `typescript/` | npm | `@misar/mail` |
| Python | `python/` | PyPI | `misarmail` |
| Go | `go/` | pkg.go.dev | `github.com/Misar-AI/misarmail-sdks/go` |
| Ruby | `ruby/` | RubyGems | `misarmail` |
| PHP | `php/` | Packagist | `misar/mail` |
| Java | `java/` | Maven Central | `io.misar.mail:misarmail-java` |
| Kotlin | `kotlin/` | Maven Central | `io.misar.mail:misarmail-kotlin` |
| C# / .NET | `csharp/` | NuGet | `MisarMail` |
| Rust | `rust/` | crates.io | `misarmail` |
| Dart | `dart/` | pub.dev | `misarmail` |
| Flutter | `flutter/` | pub.dev | `misarmail_flutter` |
| Swift | `swift/` | Swift Package Index | `MisarMail` |
| CLI | `cli/` | npm | `@misar/mail-cli` |
| C | `c/` | GitHub Releases | Binary / libmisarmail |
| C++ | `cpp/` | GitHub Releases | Binary / libmisarmail++ |
| Solidity | `solidity/` | npm | `@misar/mail-solidity` |

## Publishing

Each SDK is published independently via a Git tag matching `<lang>/v<semver>`:

```bash
git tag typescript/v1.2.3 && git push origin typescript/v1.2.3
git tag python/v1.2.3    && git push origin python/v1.2.3
git tag go/v1.2.3        && git push origin go/v1.2.3
# etc.
```

## Required GitHub Secrets

| Secret | Used by |
|--------|---------|
| `NPM_TOKEN` | typescript, cli, solidity |
| `PUB_CREDENTIALS` | dart, flutter |
| `CARGO_TOKEN` | rust |
| `RUBYGEMS_API_KEY` | ruby |
| `NUGET_API_KEY` | csharp |
| `OSSRH_USERNAME` | java, kotlin |
| `OSSRH_PASSWORD` | java, kotlin |
| `GPG_PRIVATE_KEY` | java, kotlin |
| `GPG_PASSPHRASE` | java, kotlin |
| `PACKAGIST_USERNAME` | php |
| `PACKAGIST_TOKEN` | php |

## API Base URL

```
https://mail.misar.io/api/v1
```

Authentication: `Authorization: Bearer <MISARMAIL_API_KEY>` where API keys start with `msk_`.
