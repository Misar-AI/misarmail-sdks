<?php

declare(strict_types=1);

namespace MisarMail\Core;

use MisarMail\ApiError;
use MisarMail\NetworkError;

/**
 * HTTP transport shared by the generated resource layer.
 *
 * Everything the SDK does goes through one of three transports — HTTP for REST,
 * SSE for streaming, WebSocket for push — and all three authenticate the same
 * way: the account API key, sent as a bearer token. There is no second
 * credential path. What a key may do, and how much of it, is decided
 * server-side from the subscription behind that key.
 *
 * Built on cURL rather than Guzzle so the SDK has no hard HTTP dependency;
 * ext-curl ships with essentially every PHP install.
 */
final class Transport
{
    private const RETRYABLE_STATUSES = [429, 500, 502, 503, 504];

    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl = 'https://api.misar.io/mail',
        private readonly int $maxRetries = 3,
        private readonly int $timeoutSeconds = 30,
    ) {
        if ($apiKey === '') {
            throw new \InvalidArgumentException(
                'A MisarMail API key is required. Create one at https://mail.misar.io/settings/api-keys.'
            );
        }
    }

    public function apiKey(): string
    {
        return $this->apiKey;
    }

    public function baseUrl(): string
    {
        return rtrim($this->baseUrl, '/');
    }

    /**
     * Issue a request against a manifest path and decode the JSON body.
     *
     * @param  mixed $body
     * @return array<string, mixed>
     */
    public function request(string $method, string $path, mixed $body = null): array
    {
        $url = $this->baseUrl() . $path;

        for ($attempt = 0; ; $attempt++) {
            [$status, $responseBody, $retryAfter, $error] = $this->send($method, $url, $body);

            if ($error !== null) {
                if ($attempt < $this->maxRetries - 1) {
                    usleep($this->backoffMicroseconds($attempt, null));
                    continue;
                }
                throw new NetworkError($error);
            }

            if (in_array($status, self::RETRYABLE_STATUSES, true) && $attempt < $this->maxRetries - 1) {
                usleep($this->backoffMicroseconds($attempt, $retryAfter));
                continue;
            }

            return $this->decode($status, $responseBody);
        }
    }

    /**
     * @return array{0: int, 1: string, 2: ?int, 3: ?string}
     */
    private function send(string $method, string $url, mixed $body): array
    {
        $handle = curl_init($url);
        $headers = [
            'Authorization: Bearer ' . $this->apiKey,
            'Content-Type: application/json',
        ];

        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => strtoupper($method),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_TIMEOUT => $this->timeoutSeconds,
            CURLOPT_HEADER => true,
        ]);

        if ($body !== null) {
            curl_setopt($handle, CURLOPT_POSTFIELDS, json_encode($body, JSON_THROW_ON_ERROR));
        }

        $raw = curl_exec($handle);
        if ($raw === false) {
            $message = curl_error($handle);
            curl_close($handle);

            return [0, '', null, $message];
        }

        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $headerSize = (int) curl_getinfo($handle, CURLINFO_HEADER_SIZE);
        curl_close($handle);

        $rawHeaders = substr((string) $raw, 0, $headerSize);
        $responseBody = substr((string) $raw, $headerSize);

        $retryAfter = null;
        if (preg_match('/^retry-after:\s*(\d+)/im', $rawHeaders, $matches) === 1) {
            $retryAfter = (int) $matches[1];
        }

        return [$status, $responseBody, $retryAfter, null];
    }

    /**
     * @return array<string, mixed>
     */
    private function decode(int $status, string $body): array
    {
        $data = [];
        if ($body !== '') {
            $decoded = json_decode($body, true);
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }

        if ($status >= 400) {
            $message = $data['error'] ?? $data['message'] ?? 'HTTP ' . $status;
            throw new ApiError($status, (string) $message, (string) ($data['error_type'] ?? 'api_error'), $data);
        }

        return $data;
    }

    /**
     * Exponential backoff, but honour Retry-After when the server sends one: on
     * a 429 the server knows when the window reopens, and guessing wastes the
     * caller's remaining budget.
     */
    private function backoffMicroseconds(int $attempt, ?int $retryAfterSeconds): int
    {
        if ($retryAfterSeconds !== null && $retryAfterSeconds >= 0) {
            return min($retryAfterSeconds, 60) * 1_000_000;
        }

        return (int) (200_000 * (2 ** $attempt));
    }
}
