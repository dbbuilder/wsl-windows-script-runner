#!/bin/bash

# WSL Script Submission Helper
# This script helps submit Windows scripts from WSL to the Windows Script Runner

set -euo pipefail

# Configuration
QUEUE_DIR="/mnt/d/Dev2/wsl-windows-script-runner/queue"
LOGS_DIR="/mnt/d/Dev2/wsl-windows-script-runner/logs"
COMPLETED_DIR="/mnt/d/Dev2/wsl-windows-script-runner/completed"
ARCHIVE_DIR="/mnt/d/Dev2/wsl-windows-script-runner/archive"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Print colored output
print_header() { echo -e "${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_gray() { echo -e "${GRAY}$1${NC}"; }

# Show usage
show_usage() {
    print_header
    print_info "WSL-Windows Script Runner - Submission Helper"
    print_header
    echo ""
    echo "Usage:"
    echo "  $0 <script-file>           Submit a script to run on Windows"
    echo "  $0 --status                Show runner status"
    echo "  $0 --logs [pattern]        List recent logs (optional filter)"
    echo "  $0 --tail <logfile>        Tail a specific log file"
    echo "  $0 --watch                 Watch the queue directory"
    echo "  $0 --help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 myscript.ps1            Submit PowerShell script"
    echo "  $0 backup.bat              Submit batch script"
    echo "  $0 --logs                  List all logs"
    echo "  $0 --logs backup           List logs matching 'backup'"
    echo "  $0 --tail backup_20250115_143022.log"
    echo ""
    print_header
}

# Check if directories exist
check_directories() {
    if [[ ! -d "$QUEUE_DIR" ]]; then
        print_error "ERROR: Queue directory not found: $QUEUE_DIR"
        print_warning "Make sure the Windows Script Runner is installed."
        exit 1
    fi
}

# Submit a script
submit_script() {
    local script_path="$1"

    if [[ ! -f "$script_path" ]]; then
        print_error "ERROR: File not found: $script_path"
        exit 1
    fi

    # Check file extension
    local ext="${script_path##*.}"
    if [[ ! "$ext" =~ ^(ps1|bat|cmd)$ ]]; then
        print_error "ERROR: Unsupported file type: .$ext"
        print_warning "Supported types: .ps1, .bat, .cmd"
        exit 1
    fi

    local filename=$(basename "$script_path")
    local dest="$QUEUE_DIR/$filename"

    print_header
    print_info "Submitting script to Windows Script Runner"
    print_header
    echo ""
    echo "Source: $script_path"
    echo "Destination: $dest"
    echo ""

    # Copy the script to the queue
    if cp "$script_path" "$dest"; then
        print_success "Script submitted successfully!"
        echo ""
        print_info "The script will be executed automatically by the Windows runner."
        print_gray "Check logs in: $LOGS_DIR"
        echo ""

        # Wait a moment and check if the file is still in queue
        sleep 2
        if [[ ! -f "$dest" ]]; then
            print_success "Script has been picked up for execution!"
        else
            print_warning "Script is queued and waiting for execution..."
        fi
    else
        print_error "ERROR: Failed to copy script to queue"
        exit 1
    fi

    print_header
}

# Show status
show_status() {
    print_header
    print_info "WSL-Windows Script Runner - Status"
    print_header
    echo ""

    print_info "Queue Directory: $QUEUE_DIR"
    if [[ -d "$QUEUE_DIR" ]]; then
        local count=$(find "$QUEUE_DIR" -type f \( -name "*.ps1" -o -name "*.bat" -o -name "*.cmd" \) 2>/dev/null | wc -l)
        print_success "  Status: Exists"
        echo "  Pending scripts: $count"
        if [[ $count -gt 0 ]]; then
            echo ""
            print_warning "  Queued files:"
            find "$QUEUE_DIR" -type f \( -name "*.ps1" -o -name "*.bat" -o -name "*.cmd" \) -printf "    - %f\n" 2>/dev/null
        fi
    else
        print_error "  Status: NOT FOUND"
    fi

    echo ""
    print_info "Logs Directory: $LOGS_DIR"
    if [[ -d "$LOGS_DIR" ]]; then
        local count=$(find "$LOGS_DIR" -type f -name "*.log" 2>/dev/null | wc -l)
        print_success "  Status: Exists"
        echo "  Total logs: $count"
        if [[ $count -gt 0 ]]; then
            local latest=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
            if [[ -n "$latest" ]]; then
                echo "  Latest: $(basename "$latest")"
            fi
        fi
    else
        print_error "  Status: NOT FOUND"
    fi

    echo ""
    print_info "Completed Directory: $COMPLETED_DIR"
    if [[ -d "$COMPLETED_DIR" ]]; then
        local count=$(find "$COMPLETED_DIR" -type f 2>/dev/null | wc -l)
        print_success "  Status: Exists"
        echo "  Completed scripts: $count"
    else
        print_error "  Status: NOT FOUND"
    fi

    echo ""
    print_info "Archive Directory: $ARCHIVE_DIR"
    if [[ -d "$ARCHIVE_DIR" ]]; then
        local count=$(find "$ARCHIVE_DIR" -type f 2>/dev/null | wc -l)
        print_success "  Status: Exists"
        if [[ $count -gt 0 ]]; then
            print_warning "  Failed scripts: $count"
        else
            print_gray "  Failed scripts: $count"
        fi
    else
        print_error "  Status: NOT FOUND"
    fi

    echo ""
    print_header
}

# List logs
list_logs() {
    local pattern="${1:-}"

    print_header
    print_info "Recent Log Files"
    print_header
    echo ""

    if [[ ! -d "$LOGS_DIR" ]]; then
        print_error "Logs directory not found: $LOGS_DIR"
        exit 1
    fi

    if [[ -n "$pattern" ]]; then
        print_info "Filter: $pattern"
        echo ""
        ls -lht "$LOGS_DIR"/*"$pattern"*.log 2>/dev/null | head -20 | awk '{print $9, "(" $6, $7, $8 ")"}' || print_warning "No logs matching pattern: $pattern"
    else
        ls -lht "$LOGS_DIR"/*.log 2>/dev/null | head -20 | awk '{print $9, "(" $6, $7, $8 ")"}' || print_warning "No log files found"
    fi

    echo ""
    print_header
}

# Tail a log file
tail_log() {
    local logfile="$1"
    local fullpath="$LOGS_DIR/$logfile"

    if [[ ! -f "$fullpath" ]]; then
        # Try without adding the logs dir
        if [[ -f "$logfile" ]]; then
            fullpath="$logfile"
        else
            print_error "ERROR: Log file not found: $logfile"
            exit 1
        fi
    fi

    print_header
    print_info "Tailing log file: $(basename "$fullpath")"
    print_header
    echo ""

    tail -f "$fullpath"
}

# Watch the queue directory
watch_queue() {
    print_header
    print_info "Watching queue directory: $QUEUE_DIR"
    print_info "Press Ctrl+C to stop"
    print_header
    echo ""

    if ! command -v inotifywait &> /dev/null; then
        print_error "ERROR: inotifywait not found"
        print_warning "Install with: sudo apt-get install inotify-tools"
        exit 1
    fi

    inotifywait -m -e create,delete,modify "$QUEUE_DIR" --format '%T %e %f' --timefmt '%H:%M:%S'
}

# Main
main() {
    case "${1:-}" in
        --status)
            check_directories
            show_status
            ;;
        --logs)
            check_directories
            list_logs "${2:-}"
            ;;
        --tail)
            if [[ -z "${2:-}" ]]; then
                print_error "ERROR: Please specify a log file"
                echo "Usage: $0 --tail <logfile>"
                exit 1
            fi
            check_directories
            tail_log "$2"
            ;;
        --watch)
            check_directories
            watch_queue
            ;;
        --help|"")
            show_usage
            ;;
        *)
            check_directories
            submit_script "$1"
            ;;
    esac
}

main "$@"
