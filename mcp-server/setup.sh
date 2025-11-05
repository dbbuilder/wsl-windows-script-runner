#!/bin/bash

# Setup script for WSL-Windows Script Runner MCP Server

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() { echo -e "${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}! $1${NC}"; }

MCP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$MCP_DIR/venv"

print_header
print_info "WSL-Windows Script Runner - MCP Server Setup"
print_header
echo ""

# Check Python version
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    echo "Install with: sudo apt-get update && sudo apt-get install python3 python3-pip python3-venv"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
print_success "Found Python $PYTHON_VERSION"

# Create virtual environment
if [ -d "$VENV_DIR" ]; then
    print_warning "Virtual environment already exists"
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VENV_DIR"
        print_info "Removed existing virtual environment"
    fi
fi

if [ ! -d "$VENV_DIR" ]; then
    print_info "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    print_success "Virtual environment created"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
print_info "Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1
print_success "Pip upgraded"

# Install dependencies
print_info "Installing dependencies..."
pip install -r "$MCP_DIR/requirements.txt"
print_success "Dependencies installed"

# Make server executable
chmod +x "$MCP_DIR/server.py"
print_success "Server made executable"

echo ""
print_header
print_success "MCP Server Setup Complete!"
print_header
echo ""

print_info "Next Steps:"
echo ""
echo "1. Make sure the Windows Script Watcher is installed and running:"
echo "   ${CYAN}(Windows PowerShell as Admin)${NC}"
echo "   ${YELLOW}cd D:\\Dev2\\wsl-windows-script-runner${NC}"
echo "   ${YELLOW}.\\Install-ScriptWatcher.ps1${NC}"
echo ""
echo "2. Add this MCP server to your Claude Code configuration:"
echo "   ${CYAN}~/.config/claude/claude_desktop_config.json${NC}"
echo ""
echo "   Add to the 'mcpServers' section:"
echo ""
echo '   {
     "mcpServers": {
       "windows-runner": {
         "command": "'"$VENV_DIR/bin/python"'",
         "args": ["'"$MCP_DIR/server.py"'"]
       }
     }
   }'
echo ""
echo "3. Restart Claude Code to load the MCP server"
echo ""
echo "4. Test with:"
echo "   ${YELLOW}windows_execute${NC} - Execute PowerShell commands"
echo "   ${YELLOW}windows_get_status${NC} - Check runner status"
echo "   ${YELLOW}windows_list_logs${NC} - View recent logs"
echo ""
print_header
echo ""
print_info "Virtual environment path: $VENV_DIR"
print_info "Server path: $MCP_DIR/server.py"
echo ""
