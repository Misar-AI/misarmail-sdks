/// Thrown when the MisarMail API returns a non-2xx response or a network error.
class MisarMailException implements Exception {
  final int statusCode;
  final String message;

  const MisarMailException(this.statusCode, this.message);

  @override
  String toString() => 'MisarMailException($statusCode): $message';
}

/// Thrown for connectivity failures (no response received).
/// Thrown when the subscription attached to the API key blocks the call.
///
/// MisarMail meters per-plan server-side: a spent allowance answers 429 and a
/// feature not on the plan answers 402. A distinct type rather than a generic
/// 429 because retrying cannot help until the allowance resets or the plan
/// changes — the client stops retrying on sight.
///
/// Route the user to [upgradeUrl] rather than showing a bare failure.
class MisarMailPlanLimitException extends MisarMailException {
  /// The account's current plan slug, when reported.
  final String? plan;

  /// Pricing page to send the user to.
  final String? upgradeUrl;

  /// Seconds until the allowance resets, when supplied.
  final int? retryAfter;

  /// The allowance that was exhausted.
  final String? feature;

  const MisarMailPlanLimitException(
    int statusCode,
    String message, {
    this.plan,
    this.upgradeUrl,
    this.retryAfter,
    this.feature,
  }) : super(statusCode, message);

  /// Build from a decoded body plus response headers. Headers are
  /// authoritative; the offer body is the fallback when a proxy strips them.
  factory MisarMailPlanLimitException.from(
    int status,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) {
    final h = {for (final e in headers.entries) e.key.toLowerCase(): e.value};
    final offer = body['upgrade'] is Map<String, dynamic>
        ? body['upgrade'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final urls = offer['urls'];
    final current = offer['current_plan'];
    final retry = h['retry-after'];

    return MisarMailPlanLimitException(
      status,
      (body['error'] as String?) ?? 'plan limit exceeded',
      plan: h['x-misar-plan'] ??
          offer['currentPlanSlug'] as String? ??
          (current is Map<String, dynamic> ? current['slug'] as String? : null),
      upgradeUrl: h['x-misar-upgrade-url'] ??
          (urls is Map<String, dynamic> ? urls['pricing'] as String? : null),
      retryAfter: retry == null ? null : int.tryParse(retry),
      feature: offer['feature'] as String?,
    );
  }

  @override
  String toString() =>
      'MisarMailPlanLimitException($statusCode): $message (upgrade: $upgradeUrl)';
}

class MisarMailNetworkException extends MisarMailException {
  MisarMailNetworkException(String msg) : super(0, msg);
}
