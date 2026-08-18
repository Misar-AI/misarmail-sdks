class MisarMailError implements Exception {
  final int status;
  final String message;
  MisarMailError(this.status, this.message);
  @override
  String toString() => 'MisarMailError($status): $message';
}

/// Thrown when the subscription attached to the API key blocks the call.
///
/// MisarMail meters per-plan server-side: a spent allowance answers 429 and a
/// feature not on the plan answers 402. This is a distinct type rather than a
/// generic 429 because retrying cannot help until the allowance resets or the
/// plan changes — the client stops retrying on sight.
///
/// Surface [upgradeUrl] rather than reporting a bare failure.
class MisarMailPlanLimitError extends MisarMailError {
  /// The account's current plan slug, when the API reports it.
  final String? plan;

  /// Pricing page to send the user to.
  final String? upgradeUrl;

  /// Seconds until the allowance resets, when supplied.
  final int? retryAfter;

  /// The allowance that was exhausted.
  final String? feature;

  MisarMailPlanLimitError(
    int status,
    String message, {
    this.plan,
    this.upgradeUrl,
    this.retryAfter,
    this.feature,
  }) : super(status, message);

  /// Build from a decoded body plus the response headers. Headers are
  /// authoritative; the offer body is the fallback when a proxy strips them.
  factory MisarMailPlanLimitError.from(
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

    return MisarMailPlanLimitError(
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
      'MisarMailPlanLimitError($status): $message (upgrade: $upgradeUrl)';
}

class MisarMailNetworkError extends MisarMailError {
  MisarMailNetworkError(String msg) : super(0, msg);
}
