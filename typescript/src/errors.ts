export class MisarMailError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly errorType: string = "api_error",
    readonly details?: unknown,
  ) {
    super(message);
    this.name = "MisarMailError";
  }
}

export class MisarMailNetworkError extends MisarMailError {
  constructor(message: string, cause?: unknown) {
    super(0, message, "network_error");
    this.name = "MisarMailNetworkError";
    if (cause) this.cause = cause;
  }
}
