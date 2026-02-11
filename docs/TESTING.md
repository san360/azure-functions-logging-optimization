# Testing Guide - Azure Functions Logging Optimization

This document contains all curl commands and KQL queries for testing the Azure Functions logging optimization project.

## Base URL

```
https://func-funclogging.azurewebsites.net/api
```

---

## 🔧 CURL Commands

### Health & Basic Endpoints

```bash
# Health Check
curl -s "https://func-funclogging.azurewebsites.net/api/healthcheck"

# HTTP GET - Simple greeting
curl -s "https://func-funclogging.azurewebsites.net/api/httpget?name=TestUser"

# HTTP GET - With different log levels
curl -s "https://func-funclogging.azurewebsites.net/api/httpget?name=DebugTest&loglevel=debug"
curl -s "https://func-funclogging.azurewebsites.net/api/httpget?name=WarningTest&loglevel=warning"
curl -s "https://func-funclogging.azurewebsites.net/api/httpget?name=ErrorTest&loglevel=error"

# Logging Demo - Shows all log levels
curl -s "https://func-funclogging.azurewebsites.net/api/loggingdemo"
```

### POST Endpoints

```bash
# HTTP POST - Basic
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "TestUser", "generateLogs": 5, "simulateError": false}'

# HTTP POST - Generate many logs
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "LoadTest", "generateLogs": 50, "simulateError": false}'

# HTTP POST - Simulate error
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "ErrorTest", "generateLogs": 1, "simulateError": true}'
```

### Performance & Sampling Tests

```bash
# Performance Test - Default
curl -s "https://func-funclogging.azurewebsites.net/api/performancetest"

# Performance Test - High frequency logging
curl -s "https://func-funclogging.azurewebsites.net/api/performancetest?iterations=1000&logfrequency=10"

# Sampling Test - 50 entries
curl -s "https://func-funclogging.azurewebsites.net/api/samplingtest?count=50"

# Sampling Test - 100 entries
curl -s "https://func-funclogging.azurewebsites.net/api/samplingtest?count=100"
```

### Queue Operations

```bash
# Send single message to queue
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from logging demo!", "count": 1, "includeMetadata": true}'

# Send 5 messages
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message", "count": 5, "includeMetadata": true}'

# Send 50 messages (for sampling observation)
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Bulk sampling test", "count": 50, "includeMetadata": true}'

# Send 100 messages (maximum per request)
curl -s -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Load test message", "count": 100, "includeMetadata": false}'

# Check queue status
curl -s "https://func-funclogging.azurewebsites.net/api/queuestatus"

# Clear all messages from queue
curl -s -X DELETE "https://func-funclogging.azurewebsites.net/api/queueclear"
```

---

## 📊 KQL Queries for Application Insights

> For KQL syntax reference, see [Kusto Query Language overview](https://learn.microsoft.com/azure/data-explorer/kusto/query/).
> For Application Insights table schemas, see [Application Insights telemetry data model](https://learn.microsoft.com/azure/azure-monitor/app/data-model-complete).

### Basic Trace Queries

```kusto
// View all traces (last 30 minutes)
traces
| where timestamp > ago(30m)
| project timestamp, severityLevel, message, 
    logger = customDimensions.LoggerName, 
    category = customDimensions.Category
| order by timestamp desc

// View traces with severity levels
traces
| where timestamp > ago(1h)
| summarize count() by severityLevel
| order by severityLevel asc
```

### Function-Specific Queries

```kusto
// All function logs
traces
| where timestamp > ago(30m)
| where customDimensions.Category startswith "Function"
| project timestamp, severityLevel, message, category = customDimensions.Category
| order by timestamp desc

// Queue message function logs
traces
| where timestamp > ago(30m)
| where message contains "queue" or customDimensions.Category contains "queue_message"
| project timestamp, severityLevel, message
| order by timestamp desc

// Logs by correlation ID (replace with actual ID from response)
traces
| where timestamp > ago(1h)
| where message contains "YOUR_CORRELATION_ID"
| project timestamp, severityLevel, message
| order by timestamp desc

// Count logs by correlation ID
traces
| where timestamp > ago(1h)
| where message contains "YOUR_CORRELATION_ID"
| count
```

### Sampling Analysis Queries

```kusto
// Count sampling test entries
traces
| where timestamp > ago(1h)
| where message contains "Sampling test entry"
| count

// Compare sent vs captured (sampling effect)
traces
| where timestamp > ago(1h)
| where message contains "Sampling test entry"
| summarize CapturedCount = count()

// Sampling rate over time
traces
| where timestamp > ago(1h)
| summarize count() by bin(timestamp, 1m)
| render timechart

// Trace volume by category
traces
| where timestamp > ago(1h)
| extend category = tostring(customDimensions.Category)
| summarize count() by category
| order by count_ desc
```

### Request & Dependency Analysis

```kusto
// All HTTP requests
requests
| where timestamp > ago(1h)
| project timestamp, name, url, resultCode, duration, success
| order by timestamp desc

// Request performance
requests
| where timestamp > ago(1h)
| summarize avg(duration), percentile(duration, 95), count() by name
| order by count_ desc

// Dependencies (Azure Storage Queue calls)
dependencies
| where timestamp > ago(1h)
| where type == "Azure queue" or target contains "queue"
| project timestamp, name, target, duration, success, resultCode
| order by timestamp desc

// Failed requests
requests
| where timestamp > ago(1h)
| where success == false
| project timestamp, name, resultCode, duration
| order by timestamp desc
```

### Error & Exception Tracking

```kusto
// All exceptions
exceptions
| where timestamp > ago(1h)
| project timestamp, type, outerMessage, innermostMessage
| order by timestamp desc

// Errors by type
traces
| where timestamp > ago(1h)
| where severityLevel >= 3
| summarize count() by severityLevel
| extend level = case(
    severityLevel == 3, "Warning",
    severityLevel == 4, "Error", 
    severityLevel == 5, "Critical",
    "Unknown")
```

### Performance Monitoring

```kusto
// Function execution times
requests
| where timestamp > ago(1h)
| where name contains "queuemessage"
| summarize 
    avgDuration = avg(duration),
    p95Duration = percentile(duration, 95),
    p99Duration = percentile(duration, 99),
    count = count()
| project avgDuration, p95Duration, p99Duration, count

// Requests per minute
requests
| where timestamp > ago(1h)
| summarize count() by bin(timestamp, 1m)
| render timechart
```

### Azure SDK Logging

```kusto
// Azure Core/Storage SDK logs (if enabled at Warning level or below)
traces
| where timestamp > ago(30m)
| where customDimensions.Category startswith "Azure."
| project timestamp, severityLevel, message, category = customDimensions.Category
| order by timestamp desc
```

---

## 🔍 Quick Reference Table

| What to Find | KQL Table | Key Filter |
|-------------|-----------|------------|
| Function logs | `traces` | `customDimensions.Category startswith "Function"` |
| HTTP requests | `requests` | `name contains "api"` |
| Storage calls | `dependencies` | `type == "Azure queue"` |
| Errors | `exceptions` | - |
| Sampling effect | `traces` | `message contains "Sampling test"` |
| Queue operations | `traces` | `message contains correlation_id` |

---

## 📈 Sampling Behavior

> See [Configure sampling](https://learn.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2#configure-sampling) in the Azure Functions monitoring docs.

### Current Configuration (host.json)

```json
{
  "samplingSettings": {
    "isEnabled": true,
    "maxTelemetryItemsPerSecond": 5,
    "excludedTypes": "Request;Exception"
  }
}
```

### What This Means

- **`maxTelemetryItemsPerSecond: 5`** - Only ~5 trace items per second are retained
- **`excludedTypes: "Request;Exception"`** - All requests and exceptions are always captured (never sampled)
- When sending 50+ messages quickly, many trace logs will be sampled out
- Use correlation IDs to track specific operations

### Testing Sampling

1. Send 100 messages:
   ```bash
   curl -s -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
     -H "Content-Type: application/json" \
     -d '{"message": "Sampling test", "count": 100}'
   ```

2. Note the `correlationId` from the response

3. Query Application Insights:
   ```kusto
   traces
   | where timestamp > ago(10m)
   | where message contains "YOUR_CORRELATION_ID"
   | count
   ```

4. Compare: You sent 100 messages but will see fewer traces captured due to sampling

---

## 🛠️ Local Development Testing

For local development, use `http://localhost:7071/api` instead. See [Code and test Azure Functions locally](https://learn.microsoft.com/azure/azure-functions/functions-develop-local) for setup details.

```bash
# Start function locally
cd src && func start

# Test locally
curl -s "http://localhost:7071/api/healthcheck"
curl -s -X POST "http://localhost:7071/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Local test", "count": 5}'
```

Note: Local testing requires Azurite for storage emulation and proper `local.settings.json` configuration.
