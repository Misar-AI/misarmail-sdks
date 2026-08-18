<?php

declare(strict_types=1);

namespace MisarMail;

class Client
{
    public readonly PlanResource         $plan;
    public readonly StreamingResource    $streaming;
    public readonly AiResource $ai;
    public readonly CreditRatesResource $creditRates;
    public readonly DeliverabilityResource $deliverability;
    public readonly DmarcResource $dmarc;
    public readonly EmailAccountsResource $emailAccounts;
    public readonly EmailsResource $emails;
    public readonly LandingPagesResource $landingPages;
    public readonly MonetizationResource $monetization;
    public readonly RevenueResource $revenue;
    public readonly SegmentsResource $segments;
    public readonly SubscriptionResource $subscription;
    public readonly TeamMembersResource $teamMembers;
    public readonly WalletResource $wallet;
    public readonly WarmupResource $warmup;
    public readonly EmailResource        $email;
    public readonly ContactsResource     $contacts;
    public readonly CampaignsResource    $campaigns;
    public readonly TemplatesResource    $templates;
    public readonly AutomationsResource  $automations;
    public readonly DomainsResource      $domains;
    public readonly DedicatedIpsResource $dedicatedIps;
    public readonly AbTestsResource      $abTests;
    public readonly SandboxResource      $sandbox;
    public readonly InboundResource      $inbound;
    public readonly AnalyticsResource    $analytics;
    public readonly TrackResource        $track;
    public readonly KeysResource         $keys;
    public readonly ValidateResource     $validate;
    public readonly WebhooksResource     $webhooks;
    public readonly UsageResource        $usage;
    public readonly BillingResource      $billing;

    private const BASE_URL      = 'https://api.misar.io/mail/v1';
    /** Host for routes outside /v1 — both streaming endpoints live there. */
    private const API_BASE      = 'https://api.misar.io/mail';
    private const RETRYABLE     = [429, 500, 502, 503, 504];
    private const RETRY_BASE_MS = 300;
    private const MAX_RETRIES   = 3;

    /** Versioned base, e.g. https://api.misar.io/mail/v1 */
    public readonly string $baseUrl;
    /** Unversioned base for the routes that sit outside /v1, e.g. the SSE endpoints. */
    public readonly string $apiBase;

    /**
     * @param string      $apiKey  Key from the dashboard; the subscription attached
     *                             to it is what the server meters against.
     * @param int         $timeout Per-request timeout in seconds. Streams ignore it.
     * @param string|null $baseUrl Override the API host. Intended for tests and
     *                             self-hosted deployments; leave null in production.
     */
    public function __construct(
        private readonly string $apiKey,
        private readonly int    $timeout = 30,
        ?string $baseUrl = null,
    ) {
        $this->baseUrl = rtrim($baseUrl ?? self::BASE_URL, '/');
        // Both SSE routes live off the version prefix, so derive rather than
        // asking the caller for a second URL they could get out of step.
        $this->apiBase = str_ends_with($this->baseUrl, '/v1')
            ? substr($this->baseUrl, 0, -3)
            : $this->baseUrl;

        $this->plan = new PlanResource($this);
        $this->streaming = new StreamingResource($this);
        $this->ai = new AiResource($this);
        $this->creditRates = new CreditRatesResource($this);
        $this->deliverability = new DeliverabilityResource($this);
        $this->dmarc = new DmarcResource($this);
        $this->emailAccounts = new EmailAccountsResource($this);
        $this->emails = new EmailsResource($this);
        $this->landingPages = new LandingPagesResource($this);
        $this->monetization = new MonetizationResource($this);
        $this->revenue = new RevenueResource($this);
        $this->segments = new SegmentsResource($this);
        $this->subscription = new SubscriptionResource($this);
        $this->teamMembers = new TeamMembersResource($this);
        $this->wallet = new WalletResource($this);
        $this->warmup = new WarmupResource($this);
        $this->email        = new EmailResource($this);
        $this->contacts     = new ContactsResource($this);
        $this->campaigns    = new CampaignsResource($this);
        $this->templates    = new TemplatesResource($this);
        $this->automations  = new AutomationsResource($this);
        $this->domains      = new DomainsResource($this);
        $this->dedicatedIps = new DedicatedIpsResource($this);
        $this->abTests      = new AbTestsResource($this);
        $this->sandbox      = new SandboxResource($this);
        $this->inbound      = new InboundResource($this);
        $this->analytics    = new AnalyticsResource($this);
        $this->track        = new TrackResource($this);
        $this->keys         = new KeysResource($this);
        $this->validate     = new ValidateResource($this);
        $this->webhooks     = new WebhooksResource($this);
        $this->usage        = new UsageResource($this);
        $this->billing      = new BillingResource($this);
    }

    /**
     * @throws ApiError
     * @throws NetworkError
     */
    public function request(
        string  $method,
        string  $path,
        array   $data = [],
        ?string $baseOverride = null,
    ): array {
        $base     = rtrim($baseOverride ?? $this->baseUrl, '/');
        $url      = $base . '/' . ltrim($path, '/');
        $hasBody  = !empty($data) && in_array($method, ['POST', 'PUT', 'PATCH'], true);
        $jsonBody = $hasBody ? json_encode($data, JSON_THROW_ON_ERROR) : null;

        $headers = [
            'Authorization: Bearer ' . $this->apiKey,
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        $lastStatus = 0;

        for ($attempt = 0; $attempt < self::MAX_RETRIES; $attempt++) {
            $respHeaders = [];
            $ch = curl_init();

            curl_setopt_array($ch, [
                CURLOPT_URL            => $url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER     => $headers,
                CURLOPT_CUSTOMREQUEST  => $method,
                CURLOPT_TIMEOUT        => $this->timeout,
                CURLOPT_CONNECTTIMEOUT => 10,
                CURLOPT_FOLLOWLOCATION => false,
                CURLOPT_HEADERFUNCTION => function ($_ch, string $line) use (&$respHeaders): int {
                    $parts = explode(':', $line, 2);
                    if (count($parts) === 2) {
                        $respHeaders[strtolower(trim($parts[0]))] = trim($parts[1]);
                    }
                    return strlen($line);
                },
            ]);

            if ($jsonBody !== null) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonBody);
            }

            $body      = curl_exec($ch);
            $curlErrno = curl_errno($ch);
            $curlError = curl_error($ch);
            $status    = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($curlErrno !== 0) {
                if ($attempt < self::MAX_RETRIES - 1) {
                    usleep(self::RETRY_BASE_MS * (1 << $attempt) * 1000);
                    continue;
                }
                throw new NetworkError("cURL error ({$curlErrno}): {$curlError}");
            }

            $lastStatus = $status;

            // A rate-limit 429 and a spent-allowance 429 are identical by
            // status, so the body decides. Only the first is worth retrying.
            $planLimit = self::planLimitBody((string) $body);
            if ($planLimit !== null) {
                throw self::planLimitError($status, $planLimit, $respHeaders);
            }

            if (in_array($status, self::RETRYABLE, true) && $attempt < self::MAX_RETRIES - 1) {
                usleep(self::RETRY_BASE_MS * (1 << $attempt) * 1000);
                continue;
            }

            if ($status === 204 || $body === '' || $body === false) {
                return [];
            }

            $decoded = json_decode((string) $body, true);

            if ($status >= 400) {
                $msg = is_array($decoded)
                    ? ($decoded['error'] ?? $decoded['message'] ?? (string) $body)
                    : (string) $body;
                throw new ApiError($msg, $status);
            }

            return is_array($decoded) ? $decoded : [];
        }

        throw new ApiError('Max retries exceeded', $lastStatus);
    }
    /**
     * Returns the decoded body when it carries the API's plan-refusal marker.
     *
     * @return array<string,mixed>|null
     */
    private static function planLimitBody(string $body): ?array
    {
        if ($body === '') {
            return null;
        }
        $d = json_decode($body, true);
        if (!is_array($d)) {
            return null;
        }
        $isLimit = ($d['code'] ?? null) === 'plan_limit_exceeded'
            || ($d['error_type'] ?? null) === 'plan_limit_exceeded'
            || is_array($d['upgrade'] ?? null);

        return $isLimit ? $d : null;
    }

    /**
     * @param array<string,mixed> $body
     * @param array<string,string> $headers
     */
    private static function planLimitError(int $status, array $body, array $headers): PlanLimitError
    {
        $offer = is_array($body['upgrade'] ?? null) ? $body['upgrade'] : [];
        // Headers are authoritative; the offer body is the fallback when a
        // proxy has stripped them.
        $plan = $headers['x-misar-plan']
            ?? ($offer['currentPlanSlug'] ?? $offer['current_plan']['slug'] ?? null);
        $upgradeUrl = $headers['x-misar-upgrade-url'] ?? ($offer['urls']['pricing'] ?? null);
        $retryAfter = isset($headers['retry-after']) && ctype_digit($headers['retry-after'])
            ? (int) $headers['retry-after']
            : null;

        return new PlanLimitError(
            (string) ($body['error'] ?? 'plan limit exceeded'),
            $status,
            $plan !== null ? (string) $plan : null,
            $upgradeUrl !== null ? (string) $upgradeUrl : null,
            $retryAfter,
            isset($offer['feature']) ? (string) $offer['feature'] : null,
        );
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
        $status      = 0;
        $respHeaders = [];
        $buffer      = '';
        $eventName   = null;
        $dataLines   = [];
        $stopped     = false;
        $errorBody   = '';

        $consume = function (string $frame) use (&$eventName, &$dataLines): void {
            foreach (preg_split('~\r?\n~', $frame) ?: [] as $line) {
                if ($line === '' || str_starts_with($line, ':')) {
                    continue; // blank or keepalive comment
                }
                if (str_starts_with($line, 'event:')) {
                    $eventName = trim(substr($line, 6));
                } elseif (str_starts_with($line, 'data:')) {
                    $rest        = substr($line, 5);
                    $dataLines[] = str_starts_with($rest, ' ') ? substr($rest, 1) : $rest;
                }
            }
        };

        // Returns false to stop the stream: either the [DONE] sentinel or the
        // caller's handler asking to stop.
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
                return false;
            }
            $decoded = json_decode($raw, true);
            $result  = $onEvent(new StreamEvent($name, is_array($decoded) ? $decoded : null, $raw));

            return $result === false ? false : null;
        };

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $this->apiBase . $path,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $this->apiKey,
                'Accept: text/event-stream',
                'Content-Type: application/json',
            ],
            CURLOPT_TIMEOUT        => 0,   // a stream has no fixed duration
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
                &$buffer, &$stopped, &$status, &$errorBody, $consume, $flush
            ): int {
                $len = strlen($chunk);

                // On a refusal, collect the body so the envelope can be read
                // after the transfer rather than parsed as SSE.
                if ($status < 200 || $status >= 300) {
                    $errorBody .= $chunk;
                    return $len;
                }

                $buffer .= $chunk;
                while (true) {
                    $lf   = strpos($buffer, "\n\n");
                    $crlf = strpos($buffer, "\r\n\r\n");
                    if ($lf === false && $crlf === false) {
                        break;
                    }
                    $end = $lf === false ? $crlf : ($crlf === false ? $lf : min($lf, $crlf));

                    $consume(substr($buffer, 0, $end));
                    $buffer = preg_replace('~^(\r?\n){1,2}~', '', substr($buffer, $end)) ?? '';

                    if ($flush() === false) {
                        $stopped = true;
                        // Returning 0 signals EOF to libcurl and ends the transfer.
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
            $offer   = is_array($decoded['upgrade'] ?? null) ? $decoded['upgrade'] : null;

            if (($decoded['code'] ?? null) === 'plan_limit_exceeded' || $offer !== null) {
                $retryAfter = $respHeaders['retry-after'] ?? null;
                throw new PlanLimitError(
                    (string) ($decoded['error'] ?? 'plan limit exceeded'),
                    $status,
                    $respHeaders['x-misar-plan'] ?? ($offer['currentPlanSlug'] ?? null),
                    $respHeaders['x-misar-upgrade-url'] ?? ($offer['urls']['pricing'] ?? null),
                    $retryAfter !== null && ctype_digit($retryAfter) ? (int) $retryAfter : null,
                    $offer['feature'] ?? null,
                );
            }
            $message = $decoded['error'] ?? trim($errorBody);
            throw new ApiError(is_string($message) && $message !== '' ? $message : 'stream error', $status);
        }

        if ($curlErrno !== 0 && !$stopped) {
            throw new NetworkError("cURL error ({$curlErrno}) during stream");
        }

        // A trailing frame the server never terminated with a blank line.
        if (!$stopped && trim($buffer) !== '') {
            $consume($buffer);
            $flush();
        }
    }

}
