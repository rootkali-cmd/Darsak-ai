"""Circuit breaker pattern for external service calls.

Prevents cascading failures by failing fast when a service is unhealthy.
"""
import asyncio
import time
import logging
from enum import Enum
from typing import Callable, Awaitable, Any

logger = logging.getLogger("darsak")


class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing fast
    HALF_OPEN = "half_open"  # Testing if service recovered


class CircuitBreaker:
    """Circuit breaker for async operations.
    
    - CLOSED: Normal operation. Counts failures.
    - OPEN: After `failure_threshold` failures, rejects requests for `recovery_timeout`.
    - HALF_OPEN: After timeout, allows 1 test request.
    """
    
    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        recovery_timeout: float = 30.0,
        expected_exception: type = Exception,
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: float | None = None
        self._lock = asyncio.Lock()
    
    @property
    def state(self) -> CircuitState:
        return self._state
    
    async def call(self, coro_factory: Callable[[], Awaitable[Any]], description: str = "") -> Any:
        """Execute coroutine with circuit breaker protection."""
        async with self._lock:
            if self._state == CircuitState.OPEN:
                if self._last_failure_time and (time.time() - self._last_failure_time) >= self.recovery_timeout:
                    self._state = CircuitState.HALF_OPEN
                    logger.info("Circuit breaker '%s' entering HALF_OPEN state", self.name)
                else:
                    raise CircuitBreakerOpenError(
                        f"Circuit breaker '{self.name}' is OPEN. Service temporarily unavailable."
                    )
            
            elif self._state == CircuitState.HALF_OPEN:
                self._state = CircuitState.CLOSED  # Will be set back to OPEN on failure
                self._failure_count = 0
        
        try:
            result = await coro_factory()
            # Success in half-open → close circuit
            if self._state == CircuitState.HALF_OPEN:
                async with self._lock:
                    if self._state == CircuitState.HALF_OPEN:
                        self._state = CircuitState.CLOSED
                        self._failure_count = 0
                        logger.info("Circuit breaker '%s' CLOSED after recovery", self.name)
            return result
        except self.expected_exception as e:
            async with self._lock:
                self._failure_count += 1
                self._last_failure_time = time.time()
                if self._failure_count >= self.failure_threshold:
                    self._state = CircuitState.OPEN
                    logger.error(
                        "Circuit breaker '%s' OPENED after %d failures: %s",
                        self.name, self._failure_count, e,
                    )
                else:
                    logger.warning(
                        "Circuit breaker '%s' failure %d/%d: %s",
                        self.name, self._failure_count, self.failure_threshold, e,
                    )
            raise


class CircuitBreakerOpenError(Exception):
    """Raised when the circuit breaker is OPEN."""
    pass


# Pre-configured breakers
supabase_breaker = CircuitBreaker(
    name="supabase",
    failure_threshold=5,
    recovery_timeout=30.0,
    expected_exception=(Exception,),
)

ai_api_breaker = CircuitBreaker(
    name="ai_api",
    failure_threshold=3,
    recovery_timeout=60.0,
    expected_exception=(Exception,),
)
