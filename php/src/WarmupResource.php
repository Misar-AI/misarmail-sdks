<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * warmup — generated.
 */
class WarmupResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /warmup
     *
     * @return array<string,mixed>
     */
    public function get(): array
    {
        return $this->client->request('GET', '/warmup');
    }


    /**
     * Opens an SSE connection and invokes $onEvent for each decoded frame.
     *
     * Uses API_BASE, since both streaming routes sit outside /v1. Frames end at
     * a blank line and may span several `data:` lines; the `[DONE]` sentinel
     * ends the stream and is not dispatched.
     *
     * Deliberately not retried: replaying a stream that failed mid-flight would
     * duplicate whatever the caller already consumed.
     *
     * @param callable(StreamEvent): (bool|void) $onEvent Returning false stops the stream.
     * @param array<string,mixed>|null           $data
     * @throws ApiError
     * @throws PlanLimitError
     */
    public function sseStream(string $method, string $path, ?array $data, callable $onEvent): void
    {
        $url = self::API_BASE . $path;

        $status      = 0;
        $respHeaders = [];
        $buffer      = '';
        $eventName   = null;
        $dataLines   = [];
        $stopped     = false;
        $errorBody   = '';

        $flush = function () use (&$dataLines, &$eventName, $onEvent): ?bool {
            if ($dataLines === []) {
                $eventName = null;
                return null;
            }
            $raw       = implode("\n", $dataLines);
            $name      = $eventName;
            $dataLines = [];
            $eventName = null;

            if ($raw === '[DONE]') {
                return false; // sentinel: stop
            }
            $decoded = json_decode($raw, true);
            $result  = $onEvent(new StreamEvent($name, is_array($decoded) ? $decoded : null, $raw));

            return $result === false ? false : null;
        };

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $this->apiKey,
                'Accept: text/event-stream',
                'Content-Type: application/json',
            ],
            CURLOPT_TIMEOUT        => 0,   // streams have no fixed duration
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_HEADERFUNCTION => function ($_ch, string $line) use (&$respHeaders, &$status): int {
                if (preg_match('~^HTTP/\d(?:\.\d)? (\d{3})~', $line, $m) === 1) {
                    $status = (int) $m[1];
                } else {
                    $parts = explode(':', $line, 2);
                    if (count($parts) === 2) {
                        $respHeaders[strtolower(trim($parts[0]))] = trim($parts[1]);
                    }
                }
                return strlen($line);
            },
            CURLOPT_WRITEFUNCTION  => function ($_ch, string $chunk) use (
                &$buffer, &$eventName, &$dataLines, &$stopped, &$status, &$errorBody, $flush
            ): int {
                $len = strlen($chunk);

                // On a non-2xx, collect the body so the envelope can be read
                // after the transfer rather than parsed as SSE.
                if ($status < 200 || $status >= 300) {
                    $errorBody .= $chunk;
                    return $len;
                }

                $buffer .= $chunk;
                while (true) {
                    $lf   = strpos($buffer, "\n\n");
                    $crlf = strpos($buffer, "\r\n\r\n");
                    $end  = $lf === false ? $crlf : ($crlf === false ? $lf : min($lf, $crlf));
                    if ($end === false) {
                        break;
                    }
                    $frame  = substr($buffer, 0, $end);
                    $buffer = preg_replace('~^(\r?\n){1,2}~', '', substr($buffer, $end)) ?? '';

                    foreach (preg_split('~\r?\n~', $frame) ?: [] as $line) {
                        if ($line === '' || str_starts_with($line, ':')) {
                            continue; // keepalive
                        }
                        if (str_starts_with($line, 'event:')) {
                            $eventName = trim(substr($line, 6));
                        } elseif (str_starts_with($line, 'data:')) {
                            $rest        = substr($line, 5);
                            $dataLines[] = str_starts_with($rest, ' ') ? substr($rest, 1) : $rest;
                        }
                    }

                    if ($flush() === false) {
                        $stopped = true;
                        // Returning 0 signals EOF to libcurl and stops the transfer.
                        return 0;
                    }
                }
                return $len;
            },
        ]);
        if ($data !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data, JSON_THROW_ON_ERROR));
        }

        curl_exec($ch);
        $curlErrno = curl_errno($ch);
        curl_close($ch);

        if ($status >= 400) {
            $decoded = json_decode($errorBody, true);
            $decoded = is_array($decoded) ? $decoded : [];
            $planLimit = ($decoded['code'] ?? null) === 'plan_limit_exceeded'
                || is_array($decoded['upgrade'] ?? null);
            if ($planLimit) {
                $offer = is_array($decoded['upgrade'] ?? null) ? $decoded['upgrade'] : [];
                throw new PlanLimitError(
                    (string) ($decoded['error'] ?? 'plan limit exceeded'),
                    $status,
                    isset($respHeaders['x-misar-plan'])
                        ? $respHeaders['x-misar-plan']
                        : ($offer['currentPlanSlug'] ?? null),
                    $respHeaders['x-misar-upgrade-url'] ?? ($offer['urls']['pricing'] ?? null),
                    isset($respHeaders['retry-after']) && ctype_digit($respHeaders['retry-after'])
                        ? (int) $respHeaders['retry-after']
                        : null,
                    $offer['feature'] ?? null,
                );
            }
            throw new ApiError(
                (string) ($decoded['error'] ?? ($errorBody !== '' ? $errorBody : 'stream error')),
                $status,
            );
        }

        // CURLE_WRITE_ERROR (23) is how the callback signals an intentional stop.
        if ($curlErrno !== 0 && !$stopped) {
            throw new NetworkError("cURL error ({$curlErrno}) during stream");
        }

        // A trailing frame with no closing blank line.
        if (!$stopped && trim($buffer) !== '') {
            foreach (preg_split('~\r?\n~', $buffer) ?: [] as $line) {
                if ($line === '' || str_starts_with($line, ':')) {
                    continue;
                }
                if (str_starts_with($line, 'event:')) {
                    $eventName = trim(substr($line, 6));
                } elseif (str_starts_with($line, 'data:')) {
                    $rest        = substr($line, 5);
                    $dataLines[] = str_starts_with($rest, ' ') ? substr($rest, 1) : $rest;
                }
            }
            $flush();
        }
    }

}
