# MisarMail SDKs

Official SDKs for the [MisarMail API](https://mail.misar.io/docs/api-reference) — transactional email, campaigns, contacts, CRM, and lead finder.

## Available SDKs

| Language | Directory | Package | Install |
|----------|-----------|---------|---------|
| TypeScript / JS | [typescript/](typescript/) | `@misarmail/sdk` on npm | `npm install @misarmail/sdk` |
| Python | [python/](python/) | `misarmail` on PyPI | `pip install misarmail` |
| Go | [go/](go/) | `github.com/Misar-AI/misarmail-sdks/go` | `go get github.com/Misar-AI/misarmail-sdks/go` |
| PHP | [php/](php/) | `misarai/misarmail-php` on Packagist | `composer require misarai/misarmail-php` |
| Ruby | [ruby/](ruby/) | `misarmail` on RubyGems | `gem install misarmail` |
| Rust | [rust/](rust/) | `misarmail` on crates.io | `cargo add misarmail` |
| Dart | [dart/](dart/) | `misarmail` on pub.dev | `dart pub add misarmail` |
| Flutter | [flutter/](flutter/) | `misar_mail_flutter` on pub.dev | `flutter pub add misar_mail_flutter` |
| C# / .NET | [csharp/](csharp/) | `Misar.Mail` on NuGet | `dotnet add package Misar.Mail` |
| Java | [java/](java/) | `io.misar:misarmail-java` on Maven Central | See [java/README.md](java/README.md) |
| Kotlin | [kotlin/](kotlin/) | `io.misar:misarmail-kotlin` on Maven Central | See [kotlin/README.md](kotlin/README.md) |
| Swift | [swift/](swift/) | SPM from this repo | `.package(url: "https://github.com/Misar-AI/misarmail-sdks", from: "1.0.0")` |

## Publishing

Each SDK publishes automatically when a tag is pushed in the format `{language}/v{version}`:

```bash
git tag typescript/v1.0.0
git push origin typescript/v1.0.0
```

See [PUBLISHING.md](PUBLISHING.md) for required secrets and registry setup.

## Documentation

Full API reference and SDK guides at [mail.misar.io/docs](https://mail.misar.io/docs).

## License

MIT
