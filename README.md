# Azure Functions Logging Optimization with Application Insights

This project demonstrates how to configure, optimize, and control logging/traces in Azure Functions with Python, Application Insights, and Log Analytics Workspace.

## 🎯 Overview

Azure Functions integrates with Application Insights for monitoring, which can generate high volumes of telemetry data. This project provides:

- **Configurable logging levels** for different components
- **Sampling configuration** to reduce data volume and costs
- **Azure Storage Queue integration** with managed identity
- **Infrastructure as Code** using Azure Developer CLI (azd) and Bicep
- **Test endpoints** to observe logging and sampling behavior
- **Flex Consumption plan** with user-assigned managed identity (no storage keys)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Resources                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │   Function App   │───▶│  Storage Queue   │                   │
│  │ (Flex Consumption)│    │  (Managed ID)    │                   │
│  └────────┬─────────┘    └──────────────────┘                   │
│           │                                                      │
│           │ Telemetry                                            │
│           ▼                                                      │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │   Application    │───▶│   Log Analytics  │                   │
│  │    Insights      │    │    Workspace     │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  User-Assigned   │    │  Storage Account │                   │
│  │ Managed Identity │───▶│ (No Shared Keys) │                   │
│  └──────────────────┘    └──────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

**Key Features:**
- **Flex Consumption Plan** - Serverless scaling with pay-per-use billing
- **User-Assigned Managed Identity** - Secure storage access without keys
- **No Shared Key Access** - Storage account configured with `allowSharedKeyAccess: false`
- **Blob-Based Deployment** - Function packages stored in blob container

## 📋 Prerequisites

- [Python 3.11+](https://www.python.org/downloads/)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (optional)
- [Azurite](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) for local development

## 🚀 Quick Start

### Deploy to Azure

```bash
# Login to Azure
azd auth login

# Deploy infrastructure and code
azd up
```

### Local Development

```bash
# Clone repository
git clone https://github.com/san360/azure-functions-logging-optimization.git
cd azure-functions-logging-optimization

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/macOS

# Install dependencies
pip install -r src/requirements.txt

# Start Azurite (separate terminal)
azurite --silent --location .azurite

# Run locally
cd src && func start
```

## 📁 Project Structure

```
├── azure.yaml                    # Azure Developer CLI configuration
├── docs/
│   └── TESTING.md               # Complete testing guide with curl & KQL
├── infra/                        # Infrastructure as Code (Bicep)
│   ├── main.bicep               # Main deployment orchestration
│   ├── main.parameters.json
│   └── core/
│       ├── host/
│       │   ├── app-service-plan.bicep    # Flex Consumption (FC1)
│       │   └── function-app.bicep        # Function with managed identity
│       ├── identity/
│       │   ├── user-assigned-identity.bicep
│       │   └── role-assignments.bicep    # RBAC permissions
│       ├── monitor/
│       │   ├── application-insights.bicep
│       │   └── log-analytics.bicep
│       └── storage/
│           └── storage-account.bicep     # No shared key access
├── src/                          # Function App source code
│   ├── function_app.py          # All function endpoints
│   ├── host.json                # Logging & sampling configuration
│   ├── requirements.txt         # Python dependencies
│   └── test.http                # REST Client test requests
└── README.md
```

## 🔌 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/healthcheck` | GET | Health check with minimal logging |
| `/api/httpget` | GET | Basic endpoint with configurable log level |
| `/api/httppost` | POST | Generate multiple logs, simulate errors |
| `/api/loggingdemo` | GET | Demonstrates all log levels |
| `/api/performancetest` | GET | Test performance impact of logging |
| `/api/samplingtest` | GET | Generate logs to observe sampling effect |
| `/api/queuemessage` | POST | Push messages to Azure Storage Queue |
| `/api/queuestatus` | GET | Get queue status and message count |
| `/api/queueclear` | DELETE | Clear all messages from queue |

### Live Endpoint Examples

```bash
# Health check
curl https://func-funclogging.azurewebsites.net/api/healthcheck

# Send messages to queue
curl -X POST "https://func-funclogging.azurewebsites.net/api/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test", "count": 10}'

# Check queue status
curl https://func-funclogging.azurewebsites.net/api/queuestatus
```

## 🔧 Logging Configuration

### host.json

```json
{
  "version": "2.0",
  "logging": {
    "logLevel": {
      "default": "Warning",
      "Host.Results": "Information",
      "Host.Aggregator": "Trace",
      "Function": "Information",
      "Function.queue_message": "Information",
      "Azure.Core": "Warning",
      "Azure.Storage": "Warning"
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

| Level | Value | Description |
|-------|-------|-------------|
| Trace | 0 | Most detailed (may contain sensitive data) |
| Debug | 1 | Debugging information |
| Information | 2 | General operational flow |
| Warning | 3 | Abnormal or unexpected events |
| Error | 4 | Execution stopped due to failure |
| Critical | 5 | System crash or catastrophic failure |
| None | 6 | Disables logging for the category |

### Sampling Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| `isEnabled` | Enable/disable sampling | `true` |
| `maxTelemetryItemsPerSecond` | Max traces per second | `5` |
| `excludedTypes` | Types to never sample | `Request;Exception` |
| `includedTypes` | Types to always sample | `""` |

## 📊 Observing Sampling in Application Insights

### Quick KQL Queries

```kusto
// View recent traces
traces
| where timestamp > ago(30m)
| project timestamp, severityLevel, message
| order by timestamp desc

// Count traces by correlation ID (from queue response)
traces
| where message contains "YOUR_CORRELATION_ID"
| count

// Check sampling effect
traces
| where message contains "Sampling test entry"
| count
```

### Understanding Sampling

With `maxTelemetryItemsPerSecond: 5`:
- Sending 100 messages generates ~100+ trace logs
- Only ~5 traces per second are retained
- Requests and Exceptions are **never** sampled (excluded)

**For complete testing documentation, see [docs/TESTING.md](docs/TESTING.md)**

## ⚙️ Configuration Scenarios

### 1. Cost Optimized (Production)

```json
{
  "logging": {
    "logLevel": { "default": "Error" },
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

### 2. Full Debugging

```json
{
  "logging": {
    "logLevel": { "default": "Debug", "Function": "Trace" },
    "applicationInsights": {
      "samplingSettings": { "isEnabled": false }
    }
  }
}
```

### 3. Runtime Override (No Redeployment)

```bash
# Override log level via app settings
az functionapp config appsettings set \
  --name func-funclogging \
  --resource-group rg-funclogging \
  --settings "AzureFunctionsJobHost__logging__logLevel__default=Debug"
```

## 🔐 Security Features

- **No Storage Keys** - `allowSharedKeyAccess: false` on storage account
- **User-Assigned Managed Identity** - For all Azure resource access
- **RBAC Permissions**:
  - Storage Blob Data Owner
  - Storage Blob Data Contributor  
  - Storage Queue Data Contributor
  - Storage Table Data Contributor
  - Monitoring Metrics Publisher

## 💰 Cost Optimization Tips

1. **Enable Sampling** - Reduces Application Insights data by 80%+
2. **Increase Log Level** - Use `Warning` or `Error` in production
3. **Disable Dependency Tracking** - If not analyzing external calls
4. **Filter Azure SDK Logs** - Set `Azure.Core` and `Azure.Storage` to `Warning`
5. **Set Daily Cap** - Configure in Log Analytics workspace

## 🧹 Cleanup

```bash
# Delete all Azure resources
azd down --force --purge
```

## 🔗 Resources

- [Configure monitoring for Azure Functions](https://learn.microsoft.com/azure/azure-functions/configure-monitoring)
- [Application Insights sampling](https://learn.microsoft.com/azure/azure-monitor/app/sampling)
- [Azure Functions Flex Consumption plan](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Managed identities for Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-identity-access-azure-sql-with-managed-identity)

## 📄 License

MIT
- [Application Insights sampling](https://learn.microsoft.com/azure/azure-monitor/app/sampling)
- [host.json reference](https://learn.microsoft.com/azure/azure-functions/functions-host-json)
- [Azure Functions Python developer guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
