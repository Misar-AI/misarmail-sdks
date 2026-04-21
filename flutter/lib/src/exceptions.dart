/// Thrown when the MisarMail API returns a non-2xx response or a network error.
class MisarMailException implements Exception {
  final int statusCode;
  final String message;

  const MisarMailException(this.statusCode, this.message);

  @override
  String toString() => 'MisarMailException($statusCode): $message';
}

/// Thrown for connectivity failures (no response received).
class MisarMailNetworkException extends MisarMailException {
  MisarMailNetworkException(String msg) : super(0, msg);
}
