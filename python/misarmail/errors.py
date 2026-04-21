class MisarMailError(Exception):
    def __init__(self, status: int, message: str, error_type: str = "api_error"):
        self.status = status
        self.error_type = error_type
        super().__init__(f"misar-mail: API error {status} ({error_type}): {message}")


class MisarMailNetworkError(MisarMailError):
    def __init__(self, message: str, cause: Exception | None = None):
        self.cause = cause
        super().__init__(0, message, "network_error")
