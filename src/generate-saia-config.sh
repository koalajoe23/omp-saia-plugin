#!/usr/bin/env bash
set -euo pipefail

# SAIA Configuration Manager for pi
# Fetches latest SAIA models from GWDG Chat AI API and generates pi configuration
# Uses curated model knowledge for accurate categorization and descriptions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONFIG="$SCRIPT_DIR/pi-saia.json"

# Parse flags
INCREMENTAL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --incremental) INCREMENTAL=true; shift ;;
        --help|-h) echo "Usage: $0 [--incremental]"; exit 0 ;;
        *) shift ;;
    esac
done

SAIA_API_KEY="${SAIA_API_KEY:-}"

# LiteLLM proxy support — if LITELLM_PROXY_URL is set, use the proxy instead of direct SAIA API
LITELLM_PROXY_URL="${LITELLM_PROXY_URL:-}"
USE_PROXY=false
if [[ -n "$LITELLM_PROXY_URL" ]]; then
    USE_PROXY=true
fi

# Profile support — select different model sets for production/dev/budget
SAIA_PROFILE="${SAIA_PROFILE:-production}"
PROFILE_CONFIG=""

if [[ "$SAIA_PROFILE" != "production" ]]; then
    MASTER_CONFIG="$SCRIPT_DIR/pi-saia-${SAIA_PROFILE}.json"
fi

configure_profile() {
    local profile="${1:-production}"
    case "$profile" in
        production)
            print_info "Using production profile (highest quality models)"
            PROFILE_CONFIG="production"
            ;;
        dev|development)
            print_info "Using development profile (balanced models, faster responses)"
            PROFILE_CONFIG="development"
            ;;
        budget)
            print_info "Using budget profile (cheapest, fastest models)"
            PROFILE_CONFIG="budget"
            ;;
        *)
            print_error "Unknown profile: $profile. Valid options: production, development, budget"
            exit 1
            ;;
    esac
}

configure_profile "$SAIA_PROFILE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ -z "$SAIA_API_KEY" ]]; then
    print_error "SAIA_API_KEY environment variable not set"
    print_info "Get one at: https://chat-ai.academiccloud.de"
    print_info "Then: export SAIA_API_KEY=your_key"
    exit 1
fi

if [[ "$USE_PROXY" == "true" ]]; then
    print_info "Using LiteLLM proxy at: $LITELLM_PROXY_URL"
fi

API_BASE_URL="${LITELLM_PROXY_URL:-https://chat-ai.academiccloud.de/v1}"

TIMING_START=$(date +%s%N)

print_info "Fetching latest SAIA models..."

FETCH_START=$(date +%s)
MODELS_JSON=$(curl -s --max-time 30 "${API_BASE_URL}/models" \
    -H "Authorization: Bearer $SAIA_API_KEY")
FETCH_END=$(date +%s)
FETCH_ELAPSED=$((FETCH_END - FETCH_START))
print_info "API fetch completed in ${FETCH_ELAPSED}s"

if [[ -z "$MODELS_JSON" ]] || ! echo "$MODELS_JSON" | jq -e '.data' >/dev/null 2>&1; then
    print_error "Failed to fetch models from SAIA API"
    print_info "Why this happened: Could be an invalid API key, network timeout, or server issue"
    print_info "Check:"
    print_info "  - SAIA_API_KEY is valid (not expired or revoked)"
    print_info "  - Network connectivity to: ${API_BASE_URL}/models"
    print_info "  - Proxy/VPN settings are not blocking the request"
    if [[ -z "$FETCH_ELAPSED" || "$FETCH_ELAPSED" -ge 30 ]]; then
        print_info "  - The request timed out after 30s (server may be slow or unreachable)"
    fi
    print_info "To verify your key manually: curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer <key>' ${API_BASE_URL}/models"
    exit 1
fi

MODEL_COUNT=$(echo "$MODELS_JSON" | jq -r '.data | length')
print_info "Found $MODEL_COUNT SAIA models"

# Cache last successful fetch timestamp
SAIA_CACHE_DIR="$HOME/.cache/saia"
mkdir -p "$SAIA_CACHE_DIR"
cat > "$SAIA_CACHE_DIR/last-fetch.json" <<EOF
{
  "lastFetchTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "modelCount": $MODEL_COUNT,
  "profile": "$SAIA_PROFILE",
  "elapsedSeconds": $FETCH_ELAPSED
}
EOF

# --- Model categorization ---
categorize() {
    local id="$1"
    case "$id" in
        *thinking*|*r1*|deepseek-r1*)        echo "reasoning" ;;
        *coder*)                            echo "coder" ;;
        *vl-*|*vision*|internvl*)           echo "vision" ;;
        medgemma*)                          echo "medical" ;;
        teuken*|sauerkraut*)                echo "research" ;;
        glm-4.7|devstral*)                  echo "agentic" ;;
        *120b|*235b|*675b|mistral-large*)   echo "large-context" ;;
        *)                                  echo "general" ;;
    esac
}

# --- Model metadata functions ---
get_cost_per_1k_tokens() {
    local id="$1"
    case "$id" in
        *8b*)                     echo "0.003" ;;
        *7b*|gemma-3-27b*)        echo "0.006" ;;
        *31b*|*32b*|teuken*)      echo "0.012" ;;
        *35b-a3b*|*30b*)          echo "0.018" ;;
        *70b*)                    echo "0.025" ;;
        *122b*)                   echo "0.038" ;;
        *235b*|mistral-large*)   echo "0.075" ;;
        *397b*|*675b*)            echo "0.125" ;;
        *)                        echo "0.015" ;;
    esac
}

get_estimated_latency_ms() {
    local id="$1"
    case "$id" in
        *8b*|*7b|gemma-3*)        echo "fast" ;;
        *27b*|teuken*|apertus*)   echo "moderate" ;;
        *31b*|*32b*)              echo "moderate" ;;
        *35b-a3b*|*30b*)          echo "moderate" ;;
        qwen3.5-122b*)            echo "slow" ;;
        qwen3-coder*)             echo "fast" ;;
        glm-4.7)                  echo "fast" ;;
        deepseek-r1*)             echo "slow" ;;
        *70b*)                    echo "slow" ;;
        *235b*|mistral-large*)   echo "slow" ;;
        *397b*|*675b*)            echo "very-slow" ;;
        *)                        echo "moderate" ;;
    esac
}

get_recommended_for() {
    local id="$1"
    case "$id" in
        *coder*)                 echo "agentic-coding,code-refactor,debug" ;;
        *vision*|*vl-*|internvl*)  echo "image-analysis,multimodal,diagrams" ;;
        *thinking*|*r1*|deepseek*) echo "complex-reasoning,math,planning" ;;
        glm-4.7|devstral*)       echo "agentic-coding,tool-use,architecture" ;;
        medical*)                echo "medical-qa,healthcare,biomedical" ;;
        teuken*|sauerkraut*)     echo "german-text,research,academic" ;;
        qwen3.5-397b*)           echo "complex-reasoning,high-quality-writing" ;;
        qwen3-5-122b*)           echo "balanced-response,fast-reasoning" ;;
        qwen3-5-35b*)            echo "fast-reasoning,general-purpose" ;;
        qwen3-5-27b*)            echo "efficient-reasoning,cost-optimization" ;;
        *8b*)                    echo "quick-edits,summarization,cost-optimization" ;;
        *70b*|*675b*)            echo "large-context,document-analysis,complex-tasks" ;;
        *235b*)                  echo "large-batch,context-heavy,multiple-files" ;;
        *)                       echo "general-purpose,chat,daily-tasks" ;;
    esac
}

include_in_profile() {
    local id="$1"
    local profile="$2"

    case "$profile" in
        production)
            include_in_profile_production "$id"
            ;;
        development|dev)
            include_in_profile_development "$id"
            ;;
        budget)
            include_in_profile_budget "$id"
            ;;
        *)
            return 0 # unknown profile, include all
            ;;
    esac
}

include_in_profile_production() {
    local id="$1"
    case "$id" in
        qwen3.5-397b-a17b|qwen3.5-122b-a10b|qwen3-235b-a22b|mistral-large-3-675b-instruct-2512|glm-4.7|devstral-2*)
            echo "true" ;;
        deepseek-r1*|*thinking*)
            echo "true" ;;
        *coder*|qwen3-vl*|internvl*)
            echo "true" ;;
        *)
            echo "false" ;;
    esac
}

include_in_profile_development() {
    local id="$1"
    case "$id" in
        qwen3.5-35b-a3b|qwen3.5-27b|qwen3-32b|llama-3.3-70b-instruct|gemma-3-27b*|gemma-4-31b*)
            echo "true" ;;
        qwen3-coder*|glm-4.7)
            echo "true" ;;
        *vl-*|*vision*|internvl*)
            echo "true" ;;
        *)
            echo "false" ;;
    esac
}

include_in_profile_budget() {
    local id="$1"
    case "$id" in
        llama-3.1-8b*|teuken-7b*|qwen3-30b-a3b-instruct*)
            echo "true" ;;
        gemma-3-27b*)
            echo "true" ;;
        *)
            echo "false" ;;
    esac
}

get_profile_default_model() {
    local profile="$1"
    case "$profile" in
        production)    echo "glm-4.7" ;;
        development|dev) echo "qwen3.5-35b-a3b" ;;
        budget)        echo "llama-3.1-8b-instruct" ;;
        *)             echo "glm-4.7" ;;
    esac
}

describe() {
    local id="$1"
    local cat="$2"
    case "$id" in
        qwen3.5-397b-a17b)       echo "Qwen3.5 397B MoE (128k ctx) — Flagship reasoning, best quality" ;;
        qwen3.5-122b-a10b)       echo "Qwen3.5 122B MoE (128k ctx) — Strong reasoning, fast" ;;
        qwen3.5-35b-a3b)         echo "Qwen3.5 35B MoE (128k ctx) — Fast reasoning" ;;
        qwen3.5-27b)             echo "Qwen3.5 27B Dense (128k ctx) — Efficient reasoning" ;;
        qwen3.6-35b-a3b)         echo "Qwen3.6 35B MoE — Vision, reasoning, agentic coding" ;;
        qwen3-235b-a22b)         echo "Qwen3 235B MoE (128k ctx) — Large context, strong generalist" ;;
        qwen3-32b)               echo "Qwen3 32B Dense (128k ctx) — Balanced" ;;
        qwen3-coder-30b-a3b-instruct) echo "Qwen3 Coder 30B — Code-specialized" ;;
        qwen3-omni-30b-a3b-instruct) echo "Qwen3 Omni 30B — Multimodal (text+audio)" ;;
        qwen3-vl-30b-a3b-instruct)   echo "Qwen3 VL 30B — Vision-language" ;;
        qwen3-30b-a3b-thinking-2507) echo "Qwen3 30B Thinking — Chain-of-thought reasoning" ;;
        qwen3-30b-a3b-instruct-2507) echo "Qwen3 30B Instruct — General purpose" ;;
        mistral-large-3-675b-instruct-2512) echo "Mistral Large 3 675B (128k ctx) — Largest model, strong generalist" ;;
        openai-gpt-oss-120b)     echo "OpenAI GPT-OSS 120B — Large context model" ;;
        devstral-2-123b-instruct-2512) echo "Devstral 2 123B — Mistral's agentic coder" ;;
        glm-4.7)                 echo "GLM-4.7 (128k ctx) — Agentic coding, strong tool use" ;;
        deepseek-r1-distill-llama-70b) echo "DeepSeek R1 Distill 70B — Reasoning (Llama base)" ;;
        gemma-3-27b-it)          echo "Gemma 3 27B — Google lightweight model" ;;
        gemma-4-31b-it)          echo "Gemma 4 31B — Google latest" ;;
        llama-3.3-70b-instruct)  echo "Llama 3.3 70B — Meta strong generalist" ;;
        llama-3.1-8b-instruct)   echo "Llama 3.1 8B — Meta fast lightweight" ;;
        apertus-70b-instruct-2509) echo "Apertus 70B — Open-source instruct model" ;;
        internvl3.5-30b-a3b)     echo "InternVL 3.5 30B — Vision-language" ;;
        medgemma-27b-it)         echo "MedGemma 27B — Medical domain specialist" ;;
        teuken-7b-instruct-research) echo "Teuken 7B — German research model" ;;
        llama-3.1-sauerkrautlm-70b-instruct) echo "SauerkrautLM 70B — German-enhanced Llama" ;;
        meta-llama-3.1-8b-instruct) echo "Llama 3.1 8B — Meta lightweight" ;;
        *)                       echo "$id — $(echo "$cat" | tr '[:lower:]' '[:upper:]')" ;;
    esac
}

can_reason() {
    local id="$1"
    case "$id" in
        *thinking*|*r1*|deepseek-r1*|qwen3.5-397b-a17b|qwen3.5-122b-a10b|qwen3.5-35b-a3b|qwen3.5-27b|qwen3.6-35b-a3b|glm-4.7|qwen3-235b-a22b|qwen3-30b-a3b-instruct-2507)
            echo "true" ;;
        *)
            echo "false" ;;
    esac
}

get_context_window() {
    local id="$1"
    case "$id" in
        qwen3.5-397b-a17b|qwen3.5-122b-a10b|qwen3.5-35b-a3b|qwen3.5-27b|qwen3.6-35b-a3b|qwen3-235b-a22b|qwen3-32b|mistral-large-3-675b-instruct-2512|glm-4.7|llama-3.3-70b-instruct|llama-3.1-8b-instruct|llama-3.1-sauerkrautlm-70b-instruct|meta-llama-3.1-8b-instruct|apertus-70b-instruct-2509|devstral-2-123b-instruct-2512|openai-gpt-oss-120b|deepseek-r1-distill-llama-70b)
            echo "128000" ;;
        gemma-3-27b-it|gemma-4-31b-it|qwen3-coder-30b-a3b-instruct|qwen3-30b-a3b-instruct-2507|qwen3-30b-a3b-thinking-2507)
            echo "131072" ;;
        qwen3-vl-30b-a3b-instruct|internvl3.5-30b-a3b|medgemma-27b-it|qwen3-omni-30b-a3b-instruct|teuken-7b-instruct-research)
            echo "32768" ;;
        *)
            echo "128000" ;;
    esac
}

supports_attachment() {
    local id="$1"
    case "$id" in
        qwen3-vl-30b-a3b-instruct|internvl3.5-30b-a3b|qwen3.6-35b-a3b|qwen3-omni-30b-a3b-instruct)
            echo "true" ;;
        *)
            echo "false" ;;
    esac
}

get_output_window() {
    local id="$1"
    case "$id" in
        qwen3.5-397b-a17b|qwen3.5-122b-a10b|qwen3.6-35b-a3b|mistral-large-3-675b-instruct-2512|qwen3-235b-a22b)
            echo "32768" ;;
        qwen3.5-35b-a3b|qwen3.5-27b|glm-4.7|devstral-2-123b-instruct-2512|qwen3-32b|qwen3-coder-30b-a3b-instruct|deepseek-r1-distill-llama-70b)
            echo "16384" ;;
        qwen3-30b-a3b-instruct-2507|qwen3-30b-a3b-thinking-2507)
            echo "16384" ;;
        gemma-3-27b-it|gemma-4-31b-it|llama-3.3-70b-instruct|apertus-70b-instruct-2509|openai-gpt-oss-120b)
            echo "8192" ;;
        internvl3.5-30b-a3b|qwen3-vl-30b-a3b-instruct|qwen3-omni-30b-a3b-instruct|medgemma-27b-it)
            echo "4096" ;;
        teuken-7b-instruct-research|llama-3.1-sauerkrautlm-70b-instruct|llama-3.1-8b-instruct|meta-llama-3.1-8b-instruct)
            echo "4096" ;;
        *)
            echo "8192" ;;
    esac
}

# --- Incremental mode ---
if [[ "$INCREMENTAL" == "true" && -f "$MASTER_CONFIG" ]]; then
    FRESH_IDS=$(echo "$MODELS_JSON" | jq -r '.data[].id' | sort)
    CURRENT_IDS=$(jq -r '.provider.saia.models | keys[]' "$MASTER_CONFIG" 2>/dev/null | sort)

    if [[ "$FRESH_IDS" == "$CURRENT_IDS" ]]; then
        ELAPSED=$(echo "scale=2; ($(date +%s%N) - $TIMING_START) / 1000000000" | bc 2>/dev/null || echo "0")
        print_info "No model changes detected — skipping regeneration"
        print_info "Config generation completed in ${ELAPSED}s"
        cp "$MASTER_CONFIG" ./pi.json 2>/dev/null || true
        exit 0
    else
        print_info "Model changes detected — regenerating config"
    fi
fi

print_info "Generating pi configuration..."

# Create header
cat > "$MASTER_CONFIG" <<'HEADER'
{
  "$schema": "https://pi.code/config.json",
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow",
    "grep": "allow",
    "glob": "allow",
    "list": "allow",
    "lsp": "allow",
    "skill": "allow",
    "task": "allow",
    "todowrite": "allow",
    "todoread": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "codesearch": "allow",
    "question": "allow",
    "mymcp_*": "ask"
  },
  "formatter": {},
  "model": "saia/$(get_profile_default_model "$PROFILE_CONFIG")",
  "provider": {
    "saia": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "SAIA (GWDG Chat AI)",
      "options": {
        "baseURL": "https://chat-ai.academiccloud.de/v1",
        "apiKey": "{env:SAIA_API_KEY}"
      },
      "models": {
HEADER

# Add models
FIRST=true
echo "$MODELS_JSON" | jq -r '.data[].id' | sort | while read -r model_id; do
    [[ -z "$model_id" ]] && continue

    # Filter models based on profile
    if ! include_in_profile "$model_id" "$PROFILE_CONFIG"; then
        continue
    fi

    cat=$(categorize "$model_id")
    desc=$(describe "$model_id" "$cat")

    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        echo "," >> "$MASTER_CONFIG"
    fi

    reason_flag=$(can_reason "$model_id")
    attach_flag=$(supports_attachment "$model_id")
    ctx=$(get_context_window "$model_id")
    out=$(get_output_window "$model_id")
    cost=$(get_cost_per_1k_tokens "$model_id")
    latency=$(get_estimated_latency_ms "$model_id")
    recommended=$(get_recommended_for "$model_id")

    # Build JSON fields
    fields="\"name\": \"$desc\""
    fields="$fields, \"options\": {\"enable-tools\": true, \"enable-auto-tool-choice\": true, \"tool-call-parser\": \"openai\"}"
    [[ "$reason_flag" == "true" ]] && fields="$fields, \"can_reason\": true"
    [[ "$attach_flag" == "true" ]] && fields="$fields, \"attachment\": true"
    fields="$fields, \"limit\": {\"context\": $ctx, \"output\": $out}"
    fields="$fields, \"metadata\": {\"cost_per_1k_tokens\": $cost, \"estimated_latency\": \"$latency\", \"recommended_for\": [$(echo "$recommended" | sed 's/,/","/g' | sed 's/^/\"/;s/$/\"/')]}"

    printf '        "%s": {%s}' "$model_id" "$fields" >> "$MASTER_CONFIG"
done

# Add model group aliases
ALIASES=(
    "best-for-coding:qwen3-coder-30b-a3b-instruct"
    "best-for-reasoning:deepseek-r1-distill-llama-70b"
    "best-for-vision:internvl3.5-30b-a3b"
    "best-for-agentic:glm-4.7"
    "best-quality:qwen3.5-397b-a17b"
    "fastest:llama-3.1-8b-instruct"
    "budget:llama-3.1-8b-instruct"
    "best-german:llama-3.1-sauerkrautlm-70b-instruct"
)

for alias_entry in "${ALIASES[@]}"; do
    alias_name="${alias_entry%%:*}"
    alias_target="${alias_entry#*:}"

    # Only include alias if the target model exists in current profile
    if echo "$MODELS_JSON" | jq -r '.data[].id' | grep -qx "$alias_target"; then
        if include_in_profile "$alias_target" "$PROFILE_CONFIG" 2>/dev/null; then
            echo "," >> "$MASTER_CONFIG"
            alias_desc="Alias for $alias_target"
            printf '        "%s": {"name": "%s", "alias": true, "options": {"enable-tools": true, "enable-auto-tool-choice": true, "tool-call-parser": "openai"}}' "$alias_name" "$alias_desc" >> "$MASTER_CONFIG"
        fi
    fi
done

# Close the saia provider section
cat >> "$MASTER_CONFIG" <<'SAIA_CLOSE'
      }
    }
SAIA_CLOSE

# Close the provider and root
cat >> "$MASTER_CONFIG" <<'ROOT_CLOSE'
  }
}
ROOT_CLOSE

# Add last_updated timestamp
LAST_UPDATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg lu "$LAST_UPDATED" '. + {last_updated: $lu}' "$MASTER_CONFIG" > "${MASTER_CONFIG}.tmp" && mv "${MASTER_CONFIG}.tmp" "$MASTER_CONFIG"
print_info "last_updated: $LAST_UPDATED"

if [[ "$USE_PROXY" == "true" ]]; then
    sed -i "s|https://chat-ai.academiccloud.de/v1|${LITELLM_PROXY_URL}|g" "$MASTER_CONFIG"
    print_info "Configured to use LiteLLM proxy: $LITELLM_PROXY_URL"
fi

# Validate JSON
if ! jq '.' "$MASTER_CONFIG" >/dev/null 2>&1; then
    print_error "Generated JSON is invalid - aborting"
    print_info "Why this happened: The model data or script output produced malformed JSON"
    rm -f "$MASTER_CONFIG"
    exit 1
fi

ELAPSED=$(echo "scale=2; ($(date +%s%N) - $TIMING_START) / 1000000000" | bc 2>/dev/null || echo "0")
print_info "Master configuration updated: $MASTER_CONFIG ($MODEL_COUNT models)"
print_info "Config generation completed in ${ELAPSED}s"

# Copy to current directory as pi.json for pi
cp "$MASTER_CONFIG" ./pi.json
print_info "Copied pi.json to current directory"
print_info "SAIA models are now available for pi — restart pi to load them."
