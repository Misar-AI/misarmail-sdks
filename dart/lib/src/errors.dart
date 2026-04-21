class MisarMailError implements Exception {
  final int status;
  final String message;
  MisarMailError(this.status, this.message);
  @override
  String toString() => 'MisarMailError($status): $message';
}

class MisarMailNetworkError extends MisarMailError {
  MisarMailNetworkError(String msg) : super(0, msg);
}
