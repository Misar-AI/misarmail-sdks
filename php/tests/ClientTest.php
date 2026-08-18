<?php

declare(strict_types=1);

namespace MisarMail\Tests;

use MisarMail\ApiError;
use MisarMail\Client;
use MisarMail\PlanLimitError;
use MisarMail\StreamEvent;
use PHPUnit\Framework\TestCase;

/**
 * Exercises the SDK against a real HTTP server.
 *
 * The client talks cURL directly, so there is no injectable transport to mock —
 * and mocking one would not test the code that ships. `php -S` serving
 * tests/server/router.php replays the real route shapes instead, which also
 * makes the SSE tests meaningful: frames actually arrive over a socket, in
 * pieces.
 */
class ClientTest extends TestCase
{
    /** @var resource|null */
    private static $server = null;
    private static int $port = 0;

    public static function setUpBeforeClass(): void
    {
        self::$port = random_int(20000, 60000);
        $router = __DIR__ . '/server/router.php';
        $descriptors = [1 => ['file', '/dev/null', 'w'], 2 => ['file', '/dev/null', 'w']];

        self::$server = proc_open(
            sprintf('exec php -S 127.0.0.1:%d %s', self::$port, escapeshellarg($router)),
            $descriptors,
            $pipes
        );
        if (!is_resource(self::$server)) {
            self::fail('could not start the test server');
        }

        // Wait for the listener rather than sleeping a fixed amount.
        for ($i = 0; $i < 100; $i++) {
            $sock = @fsockopen('127.0.0.1', self::$port, $errno, $errstr, 0.1);
            if ($sock !== false) {
                fclose($sock);
                return;
            }
            usleep(50_000);
        }
        self::fail('test server never came up');
    }

    public static function tearDownAfterClass(): void
    {
        if (is_resource(self::$server)) {
            proc_terminate(self::$server);
            proc_close(self::$server);
        }
    }

    private function client(string $key = 'test-key'): Client
    {
        return new Client($key, 10, sprintf('http://127.0.0.1:%d/mail/v1', self::$port));
    }

    /** How many times the router has been hit since the last reset. */
    private function requestCount(): int
    {
        $body = file_get_contents(
            sprintf('http://127.0.0.1:%d/__count', self::$port),
            false,
            stream_context_create(['http' => ['header' => "Authorization: Bearer test-key\r\n"]])
        );
        return (int) (json_decode((string) $body, true)['count'] ?? -1);
    }

    private function reset(): void
    {
        file_get_contents(sprintf('http://127.0.0.1:%d/__reset', self::$port), false, stream_context_create([
            'http' => ['header' => "Authorization: Bearer test-key\r\n", 'ignore_errors' => true],
        ]));
    }

    public function testBaseUrlDerivesTheUnversionedApiBase(): void
    {
        $client = $this->client();
        $this->assertStringEndsWith('/mail/v1', $client->baseUrl);
        $this->assertStringEndsWith('/mail', $client->apiBase);
    }

    public function testSendEmail(): void
    {
        $result = $this->client()->email->send([
            'from'    => 'sender@example.com',
            'to'      => ['recipient@example.com'],
            'subject' => 'Test',
            'html'    => '<p>Hello</p>',
        ]);

        $this->assertTrue($result['success']);
        $this->assertSame('msg_123', $result['message_id']);
    }

    public function testContactsList(): void
    {
        $result = $this->client()->contacts->list();

        $this->assertCount(1, $result['data']);
        $this->assertSame('a@b.com', $result['data'][0]['email']);
    }

    public function testPlanReportsTheSubscriptionBehindTheKey(): void
    {
        $result = $this->client()->plan->get();

        $this->assertSame('pro', $result['plan']['slug']);
        $this->assertSame(50000, $result['limits']['emails_per_month']);
    }

    public function testUnauthorizedRaisesApiError(): void
    {
        $this->expectException(ApiError::class);
        $this->expectExceptionCode(401);
        $this->client('wrong-key')->contacts->list();
    }

    public function testSpentAllowanceRaisesPlanLimitErrorAndIsNotRetried(): void
    {
        $this->reset();
        try {
            $this->client()->campaigns->create(['name' => 'Blast']);
            $this->fail('expected PlanLimitError');
        } catch (PlanLimitError $e) {
            $this->assertSame(429, $e->status);
            $this->assertSame('starter', $e->plan);
            $this->assertSame('campaigns', $e->feature);
            $this->assertSame(3600, $e->retryAfter);
            $this->assertSame('https://misarmail.com/pricing', $e->upgradeUrl);
        }

        // The whole point of the typed error: a spent allowance is not worth
        // retrying, so the server must have seen exactly one request — not the
        // three a plain retryable 429 would have produced.
        $this->assertSame(1, $this->requestCount());
    }

    public function testRetriesA503(): void
    {
        $this->reset();
        $result = $this->client()->templates->list();

        $this->assertSame('t1', $result['data'][0]['id']);
        $this->assertSame(3, $result['attempts']);
    }

    public function testStreamGenerateEmail(): void
    {
        $seen = [];
        $this->client()->streaming->generateEmail(['prompt' => 'hi'], function (StreamEvent $e) use (&$seen) {
            $seen[] = $e->data['delta'];
        });

        // "Hel" and "lo" arrived in separate writes with the frame boundary
        // split across them, so this asserts the buffering works.
        $this->assertSame(['Hel', 'lo', '!'], $seen);
    }

    public function testStreamStopsAtDoneSentinel(): void
    {
        $seen = [];
        $this->client()->streaming->generateEmail([], function (StreamEvent $e) use (&$seen) {
            $seen[] = $e->raw;
        });

        // The router writes one more frame after [DONE]; it must not be delivered.
        $this->assertNotContains('{"delta":"never"}', $seen);
        $this->assertCount(3, $seen);
    }

    public function testStreamHandlerCanStopEarly(): void
    {
        $seen = [];
        $this->client()->streaming->campaignSend('camp1', function (StreamEvent $e) use (&$seen) {
            $seen[] = $e->data['sent'];
            return false; // stop after the first frame
        });

        $this->assertSame([1], $seen);
    }

    public function testStreamRefusalRaisesPlanLimitError(): void
    {
        try {
            $this->client()->streaming->campaignSend('locked', function (StreamEvent $e) {
                $this->fail('no frame should be delivered on a refusal');
            });
            $this->fail('expected PlanLimitError');
        } catch (PlanLimitError $e) {
            $this->assertSame(402, $e->status);
            $this->assertSame('free', $e->plan);
            $this->assertSame('campaign_streaming', $e->feature);
        }
    }
}
