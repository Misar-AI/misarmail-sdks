using System;
using System.Collections.Generic;
using System.Text;

namespace Misar.Mail.Core;

/// <summary>Query-string encoding shared by every generated GET/DELETE method.</summary>
public static class Query
{
    /// <summary>
    /// Returns an empty string for a null or empty bag so a generated call site
    /// can always append unconditionally. Null values are dropped so optional
    /// filters stay out of the URL entirely.
    /// </summary>
    public static string Encode(IDictionary<string, string>? parameters)
    {
        if (parameters is null || parameters.Count == 0)
        {
            return string.Empty;
        }

        var builder = new StringBuilder();
        foreach (var pair in parameters)
        {
            if (pair.Value is null)
            {
                continue;
            }

            builder.Append(builder.Length == 0 ? '?' : '&')
                   .Append(Uri.EscapeDataString(pair.Key))
                   .Append('=')
                   .Append(Uri.EscapeDataString(pair.Value));
        }

        return builder.ToString();
    }

    /// <summary>
    /// Merges required query parameters under a caller-supplied bag, so an
    /// explicit override still wins. Extras arrive as alternating key/value
    /// arguments because generated call sites always know them at compile time.
    /// </summary>
    public static IDictionary<string, string> With(
        IDictionary<string, string>? parameters,
        params string[] keyValuePairs)
    {
        var merged = new Dictionary<string, string>(StringComparer.Ordinal);

        for (var i = 0; i + 1 < keyValuePairs.Length; i += 2)
        {
            merged[keyValuePairs[i]] = keyValuePairs[i + 1];
        }

        if (parameters is not null)
        {
            foreach (var pair in parameters)
            {
                merged[pair.Key] = pair.Value;
            }
        }

        return merged;
    }
}
