"""
log_setup.py - Reusable logging configuration for Azure Functions (Python worker).

The Python worker forwards all log records to the .NET host, which discards
the original logger name and re-categorizes everything as
Function.<FunctionName>.User.  This module works around that limitation by
embedding the logger name into the message text via a custom formatter.

Usage:
    from log_setup import setup_logging
    logger = setup_logging()
    logger.info("Hello")  # -> "[app] Hello" in Application Insights
"""

import logging

DEFAULT_FMT = "[%(name)s] %(message)s"

DEFAULT_SUPPRESS = [
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.core.pipeline",
    "azure.identity",
    "azure.storage",
    "urllib3",
    "msrest",
]


def setup_logging(
    logger_name: str = "app",
    level: int = logging.DEBUG,
    suppress_libs: list | None = None,
    fmt: str | None = None,
) -> logging.Logger:
    """Configure logging for use inside the Azure Functions Python worker.

    Returns a named logger whose formatter embeds the logger name into the
    message text so it survives the worker -> host forwarding pipeline.

    Args:
        logger_name: Name for the returned logger (embedded in messages).
        level: Logging level for the returned logger.
        suppress_libs: Library loggers to set to WARNING. None uses defaults.
                       Pass [] to suppress nothing.
        fmt: Custom format string. None uses "[%(name)s] %(message)s".

    Returns:
        A configured logging.Logger instance.
    """
    fmt = fmt or DEFAULT_FMT
    formatter = logging.Formatter(fmt)

    logger = logging.getLogger(logger_name)
    logger.setLevel(level)

    # Apply the formatter to the root handler(s).
    # The Azure Functions Python worker attaches a handler to the root logger
    # that forwards records to the .NET host.  We set our formatter on those
    # existing handlers so the embedded name appears in the forwarded message.
    root = logging.getLogger()
    for handler in root.handlers:
        handler.setFormatter(formatter)

    # If the root logger has no handlers yet (e.g., local testing outside
    # the Functions host), add a StreamHandler so logs are not silently lost.
    if not root.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(formatter)
        root.addHandler(handler)

    # Suppress noisy third-party loggers
    libs = suppress_libs if suppress_libs is not None else DEFAULT_SUPPRESS
    for lib_name in libs:
        logging.getLogger(lib_name).setLevel(logging.WARNING)

    logger.info(
        "Logging configured: logger=%r, suppressed %d libraries",
        logger_name,
        len(libs),
    )

    return logger
