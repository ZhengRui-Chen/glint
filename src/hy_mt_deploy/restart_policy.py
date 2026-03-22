from __future__ import annotations


def should_restart(*, now: int, last_restart_at: int, threshold_seconds: int) -> bool:
    return now - last_restart_at >= threshold_seconds
