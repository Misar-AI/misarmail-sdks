<?php

declare(strict_types=1);

namespace MisarMail;

class NetworkError extends ApiError
{
    public function __construct(string $message, ?\Throwable $previous = null)
    {
        parent::__construct($message, 0, $previous);
    }
}
