# misar_mail_flutter

Official Flutter SDK for the [MisarMail](https://mail.misar.io) email API.

## Installation

```yaml
# pubspec.yaml
dependencies:
  misar_mail_flutter:
    path: ../flutter   # or publish to pub.dev
```

## Initialization

### Option A — Secure Storage (recommended for mobile)

Store the key once (e.g. after login):

```dart
import 'package:misar_mail_flutter/misar_mail_flutter.dart';

final store = SecureKeyStore();
await store.saveApiKey('msk_your_api_key');
```

Then load it anywhere in your app:

```dart
final client = await MisarMailClient.withSecureStorage();
```

The key is persisted in the platform keychain (iOS Keychain / Android Keystore) via `flutter_secure_storage`.

### Option B — Direct API key

```dart
final client = MisarMailClient(apiKey: 'msk_your_api_key');
```

Use this in tests, CI, or server-side Dart environments where secure storage is unavailable.

## Usage

### Send an email

```dart
await client.sendEmail({
  'to': 'recipient@example.com',
  'subject': 'Hello from MisarMail',
  'html': '<p>Hi there!</p>',
});
```

### Contacts

```dart
final contacts = await client.contactsList();

await client.contactsCreate({
  'email': 'new@example.com',
  'first_name': 'Jane',
});
```

### Campaigns

```dart
final campaigns = await client.campaignsList();

await client.campaignsCreate({
  'name': 'Spring Launch',
  'subject': 'Big news!',
  'template_id': 'tmpl_abc',
});
```

### Analytics

```dart
final stats = await client.analyticsGet('camp_abc123');
print(stats['opens']);
```

### Validate an email address

```dart
final result = await client.validateEmail('user@example.com');
print(result['valid']); // true | false
```

### Templates

```dart
final templates = await client.templatesList();

final rendered = await client.templatesRender('tmpl_abc', {
  'first_name': 'Alice',
  'promo_code': 'SAVE20',
});
print(rendered['html']);
```

### Tracking

```dart
await client.trackEvent({'event': 'button_click', 'email': 'u@example.com'});
await client.trackPurchase({'amount': 4999, 'email': 'u@example.com'});
```

### Other endpoints

```dart
await client.keysList();
await client.abTestsList();
await client.sandboxList();
await client.inboundList();
```

## Error handling

```dart
import 'package:misar_mail_flutter/misar_mail_flutter.dart';

try {
  await client.sendEmail({...});
} on MisarMailException catch (e) {
  print('API error ${e.statusCode}: ${e.message}');
} on MisarMailNetworkException catch (e) {
  print('Network error: ${e.message}');
}
```

Requests failing with status `429 500 502 503 504` are retried up to 3 times with exponential backoff (`500ms × 2^attempt`).

## SecureKeyStore API

| Method | Description |
|--------|-------------|
| `saveApiKey(String key)` | Persists the key in the platform keychain |
| `loadApiKey()` | Returns the stored key or `null` |
| `deleteApiKey()` | Removes the stored key (use on logout) |

## Running tests

```bash
flutter test
```

Mocks are generated with `build_runner`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
