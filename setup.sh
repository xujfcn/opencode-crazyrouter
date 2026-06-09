#!/usr/bin/env bash
# OpenCode × Crazyrouter one-click setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/xujfcn/opencode-crazyrouter/main/setup.sh | bash
#
# Non-interactive:
#   CRAZYROUTER_API_KEY=sk-xxx bash setup.sh --yes --model claude-sonnet-4.6

set -euo pipefail

ROOT_URL="${CRAZYROUTER_ROOT_URL:-https://cn.crazyrouter.com}"
BASE_URL="${CRAZYROUTER_BASE_URL:-${ROOT_URL%/}/v1}"
CONFIG_FILE="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
PROVIDER_ID="${OPENCODE_CRAZYROUTER_PROVIDER_ID:-crazyrouter}"
MODEL="${OPENCODE_CRAZYROUTER_MODEL:-claude-sonnet-4.6}"
SMALL_MODEL="${OPENCODE_CRAZYROUTER_SMALL_MODEL:-deepseek-v4-flash}"
API_KEY="${CRAZYROUTER_API_KEY:-}"
YES=false
SKIP_TEST=false
SET_DEFAULT=true

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m'

usage() {
  cat <<'USAGE'
OpenCode × Crazyrouter setup

Usage:
  setup.sh [options]

Options:
  --api-key KEY          Crazyrouter API key. Or set CRAZYROUTER_API_KEY.
  --model MODEL          Main OpenCode model. Default: claude-sonnet-4.6
  --small-model MODEL    Small model. Default: deepseek-v4-flash
  --root-url URL         Crazyrouter root URL. Default: https://cn.crazyrouter.com
  --base-url URL         OpenAI-compatible URL. Default: <root-url>/v1
  --config PATH          OpenCode config path. Default: ~/.config/opencode/opencode.json
  --provider-id ID       Provider ID in OpenCode. Default: crazyrouter
  --no-default           Add provider but do not set global model/small_model.
  --skip-test            Skip Crazyrouter API test.
  --yes, -y              Non-interactive mode.
  -h, --help             Show help.

Examples:
  curl -fsSL https://raw.githubusercontent.com/xujfcn/opencode-crazyrouter/main/setup.sh | bash

  CRAZYROUTER_API_KEY=sk-your-key \
    bash <(curl -fsSL https://raw.githubusercontent.com/xujfcn/opencode-crazyrouter/main/setup.sh) \
    --yes --model claude-sonnet-4.6

Notes:
  OpenCode custom OpenAI-compatible providers need a /v1 baseURL.
  This script uses https://cn.crazyrouter.com as the root endpoint and writes
  https://cn.crazyrouter.com/v1 to OpenCode provider.options.baseURL.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key) API_KEY="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --small-model) SMALL_MODEL="${2:-}"; shift 2 ;;
    --root-url) ROOT_URL="${2:-}"; BASE_URL="${ROOT_URL%/}/v1"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --config) CONFIG_FILE="${2:-}"; shift 2 ;;
    --provider-id) PROVIDER_ID="${2:-}"; shift 2 ;;
    --no-default) SET_DEFAULT=false; shift ;;
    --skip-test) SKIP_TEST=true; shift ;;
    --yes|-y) YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo -e "${RED}[!] Unknown option: $1${NC}" >&2; usage; exit 1 ;;
  esac
done

ROOT_URL="${ROOT_URL%/}"
BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" != */v1 ]]; then
  BASE_URL="${BASE_URL}/v1"
fi

log() { echo -e "  ${CYAN}→${NC} $*"; }
ok() { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*" >&2; }

can_prompt() { [[ -r /dev/tty && -w /dev/tty ]]; }
read_prompt() {
  local prompt="$1" var="$2" value=""
  if can_prompt; then
    read -r -p "$prompt" value </dev/tty
  else
    read -r -p "$prompt" value
  fi
  printf -v "$var" '%s' "$value"
}

print_banner() {
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║      OpenCode × Crazyrouter Setup            ║${NC}"
  echo -e "${CYAN}  ║      https://cn.crazyrouter.com              ║${NC}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

choose_model() {
  if [[ "$YES" == true || (! -t 0 && ! -r /dev/tty) ]]; then
    return 0
  fi
  echo ""
  echo "  Choose your default OpenCode model:"
  echo -e "  ${GRAY}1) claude-sonnet-4.6    Balanced coding default${NC}"
  echo -e "  ${GRAY}2) claude-opus-4-8      Strongest reasoning${NC}"
  echo -e "  ${GRAY}3) gpt-5.5              OpenAI flagship${NC}"
  echo -e "  ${GRAY}4) deepseek-v4-flash    Fast and low-cost${NC}"
  echo -e "  ${GRAY}5) qwen3-coder          Coding model${NC}"
  echo -e "  ${GRAY}6) Custom${NC}"
  echo ""
  local choice=""
  read_prompt "  Choice [1]: " choice
  case "${choice:-1}" in
    1) MODEL="claude-sonnet-4.6" ;;
    2) MODEL="claude-opus-4-8" ;;
    3) MODEL="gpt-5.5" ;;
    4) MODEL="deepseek-v4-flash" ;;
    5) MODEL="qwen3-coder" ;;
    6) read_prompt "  Enter model id: " MODEL ;;
    *) MODEL="claude-sonnet-4.6" ;;
  esac
}

prompt_api_key() {
  if [[ -n "$API_KEY" ]]; then
    ok "Using API key from CRAZYROUTER_API_KEY/--api-key"
    return 0
  fi
  if [[ "$YES" == true || (! -t 0 && ! -r /dev/tty) ]]; then
    fail "API key is required. Set CRAZYROUTER_API_KEY or pass --api-key."
    exit 1
  fi
  echo -e "  ${NC}Enter your Crazyrouter API Key${NC}"
  echo -e "  ${GRAY}Get one at: https://cn.crazyrouter.com${NC}"
  read_prompt "  API Key: " API_KEY
  if [[ -z "$API_KEY" ]]; then
    fail "API key cannot be empty."
    exit 1
  fi
}

check_tools() {
  command -v python3 >/dev/null 2>&1 || { fail "python3 is required"; exit 1; }
  command -v curl >/dev/null 2>&1 || warn "curl not found; API test will be skipped"
  if command -v opencode >/dev/null 2>&1; then
    ok "OpenCode found: $(command -v opencode)"
  else
    warn "OpenCode command not found. Config will still be written. Install OpenCode, then run opencode."
  fi
}

write_config() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    ok "Backed up existing config"
  fi

  CONFIG_FILE="$CONFIG_FILE" \
  PROVIDER_ID="$PROVIDER_ID" \
  BASE_URL="$BASE_URL" \
  API_KEY="$API_KEY" \
  MODEL="$MODEL" \
  SMALL_MODEL="$SMALL_MODEL" \
  SET_DEFAULT="$SET_DEFAULT" \
  python3 - <<'PY'
import json, os
from pathlib import Path

path = Path(os.environ['CONFIG_FILE']).expanduser()
provider_id = os.environ['PROVIDER_ID']
base_url = os.environ['BASE_URL']
api_key = os.environ['API_KEY']
model = os.environ['MODEL']
small_model = os.environ['SMALL_MODEL']
set_default = os.environ['SET_DEFAULT'] == 'true'

if path.exists() and path.read_text().strip():
    try:
        data = json.loads(path.read_text())
    except Exception as exc:
        raise SystemExit(f'Existing config is not valid JSON. Please fix it or move it aside: {path}\n{exc}')
else:
    data = {}

if not isinstance(data, dict):
    raise SystemExit(f'Existing config must be a JSON object: {path}')

data.setdefault('$schema', 'https://opencode.ai/config.json')
providers = data.setdefault('provider', {})
providers[provider_id] = {
    'npm': '@ai-sdk/openai-compatible',
    'name': 'Crazyrouter',
    'options': {
        'baseURL': base_url,
        'apiKey': api_key,
        'timeout': 600000,
        'chunkTimeout': 30000
    },
    'models': {
        'claude-sonnet-4.6': {'name': 'Claude Sonnet 4.6'},
        'claude-opus-4-8': {'name': 'Claude Opus 4.8'},
        'gpt-5.5': {'name': 'GPT-5.5'},
        'gpt-4o': {'name': 'GPT-4o'},
        'deepseek-v4-flash': {'name': 'DeepSeek V4 Flash'},
        'qwen3-coder': {'name': 'Qwen3 Coder'},
        model: {'name': model}
    }
}
if set_default:
    data['model'] = f'{provider_id}/{model}'
    data['small_model'] = f'{provider_id}/{small_model}'

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
  chmod 600 "$CONFIG_FILE"
  ok "OpenCode config written: $CONFIG_FILE"
}

verify_config() {
  CONFIG_FILE="$CONFIG_FILE" PROVIDER_ID="$PROVIDER_ID" BASE_URL="$BASE_URL" MODEL="$MODEL" SET_DEFAULT="$SET_DEFAULT" python3 - <<'PY'
import json, os, sys
from pathlib import Path
path = Path(os.environ['CONFIG_FILE']).expanduser()
provider_id = os.environ['PROVIDER_ID']
base_url = os.environ['BASE_URL']
model = os.environ['MODEL']
set_default = os.environ['SET_DEFAULT'] == 'true'
data = json.loads(path.read_text())
provider = data.get('provider', {}).get(provider_id)
assert provider, 'provider block missing'
assert provider.get('npm') == '@ai-sdk/openai-compatible', 'wrong npm adapter'
assert provider.get('options', {}).get('baseURL') == base_url, 'wrong baseURL'
assert provider.get('options', {}).get('apiKey'), 'apiKey missing'
assert model in provider.get('models', {}), 'selected model missing'
if set_default:
    assert data.get('model') == f'{provider_id}/{model}', 'default model not set'
print('config verification ok')
PY
  ok "Config verification passed"
}

test_api() {
  if [[ "$SKIP_TEST" == true ]]; then
    warn "Skipping API test"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipping API test"
    return 0
  fi
  log "Testing Crazyrouter endpoint: $BASE_URL/models"
  local code
  code=$(curl -sS -o /tmp/opencode-crazyrouter-models.json -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "$BASE_URL/models" || true)
  if [[ "$code" == "200" ]]; then
    ok "Crazyrouter API test passed"
  else
    warn "Crazyrouter API test failed (HTTP $code). Config was written; check API key/model permissions."
    sed -n '1,5p' /tmp/opencode-crazyrouter-models.json 2>/dev/null || true
  fi
}

print_summary() {
  echo ""
  echo -e "${GREEN}  ╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}  ║              Setup Complete                  ║${NC}"
  echo -e "${GREEN}  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Provider ID : ${CYAN}$PROVIDER_ID${NC}"
  echo -e "  Root URL    : ${CYAN}$ROOT_URL${NC}"
  echo -e "  OpenCode URL: ${CYAN}$BASE_URL${NC}"
  echo -e "  Model       : ${CYAN}$PROVIDER_ID/$MODEL${NC}"
  echo -e "  Config      : ${CYAN}$CONFIG_FILE${NC}"
  echo ""
  echo "  Next steps:"
  echo -e "    ${CYAN}opencode${NC}"
  echo -e "    ${CYAN}/models${NC}  # choose Crazyrouter models if needed"
  echo ""
}

main() {
  print_banner
  check_tools
  prompt_api_key
  choose_model
  write_config
  verify_config
  test_api
  print_summary
}

main "$@"
