"""Keeps the harness under the org's hourly generation budget.

The Developer Edition throttles LLM generations per hour. A naive loop over
80 test cases will blow through the window and start failing mid-run, which
is exactly what you do not want happening while someone is watching.
"""

import time
from collections import deque


class RateLimiter:
    def __init__(self, generations_per_hour: int, generations_per_case: int):
        self.budget = generations_per_hour
        self.per_case = generations_per_case
        self.window = deque()  # timestamps of consumed generations

    def _prune(self, now: float) -> None:
        while self.window and now - self.window[0] > 3600:
            self.window.popleft()

    def acquire(self, verbose: bool = True) -> None:
        """Block until there is room for one more test case."""
        while True:
            now = time.time()
            self._prune(now)
            if len(self.window) + self.per_case <= self.budget:
                for _ in range(self.per_case):
                    self.window.append(now)
                return
            sleep_for = 3600 - (now - self.window[0]) + 1
            if verbose:
                print(f"  rate limit reached, sleeping {sleep_for:.0f}s")
            time.sleep(max(sleep_for, 1))

    @property
    def consumed(self) -> int:
        return len(self.window)
