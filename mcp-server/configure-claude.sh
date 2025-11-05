#!/bin/bash

# Helper script to configure Claude Code with the MCP server

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() { echo -e "${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}! $1${NC}"; }

MCP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$MCP_DIR/venv/bin/python"
SERVER_PATH="$MCP_DIR/server.py"

# Determine Claude config path
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
else
    CLAUDE_CONFIG_DIR="$HOME/.config/claude"
fi

CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

print_header
print_info "Claude Code MCP Server Configuration"
print_header
echo ""

# Check if virtual environment exists
if [ ! -f "$VENV_PYTHON" ]; then
    print_error "Virtual environment not found!"
    echo "Run ./setup.sh first to install the MCP server"
    exit 1
fi

print_success "Found MCP server at: $SERVER_PATH"
print_success "Found Python at: $VENV_PYTHON"
echo ""

# Create Claude config directory if needed
if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
    print_info "Creating Claude config directory: $CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"
fi

# Generate MCP server configuration
read -r -d '' MCP_CONFIG << EOM || true
{
  "mcpServers": {
    "windows-runner": {
      "command": "$VENV_PYTHON",
      "args": ["$SERVER_PATH"]
    }
  }
}
EOM

# Check if config file exists
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    print_warning "Claude config file already exists: $CLAUDE_CONFIG_FILE"
    echo ""
    echo "Current configuration:"
    cat "$CLAUDE_CONFIG_FILE" | python3 -m json.tool 2>/dev/null || cat "$CLAUDE_CONFIG_FILE"
    echo ""

    read -p "Do you want to merge the MCP server configuration? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_FILE="${CLAUDE_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CLAUDE_CONFIG_FILE" "$BACKUP_FILE"
        print_success "Backed up config to: $BACKUP_FILE"

        # Try to merge JSON
        if command -v jq &> /dev/null; then
            # Use jq to merge
            TEMP_FILE=$(mktemp)
            jq --argjson new_server "{\"windows-runner\": {\"command\": \"$VENV_PYTHON\", \"args\": [\"$SERVER_PATH\"]}}" \
               '.mcpServers += $new_server' \
               "$CLAUDE_CONFIG_FILE" > "$TEMP_FILE"

            mv "$TEMP_FILE" "$CLAUDE_CONFIG_FILE"
            print_success "Merged MCP server configuration"
        else
            print_warning "jq not found, showing manual merge instructions"
            echo ""
            echo "Add this to your 'mcpServers' section in $CLAUDE_CONFIG_FILE:"
            echo ""
            echo '    "windows-runner": {'
            echo "      \"command\": \"$VENV_PYTHON\","
            echo "      \"args\": [\"$SERVER_PATH\"]"
            echo '    }'
            echo ""
            exit 0
        fi
    else
        print_info "Configuration not modified"
        echo ""
        echo "To manually add the MCP server, add this to $CLAUDE_CONFIG_FILE:"
        echo ""
        echo "$MCP_CONFIG" | python3 -m json.tool
        exit 0
    fi
else
    # Create new config file
    print_info "Creating new Claude config file: $CLAUDE_CONFIG_FILE"
    echo "$MCP_CONFIG" | python3 -m json.tool > "$CLAUDE_CONFIG_FILE"
    print_success "Configuration file created"
fi

echo ""
print_header
print_success "Configuration Complete!"
print_header
echo ""

print_info "MCP Server Configuration:"
echo ""
cat "$CLAUDE_CONFIG_FILE" | python3 -m json.tool
echo ""

print_header
print_info "Next Steps:"
print_header
echo ""
echo "1. Restart Claude Code to load the MCP server"
echo ""
echo "2. Verify the MCP server is loaded by asking Claude:"
echo "   ${YELLOW}\"What MCP tools do you have available?\"${NC}"
echo ""
echo "3. Test the Windows runner:"
echo "   ${YELLOW}\"Use windows_execute to get the Windows username\"${NC}"
echo ""
echo "4. Check status:"
echo "   ${YELLOW}\"Check the Windows script runner status\"${NC}"
echo ""
print_header
