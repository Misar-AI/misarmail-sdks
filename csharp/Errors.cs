namespace Misar.Mail;

/// <summary>
/// Thrown when the MisarMail API returns a non-2xx HTTP response.
/// </summary>
public class MisarMailException : Exception
{
    /// <summary>HTTP status code returned by the server.</summary>
    public int Status { get; }

    public MisarMailException(int status, string message)
        : base($"MisarMailException({status}): {message}")
    {
        Status = status;
    }

    public MisarMailException(int status, string message, Exception inner)
        : base($"MisarMailException({status}): {message}", inner)
    {
        Status = status;
    }
}

/// <summary>
/// Thrown when a network-level error prevents the request from completing,
/// or when the maximum number of retries is exhausted.
/// </summary>
public sealed class MisarMailNetworkException : MisarMailException
{
    public MisarMailNetworkException(string message)
        : base(0, message) { }

    public MisarMailNetworkException(string message, Exception inner)
        : base(0, message, inner) { }
}
