<?php

declare(strict_types=1);

namespace MisarMail\Tests;

use GuzzleHttp\Client as HttpClient;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Response;
use MisarMail\ApiError;
use MisarMail\Client;
use PHPUnit\Framework\TestCase;

class ClientTest extends TestCase
{
    private function makeClient(MockHandler $mock): Client
    {
        $stack      = HandlerStack::create($mock);
        $httpClient = new HttpClient(['handler' => $stack]);

        return new Client('test-key', [
            'base_url'    => 'https://mail.misar.io/api/v1',
            'max_retries' => 3,
            'http_client' => $httpClient,
        ]);
    }

    public function testSendEmail(): void
    {
        $mock = new MockHandler([
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'success'    => true,
                'message_id' => 'msg_123',
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->sendEmail([
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
        $mock = new MockHandler([
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'data'  => [['id' => 'c1', 'email' => 'a@b.com', 'status' => 'active', 'created_at' => '', 'updated_at' => '']],
                'total' => 1,
                'page'  => 1,
                'limit' => 10,
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->contactsList(1, 10);

        $this->assertCount(1, $result['data']);
        $this->assertSame('a@b.com', $result['data'][0]['email']);
    }

    public function testCampaignsList(): void
    {
        $mock = new MockHandler([
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'data'  => [['id' => 'camp1', 'name' => 'Test', 'status' => 'draft', 'subject' => 'Hi', 'created_at' => '']],
                'total' => 1,
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->campaignsList();

        $this->assertCount(1, $result['data']);
        $this->assertSame('camp1', $result['data'][0]['id']);
    }

    public function testAnalyticsGet(): void
    {
        $mock = new MockHandler([
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'sent'          => 100,
                'delivered'     => 95,
                'opens'         => 40,
                'clicks'        => 10,
                'bounces'       => 5,
                'unsubscribes'  => 2,
                'open_rate'     => 0.42,
                'click_rate'    => 0.10,
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->analyticsGet();

        $this->assertSame(100, $result['sent']);
        $this->assertSame(95, $result['delivered']);
    }

    public function testValidateEmail(): void
    {
        $mock = new MockHandler([
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'valid'      => true,
                'disposable' => false,
                'mx_found'   => true,
                'suggestion' => '',
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->validateEmail('user@example.com');

        $this->assertTrue($result['valid']);
        $this->assertFalse($result['disposable']);
    }

    public function testError401ThrowsApiError(): void
    {
        $this->expectException(ApiError::class);
        $this->expectExceptionCode(401);

        $mock = new MockHandler([
            new Response(401, ['Content-Type' => 'application/json'], json_encode(['error' => 'unauthorized'])),
        ]);

        $client = $this->makeClient($mock);
        $client->sendEmail([
            'from'    => 'a@b.com',
            'to'      => ['c@d.com'],
            'subject' => 'Test',
        ]);
    }

    public function testRetry503(): void
    {
        $mock = new MockHandler([
            new Response(503, [], ''),
            new Response(503, [], ''),
            new Response(200, ['Content-Type' => 'application/json'], json_encode([
                'success'    => true,
                'message_id' => 'msg_retry',
            ])),
        ]);

        $client = $this->makeClient($mock);
        $result = $client->sendEmail([
            'from'    => 'a@b.com',
            'to'      => ['c@d.com'],
            'subject' => 'Retry test',
        ]);

        $this->assertTrue($result['success']);
        $this->assertSame('msg_retry', $result['message_id']);
        // MockHandler exhausted means 3 requests were made
        $this->assertSame(0, $mock->count());
    }
}
