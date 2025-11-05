#!/usr/bin/env python3
"""
MCP Server for WSL-Windows Script Runner
Provides native Claude tools for executing Windows scripts from WSL
"""

import asyncio
import json
import os
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent, ImageContent, EmbeddedResource

# Configuration
BASE_DIR = Path("/mnt/d/Dev2/wsl-windows-script-runner")
QUEUE_DIR = BASE_DIR / "queue"
LOGS_DIR = BASE_DIR / "logs"
COMPLETED_DIR = BASE_DIR / "completed"
ARCHIVE_DIR = BASE_DIR / "archive"

# Ensure directories exist
for directory in [QUEUE_DIR, LOGS_DIR, COMPLETED_DIR, ARCHIVE_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

app = Server("windows-runner")


def generate_script_name(prefix: str = "script") -> str:
    """Generate a unique script name with timestamp"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_id = str(uuid.uuid4())[:8]
    return f"{prefix}_{timestamp}_{unique_id}"


def create_powershell_script(content: str, script_name: Optional[str] = None) -> Path:
    """Create a PowerShell script in the queue directory"""
    if script_name is None:
        script_name = generate_script_name("ps")

    if not script_name.endswith(".ps1"):
        script_name += ".ps1"

    script_path = QUEUE_DIR / script_name
    script_path.write_text(content, encoding="utf-8")
    return script_path


def create_batch_script(content: str, script_name: Optional[str] = None) -> Path:
    """Create a batch script in the queue directory"""
    if script_name is None:
        script_name = generate_script_name("bat")

    if not script_name.endswith(".bat"):
        script_name += ".bat"

    script_path = QUEUE_DIR / script_name
    script_path.write_text(content, encoding="utf-8")
    return script_path


async def wait_for_execution(script_name: str, timeout: int = 60, poll_interval: float = 0.5) -> dict:
    """
    Wait for a script to be executed and return the results

    Returns:
        dict with keys: success, log_file, log_content, exit_code, duration
    """
    script_stem = Path(script_name).stem
    start_time = time.time()

    # Wait for script to be picked up from queue
    script_path = QUEUE_DIR / script_name
    while script_path.exists() and (time.time() - start_time) < timeout:
        await asyncio.sleep(poll_interval)

    if script_path.exists():
        return {
            "success": False,
            "error": "Timeout: Script was not picked up from queue",
            "timeout": True
        }

    # Wait for log file to appear
    log_found = False
    log_file = None

    while (time.time() - start_time) < timeout:
        # Look for log files matching the script name
        log_files = list(LOGS_DIR.glob(f"{script_stem}_*.log"))
        if log_files:
            # Get the most recent one
            log_file = max(log_files, key=lambda p: p.stat().st_mtime)
            log_found = True
            break
        await asyncio.sleep(poll_interval)

    if not log_found:
        return {
            "success": False,
            "error": "Timeout: Log file not created",
            "timeout": True
        }

    # Read the log file
    log_content = log_file.read_text(encoding="utf-8")

    # Parse exit code and status from log
    exit_code = None
    status = None
    duration = None

    for line in log_content.split("\n"):
        if line.startswith("Exit Code:"):
            try:
                exit_code = int(line.split(":")[-1].strip())
            except ValueError:
                pass
        elif line.startswith("Status:"):
            status = line.split(":")[-1].strip()
        elif line.startswith("Duration:"):
            duration = line.split(":")[-1].strip()

    success = (exit_code == 0) if exit_code is not None else (status == "SUCCESS")

    return {
        "success": success,
        "log_file": str(log_file.name),
        "log_content": log_content,
        "exit_code": exit_code,
        "status": status,
        "duration": duration,
        "timeout": False
    }


def get_runner_status() -> dict:
    """Get the current status of the Windows script runner"""
    queue_files = list(QUEUE_DIR.glob("*.ps1")) + list(QUEUE_DIR.glob("*.bat")) + list(QUEUE_DIR.glob("*.cmd"))
    log_files = list(LOGS_DIR.glob("*.log"))
    completed_files = list(COMPLETED_DIR.glob("*"))
    archive_files = list(ARCHIVE_DIR.glob("*"))

    latest_log = None
    if log_files:
        latest_log = max(log_files, key=lambda p: p.stat().st_mtime)

    return {
        "queue": {
            "path": str(QUEUE_DIR),
            "pending_scripts": len(queue_files),
            "files": [f.name for f in queue_files]
        },
        "logs": {
            "path": str(LOGS_DIR),
            "total_logs": len(log_files),
            "latest": latest_log.name if latest_log else None,
            "latest_time": datetime.fromtimestamp(latest_log.stat().st_mtime).isoformat() if latest_log else None
        },
        "completed": {
            "path": str(COMPLETED_DIR),
            "count": len(completed_files)
        },
        "archive": {
            "path": str(ARCHIVE_DIR),
            "count": len(archive_files)
        }
    }


def list_recent_logs(limit: int = 10, pattern: Optional[str] = None) -> list:
    """List recent log files"""
    log_files = list(LOGS_DIR.glob("*.log"))

    if pattern:
        log_files = [f for f in log_files if pattern.lower() in f.name.lower()]

    # Sort by modification time, newest first
    log_files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    log_files = log_files[:limit]

    return [
        {
            "name": f.name,
            "size_kb": round(f.stat().st_size / 1024, 2),
            "modified": datetime.fromtimestamp(f.stat().st_mtime).isoformat()
        }
        for f in log_files
    ]


def read_log_file(log_name: str) -> Optional[str]:
    """Read a specific log file"""
    log_path = LOGS_DIR / log_name

    if not log_path.exists():
        return None

    return log_path.read_text(encoding="utf-8")


@app.list_tools()
async def list_tools() -> list[Tool]:
    """List available tools"""
    return [
        Tool(
            name="windows_execute",
            description=(
                "Execute PowerShell commands or scripts on Windows from WSL. "
                "Supports single commands or multi-line scripts. "
                "Can wait for execution to complete and return results."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "PowerShell command or script to execute"
                    },
                    "script_name": {
                        "type": "string",
                        "description": "Optional custom name for the script (without extension)"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for execution to complete and return results (default: true)",
                        "default": True
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait for execution (default: 60)",
                        "default": 60
                    }
                },
                "required": ["command"]
            }
        ),
        Tool(
            name="windows_execute_batch",
            description=(
                "Execute batch/cmd commands on Windows from WSL. "
                "Can wait for execution to complete and return results."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "Batch command or script to execute"
                    },
                    "script_name": {
                        "type": "string",
                        "description": "Optional custom name for the script (without extension)"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for execution to complete and return results (default: true)",
                        "default": True
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait for execution (default: 60)",
                        "default": 60
                    }
                },
                "required": ["command"]
            }
        ),
        Tool(
            name="windows_get_status",
            description="Get the current status of the Windows script runner, including queue, logs, and execution statistics",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="windows_list_logs",
            description="List recent execution log files with optional filtering",
            inputSchema={
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of logs to return (default: 10)",
                        "default": 10
                    },
                    "pattern": {
                        "type": "string",
                        "description": "Optional filter pattern to match log names"
                    }
                }
            }
        ),
        Tool(
            name="windows_read_log",
            description="Read the complete contents of a specific log file",
            inputSchema={
                "type": "object",
                "properties": {
                    "log_name": {
                        "type": "string",
                        "description": "Name of the log file to read"
                    }
                },
                "required": ["log_name"]
            }
        )
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> list[TextContent]:
    """Handle tool calls"""

    if name == "windows_execute":
        command = arguments["command"]
        script_name = arguments.get("script_name")
        wait = arguments.get("wait", True)
        timeout = arguments.get("timeout", 60)

        # Create the script
        script_path = create_powershell_script(command, script_name)
        script_filename = script_path.name

        result = {
            "script_name": script_filename,
            "submitted": True,
            "queue_path": str(script_path)
        }

        if wait:
            # Wait for execution
            exec_result = await wait_for_execution(script_filename, timeout)
            result.update(exec_result)

        return [TextContent(
            type="text",
            text=json.dumps(result, indent=2)
        )]

    elif name == "windows_execute_batch":
        command = arguments["command"]
        script_name = arguments.get("script_name")
        wait = arguments.get("wait", True)
        timeout = arguments.get("timeout", 60)

        # Create the script
        script_path = create_batch_script(command, script_name)
        script_filename = script_path.name

        result = {
            "script_name": script_filename,
            "submitted": True,
            "queue_path": str(script_path)
        }

        if wait:
            # Wait for execution
            exec_result = await wait_for_execution(script_filename, timeout)
            result.update(exec_result)

        return [TextContent(
            type="text",
            text=json.dumps(result, indent=2)
        )]

    elif name == "windows_get_status":
        status = get_runner_status()
        return [TextContent(
            type="text",
            text=json.dumps(status, indent=2)
        )]

    elif name == "windows_list_logs":
        limit = arguments.get("limit", 10)
        pattern = arguments.get("pattern")

        logs = list_recent_logs(limit, pattern)
        return [TextContent(
            type="text",
            text=json.dumps(logs, indent=2)
        )]

    elif name == "windows_read_log":
        log_name = arguments["log_name"]
        content = read_log_file(log_name)

        if content is None:
            return [TextContent(
                type="text",
                text=json.dumps({
                    "error": f"Log file not found: {log_name}"
                })
            )]

        return [TextContent(
            type="text",
            text=content
        )]

    else:
        raise ValueError(f"Unknown tool: {name}")


async def main():
    """Run the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
