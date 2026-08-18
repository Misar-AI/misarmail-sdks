<?php
/**
 * Canned MisarMail API for the SDK tests, served by `php -S`.
 *
 * Replays the exact shapes the real route handlers emit — including the SSE
 * dialect (unnamed frames, `data: [DONE]` sentinel) and the plan-limit
 * envelope — so the tests exercise the SDK's real cURL transport rather than a
 * mock of a transport it does not use.
 */
declare(strict_types=1);

$path    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';
$counter = sys_get_temp_dir() . '/misarmail-test-counter';

function json(int $status, array $body, array $headers = []): void
{
    http_response_code($status);
    header('Content-Type: application/json');
    foreach ($headers as $k => $v) {
        header("$k: $v");
    }
    echo json_encode($body);
}

// Auth is checked first: every route below is key-gated on the real server.
if (($_SERVER['HTTP_AUTHORIZATION'] ?? '') !== 'Bearer test-key') {
    json(401, ['error' => 'unauthorized']);
    return;
}

switch (true) {
    case $path === '/mail/v1/send' && $_SERVER['REQUEST_METHOD'] === 'POST':
        json(200, ['success' => true, 'message_id' => 'msg_123']);
        return;

    case $path === '/mail/v1/contacts':
        json(200, [
            'data'  => [['id' => 'c1', 'email' => 'a@b.com', 'status' => 'active']],
            'total' => 1,
        ]);
        return;

    case $path === '/mail/v1/plan':
        json(200, [
            'plan'   => ['slug' => 'pro'],
            'limits' => ['emails_per_month' => 50000],
        ]);
        return;

    // A spent allowance: 429 carrying the plan-limit envelope. The SDK must
    // raise PlanLimitError and must not retry it.
    case $path === '/mail/v1/campaigns' && $_SERVER['REQUEST_METHOD'] === 'POST':
        file_put_contents($counter, (string) (((int) @file_get_contents($counter)) + 1));
        json(429, [
            'code'    => 'plan_limit_exceeded',
            'error'   => 'monthly campaign allowance spent',
            'upgrade' => [
                'feature'         => 'campaigns',
                'currentPlanSlug' => 'starter',
                'urls'            => ['pricing' => 'https://misarmail.com/pricing'],
            ],
        ], ['X-Misar-Plan' => 'starter', 'Retry-After' => '3600']);
        return;

    // Two 503s then a 200 — the retry path.
    case $path === '/mail/v1/templates':
        $n = (int) @file_get_contents($counter);
        file_put_contents($counter, (string) ($n + 1));
        if ($n < 2) {
            json(503, ['error' => 'unavailable']);
            return;
        }
        json(200, ['data' => [['id' => 't1', 'name' => 'Welcome']], 'attempts' => $n + 1]);
        return;

    case $path === '/mail/ai/generate-email/stream':
        header('Content-Type: text/event-stream');
        header('Cache-Control: no-cache');
        // Deliberately flushed in uneven pieces so a frame straddles two reads.
        foreach ([
            "data: {\"delta\":\"Hel\"}\n",
            "\ndata: {\"delta\":\"lo\"}\n\n",
            ": keepalive\n\n",
            "data: {\"delta\":\"!\",\"done\":true}\n\n",
            "data: [DONE]\n\n",
            "data: {\"delta\":\"never\"}\n\n",
        ] as $piece) {
            echo $piece;
            flush();
        }
        return;

    case $path === '/mail/campaigns/camp1/send-stream':
        header('Content-Type: text/event-stream');
        echo "data: {\"sent\":1,\"total\":2}\n\n";
        echo "data: {\"sent\":2,\"total\":2}\n\n";
        echo "data: [DONE]\n\n";
        flush();
        return;

    // A stream refused before any frame: the SDK must raise PlanLimitError at open.
    case $path === '/mail/campaigns/locked/send-stream':
        json(402, [
            'code'    => 'plan_limit_exceeded',
            'error'   => 'streaming is not on your plan',
            'upgrade' => [
                'feature' => 'campaign_streaming',
                'urls'    => ['pricing' => 'https://misarmail.com/pricing'],
            ],
        ], ['X-Misar-Plan' => 'free']);
        return;

    case $path === '/__count':
        json(200, ['count' => (int) @file_get_contents($counter)]);
        return;

    case $path === '/__reset':
        @unlink($counter);
        json(200, ['ok' => true]);
        return;

    default:
        json(404, ['error' => "no route for $path"]);
}
