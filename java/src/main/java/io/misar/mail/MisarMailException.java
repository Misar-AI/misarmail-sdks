package io.misar.mail;

/**
 * Thrown when the MisarMail API returns a non-2xx HTTP response, or when a
 * network-level error prevents the request from completing.
 *
 * <p>For network errors the {@code status} is {@code 0}.
 */
public class MisarMailException extends Exception {

    private final int status;

    /**
     * @param status  HTTP status code (0 for network errors).
     * @param message Human-readable description.
     */
    public MisarMailException(int status, String message) {
        super("MisarMailException(" + status + "): " + message);
        this.status = status;
    }

    /**
     * @param status  HTTP status code (0 for network errors).
     * @param message Human-readable description.
     * @param cause   Underlying throwable.
     */
    public MisarMailException(int status, String message, Throwable cause) {
        super("MisarMailException(" + status + "): " + message, cause);
        this.status = status;
    }

    /**
     * Convenience constructor — wraps a non-HTTP exception (network errors).
     *
     * @param message Human-readable description.
     * @param cause   Underlying throwable.
     */
    public MisarMailException(String message, Throwable cause) {
        super("MisarMailException(0): " + message, cause);
        this.status = 0;
    }

    /**
     * Convenience constructor — wraps a non-HTTP exception with a status code.
     *
     * @param message Human-readable description.
     * @param status  HTTP status code.
     */
    public MisarMailException(String message, int status) {
        super("MisarMailException(" + status + "): " + message);
        this.status = status;
    }

    /** HTTP status code returned by the server, or {@code 0} for network errors. */
    public int getStatus() {
        return status;
    }
}
