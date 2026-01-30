# Azure Functions Logging Optimization with Application Insights

This project demonstrates how to configure, optimize, and disable logging/traces in Azure Functions with Python, Application Insights, and Log Analytics Workspace.

## 🎯 Overview

Azure Functions integrates with Application Insights for monitoring, which can generate high volumes of telemetry data. This project provides:

- **Configurable logging levels** for different components
- **Sampling configuration** to reduce data volume
- **Infrastructure as Code** using Azure Developer CLI (azd) and Bicep
- **Test endpoints** to observe logging behavior
- **Documentation** on optimization strategies

## 📋 Prerequisites

- [Python 3.11+](https://www.python.org/downloads/)
- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (optional)
- [Azurite](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) for local development

## 🚀 Quick Start

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/san360/azure-functions-logging-optimization.git
   cd azure-functions-logging-optimization
   ```

2. **Create virtual environment**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Linux/macOS
   # or
   .venv\Scripts\activate     # Windows
   ```

3. **Install dependencies**
   ```bash
   pip install -r src/requirements.txt
   ```

4. **Start Azurite** (in a separate terminal)
   ```bash
   azurite --silent --location .azurite --debug .azurite/debug.log
   ```

5. **Run locally**
   ```bash
   cd src
   func start
   ```

### Deploy to Azure

1. **Login to Azure**
   ```bash
   azd auth login
   ```

2. **Initialize environment**
   ```bash
   azd init -e dev
   ```

3. **Deploy**
   ```bash
   azd up
   ```

## 📁 Project Structure

```
├── azure.yaml              # Azure Developer CLI configuration
├── infra/                  # Infrastructure as Code (Bicep)
│   ├── main.bicep         # Main deployment template
│   ├── main.parameters.json
│   └── core/
│       ├── host/
│       │   ├── app-service-plan.bicep
│       │   └── function-app.bicep
│       ├── monitor/
│       │   ├── application-insights.bicep
│       │   └── log-analytics.bicep
│       └── storage/
│           └── storage-account.bicep
├── src/                    # Function App source code
│   ├── function_app.py    # Main functions
│   ├── host.json          # Logging configuration
│   ├── local.settings.json
│   ├── requirements.txt
│   ├── logging_configurations.py  # Example configurations
│   └── test.http          # Test requests
└── README.md
```

## 🔧 Logging Configuration

### host.json Configuration

The `host.json` file controls logging behavior:

```json
{
  "version": "2.0",
  "logging": {
    "logLevel": {
      "default": "Warning",
      "Host.Results": "Information",
      "Host.Aggregator": "Trace",
      "Function": "Information"
    },
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 5,
        "excludedTypes": "Request;Exception"
      },
      "enableDependencyTracking": true
    }
  }
}
```

### Log Levels

| Level | Code | Description |
|-------|------|-------------|
| Trace | 0 | Most detailed messages (may contain sensitive data) |
| Debug | 1 | Debugging information |
| Information | 2 | General operational flow |
| Warning | 3 | Abnormal or unexpected events |
| Error | 4 | Execution stopped due to failure |
| Critical | 5 | System crash or catastrophic failure |
| None | 6 | Disables logging for the category |

### Log Categories

| Category | Description |
|----------|-------------|
| `default` | Catch-all for unspecified categories |
| `Host.Results` | Function execution results (requests table) |
| `Host.Aggregator` | Aggregated metrics (customMetrics table) |
| `Function` | All function logs |
| `Function.<Name>` | Specific function logs |
| `Function.<Name>.User` | User-generated logs from a function |

## ⚙️ Configuration Scenarios

### 1. Minimal Logging (Cost Optimized)

```json
{
  "logging": {
    "logLevel": {
      "default": "Error"
    },
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 1
      },
      "enableDependencyTracking": false
    }
  }
}
```

**Environment variables:**
```bash
azd env set DEFAULT_LOG_LEVEL Error
azd env set ENABLE_SAMPLING true
azd env set MAX_TELEMETRY_ITEMS_PER_SECOND 1
azd env set ENABLE_DEPENDENCY_TRACKING false
```

### 2. Balanced Production Logging

```json
{
  "logging": {
    "logLevel": {
      "default": "Warning",
      "Host.Results": "Information",
      "Function": "Information"
    },
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 5,
        "excludedTypes": "Request;Exception"
      }
    }
  }
}
```

### 3. Full Debugging

```json
{
  "logging": {
    "logLevel": {
      "default": "Debug",
      "Function": "Trace"
    },
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": false
      }
    }
  }
}
```

### 4. Disable Application Insights

Remove or clear the connection string:
```bash
az functionapp config appsettings delete \
  --name <FUNCTION_APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --setting-names APPLICATIONINSIGHTS_CONNECTION_STRING
```

## 🔄 Runtime Configuration Override

Override host.json settings via app settings without redeployment:

```bash
# Set log level via Azure CLI
az functionapp config appsettings set \
  --name <FUNCTION_APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --settings "AzureFunctionsJobHost__logging__logLevel__default=Warning"

# Enable scale controller logs
az functionapp config appsettings set \
  --name <FUNCTION_APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --settings "SCALE_CONTROLLER_LOGGING_ENABLED=AppInsights:Verbose"
```

## 🧪 Testing the Configuration

### Test Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/httpget` | Basic endpoint with configurable log level |
| `POST /api/httppost` | Generate multiple logs, simulate errors |
| `GET /api/loggingdemo` | Demonstrates all log levels |
| `GET /api/performancetest` | Test performance impact of logging |
| `GET /api/samplingtest` | Generate logs to observe sampling |
| `GET /api/healthcheck` | Minimal logging health check |

### Using test.http

With VS Code REST Client extension:
1. Open `src/test.http`
2. Click "Send Request" above each request

### Using curl

```bash
# Basic GET
curl http://localhost:7071/api/httpget?name=Test

# Logging demo
curl http://localhost:7071/api/loggingdemo

# Sampling test
curl "http://localhost:7071/api/samplingtest?count=100"
```

## 📊 Viewing Logs in Application Insights

### Kusto Queries

**View all traces:**
```kusto
traces
| where timestamp > ago(1h)
| order by timestamp desc
| take 100
```

**View traces by severity:**
```kusto
traces
| where timestamp > ago(1h)
| summarize count() by severityLevel
```

**Check sampling effectiveness:**
```kusto
traces
| where message contains "Sampling test entry"
| count
```

**View function executions:**
```kusto
requests
| where timestamp > ago(1h)
| summarize count(), avg(duration) by name
```

## 💰 Cost Optimization Tips

1. **Enable Sampling**: Reduces data volume significantly
   ```json
   "samplingSettings": {
     "isEnabled": true,
     "maxTelemetryItemsPerSecond": 5
   }
   ```

2. **Increase Log Level**: Use `Warning` or `Error` in production
   ```json
   "logLevel": {
     "default": "Warning"
   }
   ```

3. **Disable Dependency Tracking**: If not needed
   ```json
   "enableDependencyTracking": false
   ```

4. **Exclude High-Volume Types from Sampling**:
   ```json
   "excludedTypes": "Request;Exception"
   ```

5. **Set Daily Cap in Log Analytics**: Prevent unexpected costs

## 🔗 Resources

- [Configure monitoring for Azure Functions](https://learn.microsoft.com/azure/azure-functions/configure-monitoring)
- [Application Insights sampling](https://learn.microsoft.com/azure/azure-monitor/app/sampling)
- [host.json reference](https://learn.microsoft.com/azure/azure-functions/functions-host-json)
- [Azure Functions Python developer guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
