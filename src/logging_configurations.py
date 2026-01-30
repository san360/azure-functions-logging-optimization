# Host.json Configuration Examples for Azure Functions Logging
# ==============================================================
# These examples show different logging configurations for various scenarios

# ========================================
# SCENARIO 1: Minimal Logging (Production - Cost Optimized)
# ========================================
# Use this configuration to minimize log volume and reduce costs
# Only errors and critical issues are logged
minimal_logging = {
    "version": "2.0",
    "logging": {
        "fileLoggingMode": "never",
        "logLevel": {
            "default": "Error",
            "Host.Results": "Error",
            "Host.Aggregator": "Error",
            "Function": "Error"
        },
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": True,
                "maxTelemetryItemsPerSecond": 1,
                "excludedTypes": "Request"
            },
            "enableDependencyTracking": False
        }
    }
}

# ========================================
# SCENARIO 2: High Volume Telemetry (Production - Balanced)
# ========================================
# Use for production when you need good observability with reasonable costs
balanced_logging = {
    "version": "2.0",
    "logging": {
        "fileLoggingMode": "debugOnly",
        "logLevel": {
            "default": "Warning",
            "Host.Results": "Information",
            "Host.Aggregator": "Trace",
            "Function": "Information"
        },
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": True,
                "maxTelemetryItemsPerSecond": 5,
                "excludedTypes": "Request;Exception"
            },
            "enableDependencyTracking": True
        }
    }
}

# ========================================
# SCENARIO 3: Debug/Development (Full Logging)
# ========================================
# Use for development and debugging - NOT recommended for production
debug_logging = {
    "version": "2.0",
    "logging": {
        "fileLoggingMode": "always",
        "logLevel": {
            "default": "Debug",
            "Host.Results": "Information",
            "Host.Aggregator": "Trace",
            "Function": "Debug",
            "Function.YourFunctionName": "Trace",
            "Function.YourFunctionName.User": "Debug"
        },
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": False
            },
            "enableDependencyTracking": True,
            "dependencyTrackingOptions": {
                "enableSqlCommandTextInstrumentation": True
            }
        }
    }
}

# ========================================
# SCENARIO 4: Disable Application Insights Completely
# ========================================
# Use when you don't want any telemetry sent to Application Insights
# Note: You still need APPLICATIONINSIGHTS_CONNECTION_STRING removed from app settings
disabled_app_insights = {
    "version": "2.0",
    "logging": {
        "fileLoggingMode": "always",
        "logLevel": {
            "default": "None"
        },
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": True,
                "maxTelemetryItemsPerSecond": 0
            },
            "enableDependencyTracking": False
        }
    }
}

# ========================================
# SCENARIO 5: Per-Function Configuration
# ========================================
# Use when you need different logging levels for different functions
per_function_logging = {
    "version": "2.0",
    "logging": {
        "logLevel": {
            "default": "Warning",
            "Host.Results": "Information",
            "Host.Aggregator": "Trace",
            "Function": "Warning",
            "Function.CriticalFunction": "Information",
            "Function.CriticalFunction.User": "Debug",
            "Function.NoisyFunction": "Error",
            "Function.DebugFunction": "Trace"
        },
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": True,
                "maxTelemetryItemsPerSecond": 10,
                "excludedTypes": "Request;Exception"
            }
        }
    }
}

# ========================================
# APP SETTINGS OVERRIDES
# ========================================
# These environment variables can override host.json settings without redeployment

app_settings_overrides = {
    # Log level overrides
    "AzureFunctionsJobHost__logging__logLevel__default": "Warning",
    "AzureFunctionsJobHost__logging__logLevel__Host.Results": "Information",
    "AzureFunctionsJobHost__logging__logLevel__Host.Aggregator": "Trace",
    "AzureFunctionsJobHost__logging__logLevel__Function": "Information",
    "AzureFunctionsJobHost__logging__logLevel__Function.MyFunction": "Debug",
    
    # Sampling overrides
    "AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__isEnabled": "true",
    "AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__maxTelemetryItemsPerSecond": "5",
    "AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__excludedTypes": "Request;Exception",
    
    # Dependency tracking
    "AzureFunctionsJobHost__logging__applicationInsights__enableDependencyTracking": "true",
    
    # Scale controller logging
    "SCALE_CONTROLLER_LOGGING_ENABLED": "AppInsights:Verbose",
    
    # Python debug logging
    "PYTHON_ENABLE_DEBUG_LOGGING": "1",
    
    # Disable Application Insights (remove connection string)
    # "APPLICATIONINSIGHTS_CONNECTION_STRING": ""  # Set to empty to disable
}
