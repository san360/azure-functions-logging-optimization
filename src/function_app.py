"""
Azure Functions Logging Optimization Sample
============================================
This sample demonstrates various logging configurations and their impact on
Application Insights telemetry and Log Analytics data.
"""

import logging
import azure.functions as func
import json
import time
import random
import os
import uuid
from azure.storage.queue import QueueClient
from azure.identity import DefaultAzureCredential

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Storage Queue configuration
STORAGE_ACCOUNT_NAME = os.environ.get("AzureWebJobsStorage__accountName", "")
QUEUE_NAME = "logging-test-queue"
# User-assigned managed identity client ID (configured in Azure)
MANAGED_IDENTITY_CLIENT_ID = os.environ.get("AzureWebJobsStorage__clientId", "")


def get_queue_client() -> QueueClient:
    """
    Creates a QueueClient using user-assigned managed identity.
    No storage keys required - uses the managed identity configured for the function app.
    """
    account_url = f"https://{STORAGE_ACCOUNT_NAME}.queue.core.windows.net"
    
    # Use user-assigned managed identity with specific client ID
    if MANAGED_IDENTITY_CLIENT_ID:
        credential = DefaultAzureCredential(
            managed_identity_client_id=MANAGED_IDENTITY_CLIENT_ID
        )
    else:
        # Fallback to default (for local development)
        credential = DefaultAzureCredential()
    
    return QueueClient(account_url, queue_name=QUEUE_NAME, credential=credential)


@app.route(route="httpget", methods=["GET"])
def http_get(req: func.HttpRequest) -> func.HttpResponse:
    """
    Simple HTTP GET endpoint to test logging at different levels.
    
    Query parameters:
    - name: Name to greet (default: "World")
    - loglevel: Demonstrate logging at specified level (trace, debug, info, warning, error)
    """
    name = req.params.get("name", "World")
    log_level = req.params.get("loglevel", "info").lower()
    
    # Demonstrate different log levels
    logging.debug(f"DEBUG: Processing GET request with name={name}")
    logging.info(f"INFO: HTTP GET triggered - Greeting {name}")
    logging.warning(f"WARNING: Example warning message for {name}")
    
    # Log at the requested level
    if log_level == "trace":
        logging.log(5, f"TRACE: Very detailed trace log for {name}")  # Below DEBUG
    elif log_level == "debug":
        logging.debug(f"DEBUG: Detailed debug information for {name}")
    elif log_level == "warning":
        logging.warning(f"WARNING: Warning level log for {name}")
    elif log_level == "error":
        logging.error(f"ERROR: Error level log for {name}")
    else:
        logging.info(f"INFO: Standard info log for {name}")
    
    return func.HttpResponse(f"Hello, {name}! Check Application Insights for logs.")


@app.route(route="httppost", methods=["POST"])
def http_post(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP POST endpoint to test logging with payload data.
    
    Expected JSON body:
    {
        "name": "string",
        "generateLogs": int (number of log entries to generate),
        "simulateError": bool
    }
    """
    try:
        req_body = req.get_json()
        name = req_body.get("name", "Anonymous")
        generate_logs = req_body.get("generateLogs", 1)
        simulate_error = req_body.get("simulateError", False)
        
        logging.info(f"Processing POST request for {name}")
        
        # Generate multiple log entries if requested
        for i in range(min(generate_logs, 100)):  # Cap at 100
            logging.info(f"Log entry {i+1}/{generate_logs} for {name}")
            
        if simulate_error:
            logging.error(f"Simulated error for testing - User: {name}")
            raise ValueError("Simulated error for testing error tracking")
        
        return func.HttpResponse(
            json.dumps({
                "message": f"Hello, {name}!",
                "logsGenerated": generate_logs
            }),
            mimetype="application/json"
        )
        
    except ValueError as e:
        logging.exception(f"ValueError occurred: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        logging.exception(f"Unexpected error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="loggingdemo", methods=["GET"])
def logging_demo(req: func.HttpRequest) -> func.HttpResponse:
    """
    Demonstrates all logging levels and their visibility based on configuration.
    
    Use this endpoint to understand how host.json and app settings affect
    which logs appear in Application Insights.
    """
    results = []
    
    # Python's logging levels
    levels = [
        (logging.DEBUG, "DEBUG", "Detailed diagnostic information"),
        (logging.INFO, "INFO", "General operational information"),
        (logging.WARNING, "WARNING", "Warning about potential issues"),
        (logging.ERROR, "ERROR", "Error that prevented operation"),
        (logging.CRITICAL, "CRITICAL", "Severe error requiring attention")
    ]
    
    for level, name, description in levels:
        msg = f"{name}: {description}"
        logging.log(level, msg)
        results.append({
            "level": name,
            "logged": True,
            "description": description
        })
    
    return func.HttpResponse(
        json.dumps({
            "message": "Logging demo completed",
            "levels_logged": results,
            "note": "Check Application Insights 'traces' table to see which logs were captured based on your configuration"
        }, indent=2),
        mimetype="application/json"
    )


@app.route(route="performancetest", methods=["GET"])
def performance_test(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint to test performance impact of different logging configurations.
    
    Query parameters:
    - iterations: Number of operations to perform (default: 100)
    - logfrequency: How often to log (every N iterations, default: 10)
    """
    iterations = int(req.params.get("iterations", "100"))
    log_frequency = int(req.params.get("logfrequency", "10"))
    
    # Cap values for safety
    iterations = min(iterations, 10000)
    log_frequency = max(log_frequency, 1)
    
    start_time = time.time()
    
    logging.info(f"Starting performance test with {iterations} iterations")
    
    for i in range(iterations):
        # Simulate some work
        _ = sum(random.random() for _ in range(100))
        
        # Log periodically based on frequency
        if (i + 1) % log_frequency == 0:
            logging.info(f"Performance test progress: {i+1}/{iterations}")
    
    elapsed_time = time.time() - start_time
    
    logging.info(f"Performance test completed in {elapsed_time:.2f} seconds")
    
    return func.HttpResponse(
        json.dumps({
            "iterations": iterations,
            "logFrequency": log_frequency,
            "logsGenerated": iterations // log_frequency,
            "elapsedTimeSeconds": round(elapsed_time, 3),
            "averageIterationMs": round((elapsed_time / iterations) * 1000, 3)
        }, indent=2),
        mimetype="application/json"
    )


@app.route(route="samplingtest", methods=["GET"])
def sampling_test(req: func.HttpRequest) -> func.HttpResponse:
    """
    Generates many log entries to test Application Insights sampling behavior.
    
    When sampling is enabled (isEnabled: true in host.json), not all logs
    will appear in Application Insights. This endpoint helps visualize that behavior.
    
    Query parameters:
    - count: Number of log entries to generate (default: 50)
    """
    count = min(int(req.params.get("count", "50")), 500)
    
    logging.info(f"Starting sampling test - generating {count} log entries")
    
    for i in range(count):
        # Generate logs with unique identifiers to track sampling
        logging.info(f"Sampling test entry {i+1:04d}/{count:04d} - ID: {random.randint(10000, 99999)}")
    
    logging.info(f"Sampling test completed - {count} entries logged")
    
    return func.HttpResponse(
        json.dumps({
            "message": "Sampling test completed",
            "entriesGenerated": count,
            "note": "Query Application Insights traces table with: traces | where message contains 'Sampling test entry' | count"
        }, indent=2),
        mimetype="application/json"
    )


@app.route(route="healthcheck", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """
    Simple health check endpoint with minimal logging.
    """
    # Only log at debug level to reduce noise
    logging.debug("Health check called")
    
    return func.HttpResponse(
        json.dumps({"status": "healthy", "timestamp": time.time()}),
        mimetype="application/json"
    )


# ============================================================================
# Queue Operations Endpoint - Demonstrates Azure Storage Queue with Managed Identity
# ============================================================================

@app.route(route="queuemessage", methods=["POST"])
def queue_message(req: func.HttpRequest) -> func.HttpResponse:
    """
    Pushes messages to Azure Storage Queue using managed identity.
    
    This endpoint demonstrates:
    1. Azure Storage Queue operations with managed identity (no keys)
    2. Logging patterns for queue operations
    3. How sampling affects these logs in Application Insights
    
    Expected JSON body:
    {
        "message": "string",           // Message content (optional, default: auto-generated)
        "count": int,                  // Number of messages to send (optional, default: 1, max: 100)
        "includeMetadata": bool        // Include extra metadata in message (optional, default: true)
    }
    
    Example:
        curl -X POST https://<func-url>/api/queuemessage \
             -H "Content-Type: application/json" \
             -d '{"message": "Test message", "count": 5}'
    """
    correlation_id = str(uuid.uuid4())[:8]
    
    logging.info(f"[{correlation_id}] Queue message endpoint triggered")
    
    try:
        # Parse request body
        try:
            req_body = req.get_json()
        except ValueError:
            req_body = {}
        
        message_content = req_body.get("message", f"Auto-generated message at {time.time()}")
        count = min(int(req_body.get("count", 1)), 100)  # Cap at 100
        include_metadata = req_body.get("includeMetadata", True)
        
        logging.info(f"[{correlation_id}] Preparing to send {count} message(s) to queue '{QUEUE_NAME}'")
        logging.debug(f"[{correlation_id}] Storage account: {STORAGE_ACCOUNT_NAME}")
        
        # Get queue client with managed identity
        queue_client = get_queue_client()
        
        # Create queue if it doesn't exist
        try:
            queue_client.create_queue()
            logging.info(f"[{correlation_id}] Queue '{QUEUE_NAME}' created or already exists")
        except Exception as e:
            # Queue might already exist, which is fine
            logging.debug(f"[{correlation_id}] Queue creation note: {str(e)}")
        
        # Send messages
        sent_messages = []
        start_time = time.time()
        
        for i in range(count):
            # Build message payload
            if include_metadata:
                payload = {
                    "id": str(uuid.uuid4()),
                    "content": message_content,
                    "sequence": i + 1,
                    "totalCount": count,
                    "correlationId": correlation_id,
                    "timestamp": time.time(),
                    "source": "logging-optimization-demo"
                }
            else:
                payload = {"content": message_content, "sequence": i + 1}
            
            message_json = json.dumps(payload)
            
            # Send message to queue
            logging.debug(f"[{correlation_id}] Sending message {i+1}/{count}")
            response = queue_client.send_message(message_json)
            
            sent_messages.append({
                "messageId": response.id,
                "sequence": i + 1,
                "insertedOn": str(response.inserted_on)
            })
            
            # Log at different intervals for sampling demonstration
            if (i + 1) % 10 == 0:
                logging.info(f"[{correlation_id}] Progress: {i+1}/{count} messages sent")
        
        elapsed_time = time.time() - start_time
        
        logging.info(f"[{correlation_id}] Successfully sent {count} messages in {elapsed_time:.3f}s")
        
        # Return summary
        return func.HttpResponse(
            json.dumps({
                "success": True,
                "correlationId": correlation_id,
                "queueName": QUEUE_NAME,
                "messagesSent": count,
                "elapsedTimeMs": round(elapsed_time * 1000, 2),
                "averageTimePerMessageMs": round((elapsed_time / count) * 1000, 2) if count > 0 else 0,
                "messages": sent_messages[:10],  # Return first 10 for brevity
                "samplingNote": "Check Application Insights: traces | where message contains '" + correlation_id + "' | count"
            }, indent=2),
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"[{correlation_id}] Error sending queue message: {str(e)}")
        logging.exception(f"[{correlation_id}] Full exception details")
        
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "correlationId": correlation_id,
                "error": str(e),
                "errorType": type(e).__name__
            }, indent=2),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="queuestatus", methods=["GET"])
def queue_status(req: func.HttpRequest) -> func.HttpResponse:
    """
    Gets the status of the logging test queue.
    
    Returns queue properties including approximate message count.
    """
    correlation_id = str(uuid.uuid4())[:8]
    
    logging.info(f"[{correlation_id}] Queue status check requested")
    
    try:
        queue_client = get_queue_client()
        
        # Get queue properties
        properties = queue_client.get_queue_properties()
        
        logging.info(f"[{correlation_id}] Queue status retrieved successfully")
        
        return func.HttpResponse(
            json.dumps({
                "success": True,
                "correlationId": correlation_id,
                "queueName": QUEUE_NAME,
                "storageAccount": STORAGE_ACCOUNT_NAME,
                "approximateMessageCount": properties.approximate_message_count,
                "metadata": dict(properties.metadata) if properties.metadata else {}
            }, indent=2),
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"[{correlation_id}] Error getting queue status: {str(e)}")
        
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "correlationId": correlation_id,
                "error": str(e),
                "note": "Queue may not exist yet. Send a message first using POST /api/queuemessage"
            }, indent=2),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="queueclear", methods=["DELETE"])
def queue_clear(req: func.HttpRequest) -> func.HttpResponse:
    """
    Clears all messages from the queue.
    
    Useful for resetting the queue during testing.
    """
    correlation_id = str(uuid.uuid4())[:8]
    
    logging.warning(f"[{correlation_id}] Queue clear requested - this will delete all messages!")
    
    try:
        queue_client = get_queue_client()
        
        # Clear all messages
        queue_client.clear_messages()
        
        logging.info(f"[{correlation_id}] Queue cleared successfully")
        
        return func.HttpResponse(
            json.dumps({
                "success": True,
                "correlationId": correlation_id,
                "queueName": QUEUE_NAME,
                "message": "All messages cleared from queue"
            }, indent=2),
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"[{correlation_id}] Error clearing queue: {str(e)}")
        
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "correlationId": correlation_id,
                "error": str(e)
            }, indent=2),
            status_code=500,
            mimetype="application/json"
        )
