"""Runtime switches shared by API and agent services."""

import os


def is_local_dev_mode() -> bool:
    """Enable simulated services only outside managed AWS runtimes."""
    return (
        os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
        and not os.environ.get("AWS_EXECUTION_ENV")
    )
