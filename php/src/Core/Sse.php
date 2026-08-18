<?php

declare(strict_types=1);

namespace MisarMail\Core;

use MisarMail\ApiError;

/**
 * Server-Sent Events client for the MisarMail streaming endpoints.
 *
 * Both streams frame events as "data: <json>" and close with the sentinel
 * "data: [DONE]". One of the two is a POST, so this uses a cURL write callback
 * rather than an EventSource-style helper.
 */
final class Sse
{
    private const DONE = '[DONE]';

    /**
     * Opens an SSE endpoint and hands each decoded frame to $onEvent until the
     * stream terminates. Blocks for the life of the stream.
     *
     * @param callable(array<string, mixed>): void $onEvent
     */
    public static function stream(
        string $url,
        string $apiKey,
        string $method,
        mixed $body,
        callable $onEvent,
    ): void {
        $handle = curl_init($url);
        $headers = [
            'Authorization: Bearer ' . $apiKey,
            'Accept: text/event-stream',
        ];

        if ($body !== null) {
            $headers[] = 'Content-Type: application/json';
        }

        $buffer = '';
        $stopped = false;

        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => strtoupper($method),
            CURLOPT_HTTPHEADER => $headers,
            // A stream has no useful deadline.
            CURLOPT_TIMEOUT => 0,
            CURLOPT_WRITEFUNCTION => function ($_handle, string $chunk) use (
                &$buffer, &$stopped, $onEvent
            ): int {
                $length = strlen($chunk);
                if ($stopped) {
                    return $length;
                }

                $buffer .= $chunk;

                while (($index = strpos($buffer, "\n")) !== false) {
                    $line = rtrim(substr($buffer, 0, $index), "\r");
                    $buffer = substr($buffer, $index + 1);

                    if (!str_starts_with($line, 'data:')) {
                        continue;
                    }

                    $payload = trim(substr($line, 5));
                    if ($payload === self::DONE) {
                        $stopped = true;
                        return $length;
                    }
                    if ($payload === '') {
                        continue;
                    }

                    $decoded = json_decode($payload, true);
                    // One malformed frame should not discard everything already
                    // streamed.
                    $onEvent(is_array($decoded) ? $decoded : ['raw' => $payload]);
                }

                return $length;
            },
        ]);

        if ($body !== null) {
            curl_setopt($handle, CURLOPT_POSTFIELDS, json_encode($body, JSON_THROW_ON_ERROR));
        }

        curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_error($handle);
        curl_close($handle);

        if ($status >= 400) {
            throw new ApiError($status, $error !== '' ? $error : 'stream failed');
        }
    }
}
