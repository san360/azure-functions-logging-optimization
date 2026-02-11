# Suppressing Azure SDK HTTP Logs in Python Azure Functions

## Problem

When using the Azure Python SDK (e.g., `azure-storage-queue`, `azure-identity`) inside Azure Functions, verbose HTTP-level traces appear in Application Insights:

- `Request URL: 'https://...queue.core.windows.net/...' Request method: 'DELETE' ...`
- `Response status: 204 Response headers: 'Content-Length': '0' ...`
- `DefaultAzureCredential acquired a token from ManagedIdentityCredential`
- `ManagedIdentityCredential will use App Service managed identity with client_id: ...`

These logs show up in the `traces` table under the category **`Function.<FUNCTION_NAME>.User`**, not under `Azure.Core` or `Azure.Storage`.

## Why `host.json` Cannot Fix This

### Architecture: Two Separate Processes

Azure Functions for Python runs as [two separate processes](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?pivots=python-mode-v2#understanding-the-worker-process):

```
┌────────────────────────────────┐     ┌─────────────────────────────────┐
│   .NET Function Host           │     │   Python Worker Process         │
│                                │     │                                 │
│  host.json logLevel controls   │     │  Python logging module          │
│  THESE (.NET) loggers:         │     │  ├─ azure.core.pipeline...      │
│  ├─ Azure.Core                 │     │  ├─ azure.identity              │
│  ├─ Azure.Storage              │     │  ├─ azure.storage               │
│  ├─ Host.Results               │     │  └─ your custom loggers         │
│  ├─ Microsoft.AspNetCore       │     │                                 │
│  └─ Function.*                 │ ◄── │  ALL Python logs forwarded as:  │
│                                │     │  "Function.<name>.User"         │
└────────────────────────────────┘     └─────────────────────────────────┘
```

### The Category Re-mapping Problem

1. The Python Azure SDK logs through Python's `logging` module using loggers like `azure.core.pipeline.policies.http_logging_policy`.
2. The Python worker process forwards **all** user-code logs to the .NET host.
3. During forwarding, the original Python logger name is **discarded**. The log is re-categorized as `Function.<FUNCTION_NAME>.User`.

This means:

| `host.json` Setting | What It Actually Controls |
|---|---|
| `"Azure.Core": "Warning"` | The **.NET host's** Azure.Core library — **not** the Python SDK |
| `"Azure.Storage": "Warning"` | The **.NET host's** Azure.Storage library — **not** the Python SDK |
| `"Function.queue_clear.User": "Warning"` | **All** user logs from `queue_clear`, including your own custom logs |

There is **no** `host.json` key that maps to individual Python loggers. You can only filter at the `Function.<name>.User` level, which is too coarse — it would suppress your own application logs along with the SDK noise.

### Why `applicationInsights.samplingSettings` Cannot Fix This Either

You might consider tuning the [sampling settings](https://learn.microsoft.com/en-us/azure/azure-functions/configure-monitoring?tabs=v2#configure-sampling) in `host.json`:

```json
"applicationInsights": {
  "samplingSettings": {
    "isEnabled": true,
    "maxTelemetryItemsPerSecond": 5,
    "excludedTypes": "Request"
  }
}
```

Sampling controls **how much** telemetry Application Insights retains, not **which loggers** produce it. It operates *after* log entries have already been created and sent — randomly keeping or discarding items to stay within the target rate.

This means:

| Sampling approach | Result |
|---|---|
| Sampling **on**, high volume | SDK noise and your app logs are both randomly dropped — you lose useful logs along with the noise |
| Sampling **off** | Everything is kept, including all SDK noise — more cost, more clutter |
| Very low `maxTelemetryItemsPerSecond` | Suppresses most noise but also loses most of your own application logs |

Sampling cannot distinguish between these two trace entries — both arrive as `Function.<name>.User`:

- `Request URL: 'https://...queue.core.windows.net/...'` (SDK noise)
- `Successfully processed 50 queue messages` (your app log)

It treats them identically and randomly samples across both.

## Solution: Python-Side Logger Configuration

Add the following to the top of your `function_app.py` (after imports):

```python
import logging

# Suppress verbose Azure SDK HTTP request/response logging
logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)
logging.getLogger("azure.identity").setLevel(logging.WARNING)
logging.getLogger("azure.storage").setLevel(logging.WARNING)
```

### What Each Logger Controls

| Python Logger | Logs Suppressed |
|---|---|
| `azure.core.pipeline.policies.http_logging_policy` | `Request URL: ...`, `Response status: ...`, `Response headers: ...` |
| `azure.identity` | `DefaultAzureCredential acquired a token...`, `ManagedIdentityCredential will use...` |
| `azure.storage` | Storage-specific SDK operational traces |

### Granularity Options

```python
# Option 1: Suppress only HTTP request/response lines
logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)

# Option 2: Suppress all Azure Core pipeline logs
logging.getLogger("azure.core").setLevel(logging.WARNING)

# Option 3: Suppress everything from all Azure SDKs
logging.getLogger("azure").setLevel(logging.WARNING)
```

## References

### Microsoft Documentation

1. **[How to configure monitoring for Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/configure-monitoring?tabs=v2)**

   - **Configure categories** section confirms log category assignments:
     > *"Entries created by user code inside the function, such as when calling `logger.LogInformation()`, are assigned a category of `Function.<FUNCTION_NAME>.User`."*

   - **Custom application logs** section confirms the forwarding pipeline:
     > *"By default, custom application logs you write are sent to the Functions host, which then sends them to Application Insights under the Worker category."*

   - The categories table shows `Microsoft` and `Azure.*` refer to ".NET runtime components invoked by the host" — not Python SDK loggers.

2. **[Azure Functions Python developer guide — Logging](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?pivots=python-mode-v2#logging)**

   - Confirms that Python uses the built-in `logging` module and that custom loggers are configured via `logging.getLogger()`:
     > *"You can configure custom loggers in Python when you need more control over logging behavior, such as custom formatting, log filtering, or third-party integrations."*

3. **[Azure SDK for Python — Logging](https://learn.microsoft.com/en-us/azure/developer/python/sdk/azure-sdk-logging)**

   - Documents the Azure SDK's use of Python's standard `logging` module. Logger names follow the pattern `logging.getLogger(__name__)` within each SDK module.
   - Specific logger names like `azure.core`, `azure.identity`, and `azure.storage` can be found by browsing the [Azure SDK for Python source code](https://github.com/Azure/azure-sdk-for-python).

4. **[Azure Core Pipeline — HTTP Logging Policy](https://learn.microsoft.com/en-us/python/api/azure-core/azure.core.pipeline.policies.httploggingpolicy)**

   - API reference for the HTTP logging policy that emits `Request URL` and `Response status` log entries.

### Key Takeaway

| Control Mechanism | Scope | Works For |
|---|---|---|
| `host.json` `logLevel` | .NET host categories | Host-side loggers (`Host.Results`, `Microsoft.*`, .NET `Azure.Core`) |
| `host.json` `Function.<name>.User` | All user logs from a function | Too coarse — suppresses your custom logs too |
| `host.json` `samplingSettings` | All telemetry volume | Randomly reduces volume — cannot distinguish SDK noise from app logs |
| Python `logging.getLogger().setLevel()` | Individual Python loggers | Azure SDK loggers (`azure.core.*`, `azure.identity`) |

**Python `logging.getLogger().setLevel()` is the only mechanism that can selectively suppress Azure SDK HTTP logs without affecting your own application logs.**
