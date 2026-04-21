<?php

declare(strict_types=1);

namespace MisarMail;

class ApiError extends \RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $status = 0,
        ?\Throwable $previous = null
    ) {
        parent::__construct($message, $status, $previous);
    }
}

class NetworkError extends ApiError
{
    public function __construct(string $message, ?\Throwable $previous = null)
    {
        parent::__construct($message, 0, $previous);
    }
}
