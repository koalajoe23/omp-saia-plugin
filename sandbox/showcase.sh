#!/usr/bin/env bash
# SAIA Plugin Sandbox - Showcase Mode
# Demonstrates the plugin by having pi generate creative content
# Small, fast, and works without extra dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_header() {
    echo -e "${MAGENTA}\n╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  $(printf "%-54s" "$1")  ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
}

echo_step() { echo -e "${CYAN}[Step ${1}]${NC} ${2}"; }
echo_info() { echo -e "${BLUE}  →${NC} ${1}"; }
echo_success() { echo -e "${GREEN}  ✓${NC} ${1}"; }
echo_warning() { echo -e "${YELLOW}  ⚠${NC} ${1}"; }
echo_error() { echo -e "${RED}  ✗${NC} ${1}"; }

echo_ascii() {
    echo -e "${1}"
}

show_help() {
    echo_header "SAIA Plugin Sandbox - Showcase Mode"
    cat << EOF

This showcase demonstrates the SAIA plugin capabilities by generating
creative content. It's designed to be fast, reliable, and show off
what pi can do with SAIA models.

Usage: $(basename "$0") [OPTIONS] [COMMAND]

Commands:
  ascii           Generate ASCII art (fast, no API needed)
  story           Generate a mini text adventure story
  riddle          Generate a riddle to solve
  joke            Generate a programming joke
  wisdom          Generate wise advice
  custom PROMPT   Send a custom prompt to pi

Options:
  -m, --model MODEL     Use specific SAIA model (default: auto)
  -p, --profile PROFILE Use profile: production, development, budget
  -n, --no-api         Use only built-in content (no API calls)
  -h, --help           Show this help message

Examples:
  $(basename "$0") ascii                 # Show cool ASCII art
  $(basename "$0") story                # Generate a mini story
  $(basename "$0") riddle               # Get a riddle to solve
  $(basename "$0") -m saia/qwen3.5-35b-a3b story  # Use specific model
  SAIA_API_KEY=your_key $(basename "$0") custom "Write a haiku about coding"

Note:
  - With SAIA_API_KEY set, pi will use real SAIA models
  - Without API key, built-in content is used
  - The 'ascii' command works offline

EOF
    exit 0
}

# Parse arguments
MODEL=""
PROFILE=""
NO_API=false
COMMAND=""
CUSTOM_PROMPT=""

# Parse named arguments first
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -n|--no-api)
            NO_API=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

# The remaining arguments are the command
if [ $# -gt 0 ]; then
    if [ "$1" = "custom" ] && [ $# -gt 1 ]; then
        COMMAND="custom"
        shift
        CUSTOM_PROMPT="$@"
    else
        COMMAND="$1"
        shift
        CUSTOM_PROMPT="$@"
    fi
fi

# If no command, show menu
if [ -z "$COMMAND" ]; then
    echo_header "SAIA Plugin Sandbox - Showcase"
    cat << EOF

Choose a showcase (or use -h for help):

  ${GREEN}ascii${NC}    - Generate beautiful ASCII art
  ${GREEN}story${NC}   - Generate a mini text adventure
  ${GREEN}riddle${NC}  - Get a riddle to solve
  ${GREEN}joke${NC}    - Programming humor
  ${GREEN}wisdom${NC}  - Wise advice

To use a specific SAIA model:
  $(basename "$0") -m saia/qwen3.5-35b-a3b ascii

To use custom prompt:
  SAIA_API_KEY=your_key $(basename "$0") custom "Write a haiku about AI"

EOF
    exit 0
fi

# Check if we're running in a container
IN_CONTAINER=false
if [ -f /.dockerenv ]; then
    IN_CONTAINER=true
fi

# Check if pi is available
PI_AVAILABLE=false
if command -v pi &> /dev/null; then
    PI_AVAILABLE=true
fi

# Check if we have API key
HAS_API_KEY=false
if [ -n "${SAIA_API_KEY:-}" ]; then
    HAS_API_KEY=true
fi

# Can we use pi with API
CAN_USE_PI=false
if [ "$PI_AVAILABLE" = true ] && [ "$HAS_API_KEY" = true ] && [ "$NO_API" = false ]; then
    CAN_USE_PI=true
fi

# Main functions
run_ascii_showcase() {
    echo_header "ASCII Art Showcase"
    echo ""
    
    echo_step "1" "Generating ASCII art"
    echo ""
    
    if [ "$CAN_USE_PI" = true ]; then
        echo_info "Using pi with SAIA to generate custom ASCII art..."
        
        local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
        if [ -n "$PROFILE" ]; then
            export SAIA_PROFILE="$PROFILE"
        fi
        
        # Create temporary config
        mkdir -p ~/.config/pi
        cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
        
        # Generate ASCII art with pi
        local prompt="Generate a cool ASCII art image in a code block. Theme: a rocket launching. Max 20 lines. Only output the ASCII art, no other text."
        
        echo_info "Prompting pi for ASCII art..."
        local output
        output=$(echo "$prompt" | pi 2>&1 || echo "")
        
        if [ -n "$output" ] && ! echo "$output" | grep -qi "error\|Sorry\|I can't"; then
            echo ""
            echo_ascii "$output"
            echo ""
            echo_success "ASCII art generated by pi + SAIA!"
            return 0
        fi
        
        echo_warning "pi generation failed, using built-in art"
    fi
    
    # Fallback to built-in ASCII art
    echo_info "Using built-in ASCII art..."
    echo ""
    
    # Rocket ASCII art
    local rocket=(
        "        /\\       "
        "       /  \\      "
        "      /    \\     "
        "     /      \\    "
        "    /        \\   "
        "   /          \\  "
        "  /   SAIA     \\ "
        " /    pi       \\"
        "/              \\"
        "|              |"
        "|              |"
        "|              |"
        "+--------------+"
        "   |      |    "
        "   |      |    "
        "  /        \\  "
        " /          \\ "
        "/            \\"
        "~~~~~~~~~~~~~~"
    )
    
    for line in "${rocket[@]}"; do
        echo_ascii "$line"
    done
    
    echo ""
    echo_success "✓ ASCII art displayed"
    echo ""
    
    # Add some info
    if [ "$HAS_API_KEY" = false ]; then
        echo_info "Set SAIA_API_KEY to have pi generate custom ASCII art"
    fi
}

run_story_showcase() {
    echo_header "Mini Text Adventure Showcase"
    echo ""
    
    echo_step "1" "Generating a mini story"
    echo ""
    
    if [ "$CAN_USE_PI" = true ]; then
        echo_info "Using pi with SAIA to create a mini adventure..."
        
        local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
        if [ -n "$PROFILE" ]; then
            export SAIA_PROFILE="$PROFILE"
        fi
        
        # Create temporary config
        mkdir -p ~/.config/pi
        cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
        
        local prompt="Write a short interactive text adventure with 3 scenes. Each scene has 2 choices. Format as markdown. Setting: a mysterious programming cave. Only output the story, max 500 words total."
        
        echo_info "Generating story with pi..."
        local output
        output=$(echo "$prompt" | pi 2>&1 || echo "")
        
        if [ -n "$output" ] && ! echo "$output" | grep -qi "error\|Sorry\|I can't"; then
            echo ""
            echo "$output"
            echo ""
            echo_success "Story generated by pi + SAIA!"
            return 0
        fi
        
        echo_warning "pi generation failed, using built-in story"
    fi
    
    # Built-in mini story
    echo_info "Using built-in adventure..."
    echo ""
    
    cat << 'STORY'
You enter a dark cave filled with glowing terminals. 
The air hums with the sound of servers.

Two paths lie before you:
1. Go left - towards a flickering monitor showing matrix code
2. Go right - towards a door labeled "/dev/null"

You choose path 1.

The screen displays: "42" and opens a passage. Inside, you find
a treasure chest containing... a USB stick with all the world's
Python libraries!

The end. (You win!)
STORY
    
    echo ""
    echo_success "✓ Mini adventure displayed"
}

run_riddle_showcase() {
    echo_header "Riddle Showcase"
    echo ""
    
    echo_step "1" "Generating a riddle"
    echo ""
    
    if [ "$CAN_USE_PI" = true ]; then
        echo_info "Using pi to create a riddle..."
        
        local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
        if [ -n "$PROFILE" ]; then
            export SAIA_PROFILE="$PROFILE"
        fi
        
        mkdir -p ~/.config/pi
        cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
        
        local prompt="Create a programming-themed riddle with the answer. Format: Riddle: [question] Answer: [answer]. Keep it short and clever."
        
        echo_info "Generating riddle with pi..."
        local output
        output=$(echo "$prompt" | pi 2>&1 || echo "")
        
        if [ -n "$output" ] && ! echo "$output" | grep -qi "error\|Sorry\|I can't"; then
            echo ""
            echo "$output"
            echo ""
            echo_success "Riddle generated by pi + SAIA!"
            return 0
        fi
        
        echo_warning "pi generation failed, using built-in riddle"
    fi
    
    # Built-in riddle
    echo_info "Using built-in riddle..."
    echo ""
    
    cat << 'RIDDLE'
Riddle: I speak without a mouth and hear without ears.
        I have no body, but I come alive with wind.
        What am I?

Answer: An echo (or in programming: a function call!)
RIDDLE
    
    echo ""
    echo_success "✓ Riddle displayed"
}

run_joke_showcase() {
    echo_header "Programming Joke Showcase"
    echo ""
    
    echo_step "1" "Generating a joke"
    echo ""
    
    if [ "$CAN_USE_PI" = true ]; then
        echo_info "Using pi to tell a joke..."
        
        local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
        if [ -n "$PROFILE" ]; then
            export SAIA_PROFILE="$PROFILE"
        fi
        
        mkdir -p ~/.config/pi
        cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
        
        local prompt="Tell a short programming joke. One line. Edgy but appropriate."
        
        echo_info "Generating joke with pi..."
        local output
        output=$(echo "$prompt" | pi 2>&1 || echo "")
        
        if [ -n "$output" ] && ! echo "$output" | grep -qi "error\|Sorry\|I can't"; then
            echo ""
            echo "$output"
            echo ""
            echo_success "Joke by pi + SAIA! 😄"
            return 0
        fi
        
        echo_warning "pi generation failed, using built-in joke"
    fi
    
    # Built-in jokes
    local jokes=(
        "Why do programmers prefer dark mode? Because light attracts bugs!"
        "Why did the developer go broke? Because he used up all his cache."
        "I would tell you a UDP joke, but you might not get it."
        "There are only 10 types of people in the world: those who understand binary and those who don't."
        "A SQL query walks into a bar, goes to two tables and asks for a join."
        "Why do Java developers wear glasses? Because they can't C#."
    )
    
    local joke="${jokes[RANDOM % ${#jokes[@]}]}"
    
    echo_info "Using built-in humor..."
    echo ""
    echo "  $joke"
    echo ""
    echo_success "✓ Joke displayed 😄"
}

run_wisdom_showcase() {
    echo_header "Wise Advice Showcase"
    echo ""
    
    echo_step "1" "Generating wisdom"
    echo ""
    
    if [ "$CAN_USE_PI" = true ]; then
        echo_info "Consulting the AI oracle..."
        
        local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
        if [ -n "$PROFILE" ]; then
            export SAIA_PROFILE="$PROFILE"
        fi
        
        mkdir -p ~/.config/pi
        cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
        
        local prompt="Give me one sentence of profound programming wisdom. Inspiring and thought-provoking."
        
        echo_info "Receiving wisdom from pi..."
        local output
        output=$(echo "$prompt" | pi 2>&1 || echo "")
        
        if [ -n "$output" ] && ! echo "$output" | grep -qi "error\|Sorry\|I can't"; then
            echo ""
            echo "  ${CYAN}"$output"${NC}"
            echo ""
            echo_success "Wisdom from pi + SAIA! 🧠"
            return 0
        fi
        
        echo_warning "pi generation failed, using built-in wisdom"
    fi
    
    # Built-in wisdom
    local wisdom=(
        "Code is read more often than it is written. - Guido van Rossum"
        "First, solve the problem. Then, write the code. - John Johnson"
        "Simplicity is the soul of efficiency. - Austin Freeman"
        "The best code is no code at all. - Jeff Atwood"
        "Make it work, make it right, make it fast. - Kent Beck"
        "Programs must be written for people to read, and only incidentally for machines to execute. - Harold Abelson"
        "Debugging is twice as hard as writing the code in the first place. - Brian Kernighan"
    )
    
    local saying="${wisdom[RANDOM % ${#wisdom[@]}]}"
    
    echo_info "Sharing programming wisdom..."
    echo ""
    echo "  ${CYAN}$saying${NC}"
    echo ""
    echo_success "✓ Wisdom shared 🧠"
}

run_custom_showcase() {
    if [ -z "$CUSTOM_PROMPT" ]; then
        echo_error "No custom prompt provided"
        echo_info "Usage: $(basename "$0") custom "Your prompt here""
        exit 1
    fi
    
    echo_header "Custom Prompt"
    echo ""
    echo_step "1" "Sending custom prompt to pi"
    echo_info "Prompt: $CUSTOM_PROMPT"
    echo ""
    
    if [ "$CAN_USE_PI" = false ]; then
        echo_error "Cannot use pi - no API key or pi not available"
        echo_info "Set SAIA_API_KEY and ensure pi is installed"
        exit 1
    fi
    
    local model_to_use="${MODEL:-saia/qwen3.5-35b-a3b}"
    if [ -n "$PROFILE" ]; then
        export SAIA_PROFILE="$PROFILE"
    fi
    
    mkdir -p ~/.config/pi
    cat > ~/.config/pi/pi.json << EOL
{
  "model": "${model_to_use}",
  "plugin": ["saia"],
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow"
  }
}
EOL
    
    echo_info "Getting response from pi..."
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    echo "$CUSTOM_PROMPT" | pi 2>&1 || echo "pi failed to respond"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo_success "Custom prompt completed"
}

# Main execution
main() {
    case "$COMMAND" in
        ascii)
            run_ascii_showcase
            ;;
        story)
            run_story_showcase
            ;;
        riddle)
            run_riddle_showcase
            ;;
        joke)
            run_joke_showcase
            ;;
        wisdom)
            run_wisdom_showcase
            ;;
        custom)
            run_custom_showcase
            ;;
        *)
            echo_error "Unknown command: $COMMAND"
            show_help
            ;;
    esac
}

main
