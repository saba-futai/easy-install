#!/bin/bash
#
# Sudoku Server One-Click Installation Script
# https://github.com/SUDOKU-ASCII/sudoku
#
# Usage:
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
# Uninstall:
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)" -- --uninstall
#
# Environment Variables:
#   SUDOKU_PORT      - Server port (default: 10233)
#   SUDOKU_CLIENT_PORT - Client local proxy port used in exported short link (default: 10233)
#   SUDOKU_FALLBACK  - Fallback address (default: 127.0.0.1:80)
#   SUDOKU_CF_FALLBACK - Enable CF 500 error page fallback service (default: true)
#   SUDOKU_CF_FALLBACK_BIND - Bind address for CF fallback service (default: 127.0.0.1)
#   SUDOKU_CF_FALLBACK_PORT - Preferred port for CF fallback service (default: 10232)
#   SUDOKU_CF_FALLBACK_FALLBACK_PORT - Port to try when preferred port fails (default: 80)
#   SUDOKU_CF_FALLBACK_FORCE - Force override SUDOKU_FALLBACK when CF fallback starts (default: false)
#   SERVER_IP        - Override public host/IP used in short link & Clash config (default: auto-detect)
#   SUDOKU_HTTP_MASK - Enable HTTP mask (default: true)
#   SUDOKU_HTTP_MASK_MODE - HTTP mask mode: auto/stream/poll/legacy/ws (default: auto)
#   SUDOKU_HTTP_MASK_TLS  - Use HTTPS in HTTP mask tunnel modes (default: false)
#   SUDOKU_HTTP_MASK_MULTIPLEX - HTTP mask mux: off/auto/on (default: on)
#   SUDOKU_HTTP_MASK_HOST - Override HTTP Host/SNI in tunnel modes (default: empty)
#   SUDOKU_HTTP_MASK_PATH_ROOT - Optional first-level path prefix for HTTP mask/tunnel endpoints (default: empty)
#

set -e

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration Defaults
# ═══════════════════════════════════════════════════════════════════════════════

SUDOKU_PORT="${SUDOKU_PORT:-10233}"
SUDOKU_CLIENT_PORT="${SUDOKU_CLIENT_PORT:-10233}"
DEFAULT_SUDOKU_FALLBACK="127.0.0.1:80"
SUDOKU_FALLBACK="${SUDOKU_FALLBACK:-${DEFAULT_SUDOKU_FALLBACK}}"
SUDOKU_REPO="${SUDOKU_REPO:-SUDOKU-ASCII/sudoku}"
SUDOKU_CF_FALLBACK="${SUDOKU_CF_FALLBACK:-true}"
SUDOKU_CF_FALLBACK_BIND="${SUDOKU_CF_FALLBACK_BIND:-127.0.0.1}"
SUDOKU_CF_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_PORT:-10232}"
SUDOKU_CF_FALLBACK_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_FALLBACK_PORT:-80}"
SUDOKU_CF_FALLBACK_FORCE="${SUDOKU_CF_FALLBACK_FORCE:-false}"
SUDOKU_CF_FALLBACK_REPO="${SUDOKU_CF_FALLBACK_REPO:-donlon/cloudflare-error-page}"
SUDOKU_CF_FALLBACK_BRANCH="${SUDOKU_CF_FALLBACK_BRANCH:-main}"
SUDOKU_HTTP_MASK="${SUDOKU_HTTP_MASK:-true}"
SUDOKU_HTTP_MASK_MODE="${SUDOKU_HTTP_MASK_MODE:-auto}"
SUDOKU_HTTP_MASK_TLS="${SUDOKU_HTTP_MASK_TLS:-false}"
SUDOKU_HTTP_MASK_MULTIPLEX="${SUDOKU_HTTP_MASK_MULTIPLEX:-on}"
SUDOKU_HTTP_MASK_HOST="${SUDOKU_HTTP_MASK_HOST:-}"
SUDOKU_HTTP_MASK_PATH_ROOT="${SUDOKU_HTTP_MASK_PATH_ROOT:-}"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sudoku"
SERVICE_NAME="sudoku"
FALLBACK_SERVICE_NAME="sudoku-fallback"
FALLBACK_LIB_DIR="/usr/local/lib/sudoku-fallback"
CUSTOM_TABLE=""
DISABLE_HTTP_MASK="false"
HTTP_MASK_MODE="auto"
HTTP_MASK_TLS="false"
HTTP_MASK_MULTIPLEX="on"
HTTP_MASK_HOST=""
HTTP_MASK_PATH_ROOT=""
CF_FALLBACK_ENABLED="true"
CF_FALLBACK_BIND="127.0.0.1"
CF_FALLBACK_PORT="10232"
CF_FALLBACK_PORT_FALLBACK="80"
CF_FALLBACK_FORCE="false"
PKG_MANAGER=""

# ═══════════════════════════════════════════════════════════════════════════════
# Color Output
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ███████╗██╗   ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██╔════╝██║   ██║██╔══██╗██╔═══██╗██║ ██╔╝██║   ██║
  ███████╗██║   ██║██║  ██║██║   ██║█████╔╝ ██║   ██║
  ╚════██║██║   ██║██║  ██║██║   ██║██╔═██╗ ██║   ██║
  ███████║╚██████╔╝██████╔╝╚██████╔╝██║  ██╗╚██████╔╝
  ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}  One-Click Server Installation Script${NC}"
    echo ""
}

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════════
# Input Normalization
# ═══════════════════════════════════════════════════════════════════════════════

normalize_bool() {
    local raw="${1:-}"
    raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    case "$raw" in
        1|true|yes|y|on) echo "true" ;;
        0|false|no|n|off) echo "false" ;;
        *) return 1 ;;
    esac
}

is_valid_port() {
    local p="${1:-}"
    [[ "${p}" =~ ^[0-9]+$ ]] || return 1
    if ((p < 1 || p > 65535)); then
        return 1
    fi
}

trim_space() {
    local s="${1:-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

normalize_settings() {
    local http_mask_enabled
    local http_mask_tls
    local cf_fallback_enabled
    local cf_fallback_force

    if ! http_mask_enabled=$(normalize_bool "${SUDOKU_HTTP_MASK}"); then
        error "Invalid SUDOKU_HTTP_MASK=${SUDOKU_HTTP_MASK} (expected true/false)"
    fi
    if ! http_mask_tls=$(normalize_bool "${SUDOKU_HTTP_MASK_TLS}"); then
        error "Invalid SUDOKU_HTTP_MASK_TLS=${SUDOKU_HTTP_MASK_TLS} (expected true/false)"
    fi
    if ! cf_fallback_enabled=$(normalize_bool "${SUDOKU_CF_FALLBACK}"); then
        error "Invalid SUDOKU_CF_FALLBACK=${SUDOKU_CF_FALLBACK} (expected true/false)"
    fi
    if ! cf_fallback_force=$(normalize_bool "${SUDOKU_CF_FALLBACK_FORCE}"); then
        error "Invalid SUDOKU_CF_FALLBACK_FORCE=${SUDOKU_CF_FALLBACK_FORCE} (expected true/false)"
    fi

    if ! is_valid_port "${SUDOKU_PORT}"; then
        error "Invalid SUDOKU_PORT=${SUDOKU_PORT} (expected 1-65535)"
    fi
    if ! is_valid_port "${SUDOKU_CLIENT_PORT}"; then
        error "Invalid SUDOKU_CLIENT_PORT=${SUDOKU_CLIENT_PORT} (expected 1-65535)"
    fi

    SUDOKU_FALLBACK=$(trim_space "${SUDOKU_FALLBACK}")
    if [[ -z "${SUDOKU_FALLBACK}" ]]; then
        error "Invalid SUDOKU_FALLBACK (expected host:port)"
    fi
    local fallback_host fallback_port
    fallback_port="${SUDOKU_FALLBACK##*:}"
    fallback_host="${SUDOKU_FALLBACK%:*}"
    if [[ -z "${fallback_host}" || -z "${fallback_port}" ]]; then
        error "Invalid SUDOKU_FALLBACK=${SUDOKU_FALLBACK} (expected host:port)"
    fi
    if ! is_valid_port "${fallback_port}"; then
        error "Invalid SUDOKU_FALLBACK=${SUDOKU_FALLBACK} (invalid port; expected 1-65535)"
    fi
    if [[ "${fallback_host}" == *:* && "${fallback_host}" != \[*\] ]]; then
        error "Invalid SUDOKU_FALLBACK=${SUDOKU_FALLBACK} (IPv6 must be in [::1]:port form)"
    fi

    HTTP_MASK_MODE=$(trim_space "${SUDOKU_HTTP_MASK_MODE}")
    HTTP_MASK_MODE=$(echo "${HTTP_MASK_MODE}" | tr '[:upper:]' '[:lower:]')
    if [[ -z "${HTTP_MASK_MODE}" ]]; then
        HTTP_MASK_MODE="auto"
    fi
    case "${HTTP_MASK_MODE}" in
        auto|stream|poll|legacy|ws) ;;
        *) error "Invalid SUDOKU_HTTP_MASK_MODE=${SUDOKU_HTTP_MASK_MODE} (expected auto/stream/poll/legacy/ws)" ;;
    esac

    HTTP_MASK_HOST=$(trim_space "${SUDOKU_HTTP_MASK_HOST}")
    HTTP_MASK_TLS="${http_mask_tls}"

    HTTP_MASK_PATH_ROOT=$(trim_space "${SUDOKU_HTTP_MASK_PATH_ROOT}")
    while [[ "${HTTP_MASK_PATH_ROOT}" == /* ]]; do
        HTTP_MASK_PATH_ROOT="${HTTP_MASK_PATH_ROOT#/}"
    done
    while [[ "${HTTP_MASK_PATH_ROOT}" == */ ]]; do
        HTTP_MASK_PATH_ROOT="${HTTP_MASK_PATH_ROOT%/}"
    done
    if [[ -n "${HTTP_MASK_PATH_ROOT}" && ! "${HTTP_MASK_PATH_ROOT}" =~ ^[A-Za-z0-9_-]+$ ]]; then
        error "Invalid SUDOKU_HTTP_MASK_PATH_ROOT=${SUDOKU_HTTP_MASK_PATH_ROOT} (expected single segment [A-Za-z0-9_-], e.g. aabbcc)"
    fi

    HTTP_MASK_MULTIPLEX=$(trim_space "${SUDOKU_HTTP_MASK_MULTIPLEX}")
    HTTP_MASK_MULTIPLEX=$(echo "${HTTP_MASK_MULTIPLEX}" | tr '[:upper:]' '[:lower:]')
    if [[ -z "${HTTP_MASK_MULTIPLEX}" ]]; then
        HTTP_MASK_MULTIPLEX="on"
    fi
    case "${HTTP_MASK_MULTIPLEX}" in
        off|auto|on) ;;
        *) error "Invalid SUDOKU_HTTP_MASK_MULTIPLEX=${SUDOKU_HTTP_MASK_MULTIPLEX} (expected off/auto/on)" ;;
    esac

    if [[ "${http_mask_enabled}" == "true" ]]; then
        DISABLE_HTTP_MASK="false"
    else
        DISABLE_HTTP_MASK="true"
    fi

    CF_FALLBACK_ENABLED="${cf_fallback_enabled}"
    CF_FALLBACK_FORCE="${cf_fallback_force}"
    CF_FALLBACK_BIND=$(trim_space "${SUDOKU_CF_FALLBACK_BIND}")
    if [[ -z "${CF_FALLBACK_BIND}" ]]; then
        CF_FALLBACK_BIND="127.0.0.1"
    fi
    CF_FALLBACK_PORT=$(trim_space "${SUDOKU_CF_FALLBACK_PORT}")
    CF_FALLBACK_PORT_FALLBACK=$(trim_space "${SUDOKU_CF_FALLBACK_FALLBACK_PORT}")
    if ! is_valid_port "${CF_FALLBACK_PORT}"; then
        error "Invalid SUDOKU_CF_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_PORT} (expected 1-65535)"
    fi
    if ! is_valid_port "${CF_FALLBACK_PORT_FALLBACK}"; then
        error "Invalid SUDOKU_CF_FALLBACK_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_FALLBACK_PORT} (expected 1-65535)"
    fi
}

join_host_port() {
    local host="${1:-}"
    local port="${2:-}"
    if [[ -z "${host}" || -z "${port}" ]]; then
        return 1
    fi
    if [[ "${host}" == *:* && "${host}" != \[*\] ]]; then
        printf '[%s]:%s' "${host}" "${port}"
    else
        printf '%s:%s' "${host}" "${port}"
    fi
}

build_http_url() {
    local host="${1:-}"
    local port="${2:-}"
    printf 'http://%s/' "$(join_host_port "${host}" "${port}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
# System Detection
# ═══════════════════════════════════════════════════════════════════════════════

detect_os() {
    if [[ "$(uname)" != "Linux" ]]; then
        error "This script only supports Linux servers."
    fi
    success "Operating system: Linux"
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            ;;
    esac
    success "Architecture: $ARCH"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    success "Running as root"
}

detect_pkg_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
    else
        PKG_MANAGER=""
        return 1
    fi
}

install_packages() {
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -z "${PKG_MANAGER}" ]]; then
        detect_pkg_manager || error "Cannot install dependencies. Please install manually: ${pkgs[*]}"
    fi

    case "${PKG_MANAGER}" in
        apt)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}"
            ;;
        yum)
            yum install -y -q "${pkgs[@]}"
            ;;
        dnf)
            dnf install -y -q "${pkgs[@]}"
            ;;
        apk)
            apk add --quiet "${pkgs[@]}"
            ;;
        *)
            error "Cannot install dependencies. Please install manually: ${pkgs[*]}"
            ;;
    esac
}

check_dependencies() {
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ "${CF_FALLBACK_ENABLED}" == "true" ]]; then
        if ! command -v python3 &> /dev/null; then
            missing+=("python3")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Installing missing dependencies: ${missing[*]}"
        install_packages "${missing[@]}"
    fi

    success "Dependencies satisfied"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cloudflare 500 Error Page Fallback (for suspicious traffic fallback)
# ═══════════════════════════════════════════════════════════════════════════════

should_override_fallback_address() {
    if [[ "${CF_FALLBACK_FORCE}" == "true" ]]; then
        return 0
    fi
    [[ "${SUDOKU_FALLBACK}" == "${DEFAULT_SUDOKU_FALLBACK}" ]]
}

ensure_cf_fallback_pydeps() {
    mkdir -p "${FALLBACK_LIB_DIR}/pydeps"

    if python3 -c 'import flask, jinja2' >/dev/null 2>&1; then
        return 0
    fi

    if ! python3 -m pip --version >/dev/null 2>&1; then
        info "Installing pip (required for CF fallback Python deps)..."
        if detect_pkg_manager; then
            case "${PKG_MANAGER}" in
                apt|yum|dnf) install_packages python3-pip ;;
                apk) install_packages py3-pip ;;
                *) ;;
            esac
        fi
    fi

    if ! python3 -m pip --version >/dev/null 2>&1; then
        python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi
    if ! python3 -m pip --version >/dev/null 2>&1; then
        return 1
    fi

    info "Installing CF fallback Python deps (Flask + Jinja2)..."
    if ! PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore \
        python3 -m pip install --no-cache-dir --upgrade --target "${FALLBACK_LIB_DIR}/pydeps" Flask Jinja2; then
        return 1
    fi

    python3 -c "import sys; sys.path.insert(0, '${FALLBACK_LIB_DIR}/pydeps'); import flask, jinja2" >/dev/null 2>&1
}

write_cf_fallback_server() {
    mkdir -p "${FALLBACK_LIB_DIR}"

    cat > "${FALLBACK_LIB_DIR}/server.py" << 'PY'
import argparse
import html
import json
import secrets
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


# This page is based on the MIT-licensed project:
# https://github.com/donlon/cloudflare-error-page
#
# We render a 1:1 Cloudflare-style error page without external runtime deps (no pip).

CF_MAIN_CSS = r""".container{width:100%}.bg-white{--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity))}.bg-center{background-position:50%}.bg-no-repeat{background-repeat:no-repeat}.border-gray-300{--border-opacity:1;border-color:#ebebeb;border-color:rgba(235,235,235,var(--border-opacity))}.rounded{border-radius:.25rem}.border-solid{border-style:solid}.border-0{border-width:0}.border{border-width:1px}.border-t{border-top-width:1px}.cursor-pointer{cursor:pointer}.block{display:block}.inline-block{display:inline-block}.table{display:table}.hidden{display:none}.float-left{float:left}.clearfix:after{content:"";display:table;clear:both}.font-mono{font-family:monaco,courier,monospace}.font-light{font-weight:300}.font-normal{font-weight:400}.font-semibold{font-weight:600}.h-12{height:3rem}.h-20{height:5rem}.text-13{font-size:13px}.text-15{font-size:15px}.text-60{font-size:60px}.text-2xl{font-size:1.5rem}.text-3xl{font-size:1.875rem}.leading-tight{line-height:1.25}.leading-normal{line-height:1.5}.leading-relaxed{line-height:1.625}.leading-1\.3{line-height:1.3}.my-8{margin-top:2rem;margin-bottom:2rem}.mx-auto{margin-left:auto;margin-right:auto}.mr-2{margin-right:.5rem}.mb-2{margin-bottom:.5rem}.mt-3{margin-top:.75rem}.mb-4{margin-bottom:1rem}.ml-4{margin-left:1rem}.mt-6{margin-top:1.5rem}.mb-6{margin-bottom:1.5rem}.mb-8{margin-bottom:2rem}.mb-10{margin-bottom:2.5rem}.ml-10{margin-left:2.5rem}.mb-15{margin-bottom:3.75rem}.-ml-6{margin-left:-1.5rem}.overflow-hidden{overflow:hidden}.p-0{padding:0}.py-2{padding-top:.5rem;padding-bottom:.5rem}.px-4{padding-left:1rem;padding-right:1rem}.py-8{padding-top:2rem;padding-bottom:2rem}.py-10{padding-top:2.5rem;padding-bottom:2.5rem}.py-15{padding-top:3.75rem;padding-bottom:3.75rem}.pr-6{padding-right:1.5rem}.pt-10{padding-top:2.5rem}.absolute{position:absolute}.relative{position:relative}.left-1\/2{left:50%}.-bottom-4{bottom:-1rem}.resize{resize:both}.text-center{text-align:center}.text-black-dark{--text-opacity:1;color:#404040;color:rgba(64,64,64,var(--text-opacity))}.text-gray-600{--text-opacity:1;color:#999;color:rgba(153,153,153,var(--text-opacity))}.text-red-error{--text-opacity:1;color:#bd2426;color:rgba(189,36,38,var(--text-opacity))}.text-green-success{--text-opacity:1;color:#9bca3e;color:rgba(155,202,62,var(--text-opacity))}.antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.w-12{width:3rem}.w-240{width:60rem}.w-1\/2{width:50%}.w-1\/3{width:33.333333%}.w-full{width:100%}.transition{-webkit-transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,-webkit-transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,-webkit-transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,transform,-webkit-transform}body,html{--text-opacity:1;color:#404040;color:rgba(64,64,64,var(--text-opacity));-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;font-size:16px}*,body,html{margin:0;padding:0}*{box-sizing:border-box}a{--text-opacity:1;color:#2f7bbf;color:rgba(47,123,191,var(--text-opacity));text-decoration:none;-webkit-transition-property:all;transition-property:all;-webkit-transition-duration:.15s;transition-duration:.15s;-webkit-transition-timing-function:cubic-bezier(0,0,.2,1);transition-timing-function:cubic-bezier(0,0,.2,1)}a:hover{--text-opacity:1;color:#f68b1f;color:rgba(246,139,31,var(--text-opacity))}img{display:block;width:100%;height:auto}#what-happened-section p{font-size:15px;line-height:1.5}strong{font-weight:600}.bg-gradient-gray{background-image:-webkit-linear-gradient(top,#dedede,#ebebeb 3%,#ebebeb 97%,#dedede)}.cf-error-source:after{position:absolute;--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity));width:2.5rem;height:2.5rem;--transform-translate-x:0;--transform-translate-y:0;--transform-rotate:0;--transform-skew-x:0;--transform-skew-y:0;--transform-scale-x:1;--transform-scale-y:1;-webkit-transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));-ms-transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));--transform-rotate:45deg;content:"";bottom:-1.75rem;left:50%;margin-left:-1.25rem;box-shadow:0 0 4px 4px #dedede}@media screen and (max-width:720px){.cf-error-source:after{display:none}}.cf-icon-browser{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%20100%2080.7362%22%3E%3Cpath%20d%3D%22M89.8358.1636H10.1642C4.6398.1636.1614%2C4.6421.1614%2C10.1664v60.4033c0%2C5.5244%2C4.4784%2C10.0028%2C10.0028%2C10.0028h79.6716c5.5244%2C0%2C10.0027-4.4784%2C10.0027-10.0028V10.1664c0-5.5244-4.4784-10.0028-10.0027-10.0028ZM22.8323%2C9.6103c1.9618%2C0%2C3.5522%2C1.5903%2C3.5522%2C3.5521s-1.5904%2C3.5522-3.5522%2C3.5522-3.5521-1.5904-3.5521-3.5522%2C1.5903-3.5521%2C3.5521-3.5521ZM12.8936%2C9.6103c1.9618%2C0%2C3.5522%2C1.5903%2C3.5522%2C3.5521s-1.5904%2C3.5522-3.5522%2C3.5522-3.5521-1.5904-3.5521-3.5522%2C1.5903-3.5521%2C3.5521-3.5521ZM89.8293%2C70.137H9.7312V24.1983h80.0981v45.9387ZM89.8293%2C16.1619H29.8524v-5.999h59.977v5.999Z%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-cloud{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%20152%2078.9141%22%3E%3Cpath%20d%3D%22M132.2996%2C77.9927v-.0261c10.5477-.2357%2C19.0305-8.8754%2C19.0305-19.52%2C0-10.7928-8.7161-19.5422-19.4678-19.5422-2.9027%2C0-5.6471.6553-8.1216%2C1.7987C123.3261%2C18.6624%2C105.3419.9198%2C83.202.9198c-17.8255%2C0-32.9539%2C11.5047-38.3939%2C27.4899-3.0292-2.2755-6.7818-3.6403-10.8622-3.6403-10.0098%2C0-18.1243%2C8.1145-18.1243%2C18.1243%2C0%2C1.7331.258%2C3.4033.7122%2C4.9905-.2899-.0168-.5769-.0442-.871-.0442-8.2805%2C0-14.993%2C6.7503-14.993%2C15.0772%2C0%2C8.2795%2C6.6381%2C14.994%2C14.8536%2C15.0701v.0054h.1069c.0109%2C0%2C.0215.0016.0325.0016s.0215-.0016.0325-.0016%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-server{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2095%2075%22%3E%3Cpath%20d%3D%22M94.0103%2C45.0775l-12.9885-38.4986c-1.2828-3.8024-4.8488-6.3624-8.8618-6.3619l-49.91.0065c-3.9995.0005-7.556%2C2.5446-8.8483%2C6.3295L1.0128%2C42.8363c-.3315.971-.501%2C1.9899-.5016%2C3.0159l-.0121%2C19.5737c-.0032%2C5.1667%2C4.1844%2C9.3569%2C9.3513%2C9.3569h75.2994c5.1646%2C0%2C9.3512-4.1866%2C9.3512-9.3512v-17.3649c0-1.0165-.1657-2.0262-.4907-2.9893ZM86.7988%2C65.3097c0%2C1.2909-1.0465%2C2.3374-2.3374%2C2.3374H9.9767c-1.2909%2C0-2.3374-1.0465-2.3374-2.3374v-18.1288c0-1.2909%2C1.0465-2.3374%2C2.3374-2.3374h74.4847c1.2909%2C0%2C2.3374%2C1.0465%2C2.3374%2C2.3374v18.1288Z%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3Ccircle%20cx%3D%2274.6349%22%20cy%3D%2256.1889%22%20r%3D%224.7318%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3Ccircle%20cx%3D%2259.1472%22%20cy%3D%2256.1889%22%20r%3D%224.7318%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-ok{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2048%2048%22%3E%3Ccircle%20cx%3D%2224%22%20cy%3D%2224%22%20r%3D%2223.4815%22%20style%3D%22fill%3A%20%239bca3e%3B%22/%3E%3Cpolyline%20points%3D%2217.453%2024.9841%2021.7183%2030.4504%2030.2076%2016.8537%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%204px%3B%22/%3E%3C/svg%3E)}.cf-icon-error{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2047.9145%2047.9641%22%3E%3Ccircle%20cx%3D%2223.9572%22%20cy%3D%2223.982%22%20r%3D%2223.4815%22%20style%3D%22fill%3A%20%23bd2426%3B%22/%3E%3Cline%20x1%3D%2219.0487%22%20y1%3D%2219.0768%22%20x2%3D%2227.8154%22%20y2%3D%2228.8853%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%203px%3B%22/%3E%3Cline%20x1%3D%2227.8154%22%20y1%3D%2219.0768%22%20x2%3D%2219.0487%22%20y2%3D%2228.8853%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%203px%3B%22/%3E%3C/svg%3E)}#cf-wrapper .feedback-hidden{display:none}#cf-wrapper .feedback-success{min-height:33px;line-height:33px}#cf-wrapper .cf-button{color:#0051c3;font-size:13px;border-color:#0045a6;-webkit-transition-timing-function:ease;transition-timing-function:ease;-webkit-transition-duration:.2s;transition-duration:.2s;-webkit-transition-property:background-color,border-color,color;transition-property:background-color,border-color,color}#cf-wrapper .cf-button:hover{color:#fff;background-color:#003681}.cf-error-footer .hidden{display:none}.cf-error-footer .cf-footer-ip-reveal-btn{-webkit-appearance:button;-moz-appearance:button;appearance:button;text-decoration:none;background:none;color:inherit;border:none;padding:0;font:inherit;cursor:pointer;color:#0051c3;-webkit-transition:color .15s ease;transition:color .15s ease}.cf-error-footer .cf-footer-ip-reveal-btn:hover{color:#ee730a}.code-label{background-color:#d9d9d9;color:#313131;font-weight:500;border-radius:1.25rem;font-size:.75rem;line-height:4.5rem;padding:.25rem .5rem;height:4.5rem;white-space:nowrap;vertical-align:middle}@media (max-width:639px){.sm\:block{display:block}.sm\:hidden{display:none}.sm\:mb-1{margin-bottom:.25rem}.sm\:mb-2{margin-bottom:.5rem}.sm\:py-4{padding-top:1rem;padding-bottom:1rem}.sm\:px-8{padding-left:2rem;padding-right:2rem}.sm\:text-left{text-align:left}}@media (max-width:720px){.md\:border-gray-400{--border-opacity:1;border-color:#dedede;border-color:rgba(222,222,222,var(--border-opacity))}.md\:border-solid{border-style:solid}.md\:border-0{border-width:0}.md\:border-b{border-bottom-width:1px}.md\:block{display:block}.md\:inline-block{display:inline-block}.md\:hidden{display:none}.md\:float-none{float:none}.md\:text-3xl{font-size:1.875rem}.md\:m-0{margin:0}.md\:mt-0{margin-top:0}.md\:mb-2{margin-bottom:.5rem}.md\:p-0{padding:0}.md\:py-8{padding-top:2rem;padding-bottom:2rem}.md\:px-8{padding-left:2rem;padding-right:2rem}.md\:pr-0{padding-right:0}.md\:pb-10{padding-bottom:2.5rem}.md\:top-0{top:0}.md\:right-0{right:0}.md\:left-auto{left:auto}.md\:text-left{text-align:left}.md\:w-full{width:100%}}@media (max-width:1023px){.lg\:text-sm{font-size:.875rem}.lg\:text-2xl{font-size:1.5rem}.lg\:text-4xl{font-size:2.25rem}.lg\:leading-relaxed{line-height:1.625}.lg\:px-8{padding-left:2rem;padding-right:2rem}.lg\:pt-6{padding-top:1.5rem}.lg\:w-full{width:100%}}"""

DEFAULT_WHAT_HAPPENED = "<p>There is an internal server error on Cloudflare's network.</p>"
DEFAULT_WHAT_CAN_I_DO = "<p>Please try again in a few minutes.</p>"


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def _esc(x: object) -> str:
    return html.escape("" if x is None else str(x), quote=True)


def _as_dict(v: object) -> dict:
    return v if isinstance(v, dict) else {}


def _host_only(host: str) -> str:
    host = (host or "").strip()
    if not host:
        return host
    # Drop port for display (best effort).
    if host.startswith("["):
        # [::1]:443
        if "]:" in host:
            return host[1 : host.index("]:")]
        return host.strip("[]")
    if ":" in host:
        return host.split(":", 1)[0]
    return host


def _normalize_params(base: dict, *, ray_id: str, client_ip: str, host_header: str) -> dict:
    params = dict(base or {})

    more_info = _as_dict(params.get("more_information"))
    if "for_text" in more_info and "for" not in more_info:
        more_info = dict(more_info)
        more_info["for"] = more_info.get("for_text")
        params["more_information"] = more_info

    if not params.get("time"):
        params["time"] = _now_utc()
    if not params.get("ray_id"):
        params["ray_id"] = (ray_id or "").strip() or secrets.token_hex(8)
    if not params.get("client_ip"):
        params["client_ip"] = (client_ip or "").strip()

    # If host_status.location is empty, use request Host header.
    host_status = _as_dict(params.get("host_status"))
    if host_status.get("location") in ("", None):
        host_status = dict(host_status)
        host_status["location"] = _host_only(host_header)
        params["host_status"] = host_status

    return params


def _render_status_item(params: dict, item_id: str) -> str:
    if item_id == "browser":
        icon = "browser"
        default_location = "You"
        default_name = "Browser"
    elif item_id == "cloudflare":
        icon = "cloud"
        default_location = "San Francisco"
        default_name = "Cloudflare"
    else:
        icon = "server"
        default_location = "Website"
        default_name = "Host"

    item = dict(_as_dict(params.get(f"{item_id}_status")))
    status = (item.get("status") or "ok").strip()

    if item.get("status_text_color"):
        text_color = str(item.get("status_text_color"))
    elif status == "ok":
        text_color = "#9bca3e"  # text-green-success
    else:
        text_color = "#bd2426"  # text-red-error

    status_text = item.get("status_text")
    if not status_text:
        status_text = "Working" if status == "ok" else "Error"

    location = item.get("location") or default_location
    name = item.get("name") or default_name

    is_error_source = (params.get("error_source") or "") == item_id
    klass = (
        ("cf-error-source " if is_error_source else "")
        + "relative w-1/3 md:w-full py-15 md:p-0 md:py-8 md:text-left md:border-solid md:border-0 md:border-b md:border-gray-400 overflow-hidden float-left md:float-none text-center"
    )
    name_style = 'style="color: #2f7bbf;"' if name == "Cloudflare" else ""

    return (
        f'                    <div id="cf-{item_id}-status" class="{klass}">\n'
        f'                        <div class="relative mb-10 md:m-0">\n'
        f'                            <span class="cf-icon-{icon} block md:hidden h-20 bg-center bg-no-repeat"></span>\n'
        f'                            <span class="cf-icon-{_esc(status)} w-12 h-12 absolute left-1/2 md:left-auto md:right-0 md:top-0 -ml-6 -bottom-4"></span>\n'
        f"                        </div>\n"
        f'                        <span class="md:block w-full truncate">{_esc(location)}</span>\n'
        f'                        <h3 class="md:inline-block mt-3 md:mt-0 text-2xl text-gray-600 font-light leading-1.3" {name_style}>{_esc(name)}</h3>\n'
        f'                        <span class="leading-1.3 text-2xl" style="color: {html.escape(text_color, quote=True)}">{_esc(status_text)}</span>\n'
        f"                    </div>\n"
    )


def render_cloudflare_error_page(params: dict) -> bytes:
    error_code = params.get("error_code") or 500
    title = params.get("title") or "Internal server error"
    html_title = params.get("html_title") or f"{error_code}: {title}"

    more_info = _as_dict(params.get("more_information"))
    more_hidden = bool(more_info.get("hidden") or False) if isinstance(more_info, dict) else False
    more_link = more_info.get("link") or "https://www.cloudflare.com/"
    more_text = more_info.get("text") or "cloudflare.com"
    more_for = more_info.get("for") or more_info.get("for_text") or "more information"

    perf_sec_by = _as_dict(params.get("perf_sec_by"))
    perf_text = perf_sec_by.get("text") or "Cloudflare"
    perf_link = perf_sec_by.get("link") or "https://www.cloudflare.com/"

    creator_info = _as_dict(params.get("creator_info"))
    creator_hidden = creator_info.get("hidden", True)
    creator_text = creator_info.get("text") or ""
    creator_link = creator_info.get("link") or ""

    what_happened = params.get("what_happened") or DEFAULT_WHAT_HAPPENED
    what_can_i_do = params.get("what_can_i_do") or DEFAULT_WHAT_CAN_I_DO

    style = params.get("html_style") or CF_MAIN_CSS

    parts: list[str] = []
    parts.append("<!DOCTYPE html>")
    parts.append('<!--[if lt IE 7]> <html class="no-js ie6 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if IE 7]>    <html class="no-js ie7 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if IE 8]>    <html class="no-js ie8 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if gt IE 8]><!--> <html class="no-js" lang="en-US"> <!--<![endif]-->')
    parts.append("<head>")
    parts.append(f"<title>{_esc(html_title)}</title>")
    parts.append('<meta charset="UTF-8" />')
    parts.append('<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />')
    parts.append('<meta http-equiv="X-UA-Compatible" content="IE=Edge" />')
    parts.append('<meta name="robots" content="noindex, nofollow" />')
    parts.append('<meta name="viewport" content="width=device-width,initial-scale=1" />')
    parts.append("<style>")
    parts.append(str(style))
    parts.append("</style>")
    parts.append("</head>")
    parts.append("<body>")
    parts.append('<div id="cf-wrapper">')
    parts.append('    <div id="cf-error-details" class="p-0">')
    parts.append('        <header class="mx-auto pt-10 lg:pt-6 lg:px-8 w-240 lg:w-full mb-8">')
    parts.append('            <h1 class="inline-block sm:block sm:mb-2 font-light text-60 lg:text-4xl text-black-dark leading-tight mr-2">')
    parts.append(f'                <span class="inline-block">{_esc(title)}</span>')
    parts.append(f'                <span class="code-label">Error code {_esc(error_code)}</span>')
    parts.append("            </h1>")
    if not more_hidden:
        parts.append("            <div>")
        parts.append(
            f'                Visit <a href="{_esc(more_link)}" target="_blank" rel="noopener noreferrer">{_esc(more_text)}</a> for {_esc(more_for)}.'
        )
        parts.append("            </div>")
    parts.append(f'            <div class="mt-3">{_esc(params.get("time"))}</div>')
    parts.append("        </header>")
    parts.append('        <div class="my-8 bg-gradient-gray">')
    parts.append('          <div class="w-240 lg:w-full mx-auto">')
    parts.append('                <div class="clearfix md:px-8">')
    parts.append(_render_status_item(params, "browser").rstrip("\n"))
    parts.append(_render_status_item(params, "cloudflare").rstrip("\n"))
    parts.append(_render_status_item(params, "host").rstrip("\n"))
    parts.append("                </div>")
    parts.append("            </div>")
    parts.append("        </div>")
    parts.append("")
    parts.append('        <div class="w-240 lg:w-full mx-auto mb-8 lg:px-8">')
    parts.append('            <div class="clearfix">')
    parts.append('                <div class="w-1/2 md:w-full float-left pr-6 md:pb-10 md:pr-0 leading-relaxed">')
    parts.append('                    <h2 class="text-3xl font-normal leading-1.3 mb-4">What happened?</h2>')
    parts.append(f"                    {what_happened}")
    parts.append("                </div>")
    parts.append('                <div class="w-1/2 md:w-full float-left leading-relaxed">')
    parts.append('                    <h2 class="text-3xl font-normal leading-1.3 mb-4">What can I do?</h2>')
    parts.append(f"                    {what_can_i_do}")
    parts.append("                </div>")
    parts.append("            </div>")
    parts.append("        </div>")
    parts.append("")
    parts.append(
        '        <div class="cf-error-footer cf-wrapper w-240 lg:w-full py-10 sm:py-4 sm:px-8 mx-auto text-center sm:text-left border-solid border-0 border-t border-gray-300">'
    )
    parts.append('            <p class="text-13">')
    parts.append(
        f'                <span class="cf-footer-item sm:block sm:mb-1">Ray ID: <strong class="font-semibold">{_esc(params.get("ray_id"))}</strong></span>'
    )
    parts.append('                <span class="cf-footer-separator sm:hidden">&bull;</span>')
    parts.append('                <span id="cf-footer-item-ip" class="cf-footer-item hidden sm:block sm:mb-1">')
    parts.append("                    Your IP:")
    parts.append('                    <button type="button" id="cf-footer-ip-reveal" class="cf-footer-ip-reveal-btn">Click to reveal</button>')
    parts.append(f'                    <span class="hidden" id="cf-footer-ip">{_esc(params.get("client_ip") or "1.1.1.1")}</span>')
    parts.append('                    <span class="cf-footer-separator sm:hidden">&bull;</span>')
    parts.append("                </span>")
    parts.append(
        f'                <span class="cf-footer-item sm:block sm:mb-1"><span>Performance &amp; security by</span> <a rel="noopener noreferrer" href="{_esc(perf_link)}" id="brand_link" target="_blank">{_esc(perf_text)}</a></span>'
    )
    if not bool(creator_hidden):
        parts.append('                <span class="cf-footer-separator sm:hidden">&bull;</span>')
        parts.append(
            f'                <span class="cf-footer-item sm:block sm:mb-1">Created with <a href="{_esc(creator_link)}" target="_blank">{_esc(creator_text)}</a></span>'
        )
    parts.append("            </p>")
    parts.append("        </div><!-- /.error-footer -->")
    parts.append("    </div>")
    parts.append("</div>")
    parts.append(
        '<script>(function(){function d(){var b=a.getElementById("cf-footer-item-ip"),c=a.getElementById("cf-footer-ip-reveal");b&&"classList"in b&&(b.classList.remove("hidden"),c.addEventListener("click",function(){c.classList.add("hidden");a.getElementById("cf-footer-ip").classList.remove("hidden")}))}var a=document;document.addEventListener&&a.addEventListener("DOMContentLoaded",d)})();</script>'
    )
    parts.append("</body>")
    parts.append("</html>")

    return ("\n".join(parts) + "\n").encode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=10232)
    parser.add_argument("--params", required=True)
    args = parser.parse_args()

    base_params = {}
    try:
        with open(args.params, "r", encoding="utf-8") as f:
            base_params = json.load(f) or {}
    except Exception:
        base_params = {}

    class Handler(BaseHTTPRequestHandler):
        server_version = "cloudflare"
        sys_version = ""

        def _client_ip(self) -> str:
            xff = (self.headers.get("X-Forwarded-For") or "").strip()
            if xff:
                return xff.split(",")[0].strip()
            return (self.client_address[0] or "").strip()

        def _ray_id(self) -> str:
            v = (self.headers.get("Cf-Ray") or self.headers.get("CF-Ray") or "").strip()
            return v[:32]

        def _send_500(self) -> None:
            host_header = (self.headers.get("Host") or "").strip()
            params = _normalize_params(
                base_params,
                ray_id=self._ray_id(),
                client_ip=self._client_ip(),
                host_header=host_header,
            )
            body = render_cloudflare_error_page(params)
            self.send_response(500)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)

        def do_GET(self):  # noqa: N802
            self._send_500()

        def do_HEAD(self):  # noqa: N802
            self._send_500()

        def do_POST(self):  # noqa: N802
            self._send_500()

        def do_PUT(self):  # noqa: N802
            self._send_500()

        def do_PATCH(self):  # noqa: N802
            self._send_500()

        def do_DELETE(self):  # noqa: N802
            self._send_500()

        def do_OPTIONS(self):  # noqa: N802
            self._send_500()

        def log_message(self, format, *args):  # noqa: A003
            return

    class ReusableTCPServer(ThreadingHTTPServer):
        allow_reuse_address = True

    with ReusableTCPServer((args.bind, args.port), Handler) as httpd:
        httpd.daemon_threads = True
        httpd.serve_forever(poll_interval=0.5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

    if [[ ! -f "${FALLBACK_LIB_DIR}/params.json" ]]; then
        cat > "${FALLBACK_LIB_DIR}/params.json" << 'JSON'
{
  "title": "Internal server error",
  "error_code": 500,
  "browser_status": { "status": "ok" },
  "cloudflare_status": { "status": "error", "status_text": "Error" },
  "host_status": { "status": "ok", "location": "" },
  "error_source": "cloudflare",
  "what_happened": "<p>There is an internal server error on Cloudflare's network.</p>",
  "what_can_i_do": "<p>Please try again in a few minutes.</p>"
}
JSON
    fi
}

download_cf_fallback_vendor() {
    mkdir -p "${FALLBACK_LIB_DIR}"
    local temp_dir tarball src_root
    temp_dir=$(mktemp -d)
    tarball="${temp_dir}/cf.tgz"

    local branches=("${SUDOKU_CF_FALLBACK_BRANCH}" "main" "master")
    local branch ok="false"
    for branch in "${branches[@]}"; do
        if [[ -z "${branch}" ]]; then
            continue
        fi
        if curl -fsSL "https://codeload.github.com/${SUDOKU_CF_FALLBACK_REPO}/tar.gz/refs/heads/${branch}" -o "${tarball}"; then
            ok="true"
            break
        fi
    done
    if [[ "${ok}" != "true" ]]; then
        rm -rf "${temp_dir}"
        return 1
    fi

    if ! tar -xzf "${tarball}" -C "${temp_dir}" >/dev/null 2>&1; then
        rm -rf "${temp_dir}"
        return 1
    fi

    src_root=$(find "${temp_dir}" -maxdepth 1 -type d -name 'cloudflare-error-page-*' | head -n 1)
    if [[ -z "${src_root}" ]]; then
        rm -rf "${temp_dir}"
        return 1
    fi

    rm -rf "${FALLBACK_LIB_DIR}/templates" "${FALLBACK_LIB_DIR}/cloudflare_error_page"
    cp -r "${src_root}/cloudflare_error_page" "${FALLBACK_LIB_DIR}/cloudflare_error_page"
    mkdir -p "${FALLBACK_LIB_DIR}/cloudflare_error_page/templates"
    cp "${src_root}/resources/styles/main.css" "${FALLBACK_LIB_DIR}/cloudflare_error_page/templates/main.css"
    cp "${src_root}/examples/default.json" "${FALLBACK_LIB_DIR}/params.json"

    rm -rf "${temp_dir}"
    return 0
}

write_cf_fallback_service() {
    local bind="${1:-}"
    local port="${2:-}"
    local pybin
    pybin=$(command -v python3 2>/dev/null || true)
    if [[ -z "${pybin}" ]]; then
        return 1
    fi

    cat > "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service" << EOF
[Unit]
Description=Sudoku Cloudflare 500 Error Page Fallback
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
WorkingDirectory=${FALLBACK_LIB_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${pybin} ${FALLBACK_LIB_DIR}/server.py --bind ${bind} --port ${port} --params ${FALLBACK_LIB_DIR}/params.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

start_cf_fallback_service() {
    local bind="${1:-}"
    local port="${2:-}"

    if ! command -v systemctl &> /dev/null; then
        return 1
    fi
    if [[ ! -f "${FALLBACK_LIB_DIR}/server.py" || ! -f "${FALLBACK_LIB_DIR}/params.json" ]]; then
        return 1
    fi

    write_cf_fallback_service "${bind}" "${port}" || return 1
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl reset-failed "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl enable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl restart "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || systemctl start "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    sleep 1
    if ! systemctl is-active --quiet "${FALLBACK_SERVICE_NAME}"; then
        return 1
    fi

    local url http_code
    url=$(build_http_url "${bind}" "${port}")
    http_code=$(curl -sS -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)
    [[ "${http_code}" == "500" ]]
}

setup_cf_fallback() {
    if [[ "${CF_FALLBACK_ENABLED}" != "true" ]]; then
        return 0
    fi

    info "Setting up Cloudflare-style 500 error page fallback (embedded, no pip required)..."
    write_cf_fallback_server

    local selected_port=""
    if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT}"; then
        selected_port="${CF_FALLBACK_PORT}"
    else
        warn "CF fallback service failed on ${CF_FALLBACK_BIND}:${CF_FALLBACK_PORT}; trying ${CF_FALLBACK_PORT_FALLBACK}"
        if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT_FALLBACK}"; then
            selected_port="${CF_FALLBACK_PORT_FALLBACK}"
        fi
    fi

    if [[ -z "${selected_port}" ]]; then
        warn "CF fallback service setup failed; using fallback_address=${SUDOKU_FALLBACK}"
        if command -v systemctl &> /dev/null; then
            systemctl stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
            systemctl disable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
            rm -f "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service"
            systemctl daemon-reload >/dev/null 2>&1 || true
        fi
        return 0
    fi

    success "CF fallback page listening: $(join_host_port "${CF_FALLBACK_BIND}" "${selected_port}") (always returns HTTP 500)"

    if should_override_fallback_address; then
        SUDOKU_FALLBACK=$(join_host_port "${CF_FALLBACK_BIND}" "${selected_port}")
        success "Sudoku fallback_address -> ${SUDOKU_FALLBACK}"
    else
        info "Keeping user-provided SUDOKU_FALLBACK=${SUDOKU_FALLBACK}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Download Binary
# ═══════════════════════════════════════════════════════════════════════════════

get_latest_version() {
    local version
    # GitHub API is rate-limited; fall back to the releases/latest redirect when needed.
    version=$(
        curl -fsSL "https://api.github.com/repos/${SUDOKU_REPO}/releases/latest" 2>/dev/null \
            | jq -r '.tag_name' 2>/dev/null \
            || true
    )
    if [[ -z "$version" || "$version" == "null" ]]; then
        local url=""
        url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${SUDOKU_REPO}/releases/latest" 2>/dev/null || true)
        version="${url##*/}"
    fi
    if [[ -z "$version" || "$version" == "null" ]]; then
        error "Failed to get latest version. Please check network connectivity."
    fi
    echo "$version"
}

download_binary() {
    local version="$1"
    local download_url="https://github.com/${SUDOKU_REPO}/releases/download/${version}/sudoku-linux-${ARCH}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading Sudoku ${version} for linux-${ARCH}..."
    
    if ! curl -fsSL "$download_url" -o "${temp_dir}/sudoku.tar.gz"; then
        error "Failed to download binary from: $download_url"
    fi
    
    tar -xzf "${temp_dir}/sudoku.tar.gz" -C "${temp_dir}"
    
    # Install binary
    mv "${temp_dir}/sudoku" "${INSTALL_DIR}/sudoku"
    chmod +x "${INSTALL_DIR}/sudoku"
    
    rm -rf "${temp_dir}"
    success "Installed to ${INSTALL_DIR}/sudoku"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Update Kernel Only (Do Not Touch Config)
# ═══════════════════════════════════════════════════════════════════════════════

has_existing_install() {
    [[ -x "${INSTALL_DIR}/sudoku" ]] || [[ -f "${CONFIG_DIR}/config.json" ]] || \
        [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] || \
        [[ -f "/lib/systemd/system/${SERVICE_NAME}.service" ]] || \
        [[ -f "/usr/lib/systemd/system/${SERVICE_NAME}.service" ]]
}

restart_service_if_present() {
    if ! command -v systemctl &> /dev/null; then
        warn "systemctl not found; please restart Sudoku manually if needed."
        return 0
    fi

    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" || -f "/lib/systemd/system/${SERVICE_NAME}.service" || -f "/usr/lib/systemd/system/${SERVICE_NAME}.service" ]]; then
        info "Restarting ${SERVICE_NAME} service..."
        systemctl daemon-reload > /dev/null 2>&1 || true
        systemctl restart "${SERVICE_NAME}" > /dev/null 2>&1 || systemctl start "${SERVICE_NAME}" > /dev/null 2>&1 || true
        sleep 2
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            success "Service restarted successfully"
        else
            warn "Service may have issues. Check: journalctl -u ${SERVICE_NAME}"
        fi
    else
        warn "Systemd service not found; skipped restart."
    fi
}

extract_port_from_hostport() {
    local hp="${1:-}"
    if [[ -z "${hp}" ]]; then
        return 1
    fi
    if [[ "${hp}" == \[*\]:* ]]; then
        printf '%s' "${hp##*]:}"
        return 0
    fi
    printf '%s' "${hp##*:}"
}

extract_host_from_hostport() {
    local hp="${1:-}"
    if [[ -z "${hp}" ]]; then
        return 1
    fi
    if [[ "${hp}" == \[*\]:* ]]; then
        hp="${hp#[}"
        printf '%s' "${hp%%]:*}"
        return 0
    fi
    printf '%s' "${hp%:*}"
}

unique_ports() {
    local out=()
    local seen=" "
    local p
    for p in "$@"; do
        if [[ -z "${p}" ]]; then
            continue
        fi
        if ! is_valid_port "${p}"; then
            continue
        fi
        if [[ "${seen}" == *" ${p} "* ]]; then
            continue
        fi
        out+=("${p}")
        seen+=" ${p} "
    done
    printf '%s\n' "${out[@]}"
}

host_equivalent_for_bind() {
    local bind="${1:-}"
    local host="${2:-}"
    if [[ -z "${bind}" || -z "${host}" ]]; then
        return 1
    fi
    if [[ "${bind}" == "${host}" ]]; then
        return 0
    fi
    case "${bind}" in
        0.0.0.0)
            [[ "${host}" == "127.0.0.1" || "${host}" == "0.0.0.0" ]]
            ;;
        ::|::0)
            [[ "${host}" == "::1" || "${host}" == "::" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

refresh_cf_fallback_if_present() {
    if [[ "${CF_FALLBACK_ENABLED}" != "true" ]]; then
        return 0
    fi
    if ! command -v systemctl &> /dev/null; then
        return 0
    fi
    if [[ ! -f "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service" && ! -f "/lib/systemd/system/${FALLBACK_SERVICE_NAME}.service" && ! -f "/usr/lib/systemd/system/${FALLBACK_SERVICE_NAME}.service" ]]; then
        return 0
    fi

    info "Refreshing ${FALLBACK_SERVICE_NAME} assets..."
    write_cf_fallback_server

    systemctl stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl reset-failed "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true

    local cfg_fallback="" cfg_host="" cfg_port=""
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        cfg_fallback=$(jq -r '.fallback_address // ""' "${CONFIG_DIR}/config.json" 2>/dev/null || true)
        cfg_fallback=$(trim_space "${cfg_fallback}")
        if [[ -n "${cfg_fallback}" ]]; then
            cfg_host=$(extract_host_from_hostport "${cfg_fallback}" 2>/dev/null || true)
            cfg_port=$(extract_port_from_hostport "${cfg_fallback}" 2>/dev/null || true)
        fi
    fi

    local try_ports=""
    if [[ -n "${cfg_host}" && -n "${cfg_port}" ]] && host_equivalent_for_bind "${CF_FALLBACK_BIND}" "${cfg_host}"; then
        try_ports=$(unique_ports "${cfg_port}" "${CF_FALLBACK_PORT}" "${CF_FALLBACK_PORT_FALLBACK}")
    else
        try_ports=$(unique_ports "${CF_FALLBACK_PORT}" "${CF_FALLBACK_PORT_FALLBACK}")
    fi

    local selected_port="" p=""
    while IFS= read -r p; do
        if [[ -z "${p}" ]]; then
            continue
        fi
        if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${p}"; then
            selected_port="${p}"
            break
        fi
    done <<< "${try_ports}"

    if [[ -n "${selected_port}" ]]; then
        success "${FALLBACK_SERVICE_NAME} refreshed (listening: $(join_host_port "${CF_FALLBACK_BIND}" "${selected_port}"))"
    else
        warn "${FALLBACK_SERVICE_NAME} may have issues. Check: journalctl -u ${FALLBACK_SERVICE_NAME}"
    fi
}

config_has_httpmask_object() {
    local path="${1:-}"
    [[ -f "${path}" ]] || return 1
    jq -e '(.httpmask? | type) == "object"' "${path}" >/dev/null 2>&1
}

config_has_legacy_httpmask_fields() {
    local path="${1:-}"
    [[ -f "${path}" ]] || return 1
    jq -e '
        has("disable_http_mask")
        or has("http_mask_mode")
        or has("http_mask_tls")
        or has("http_mask_host")
        or has("path_root")
        or has("http_mask_path_root")
        or has("http_mask_multiplex")
    ' "${path}" >/dev/null 2>&1
}

migrate_legacy_httpmask_config_inplace() {
    local path="${1:-}"
    [[ -f "${path}" ]] || return 1

    if config_has_httpmask_object "${path}"; then
        return 0
    fi
    if ! config_has_legacy_httpmask_fields "${path}"; then
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    if ! jq '
        .httpmask = {
            "disable": (.disable_http_mask // false),
            "mode": ((.http_mask_mode // "legacy") | tostring | if . == "" then "legacy" else . end),
            "tls": (.http_mask_tls // false),
            "host": ((.http_mask_host // "") | tostring),
            "path_root": (((.path_root // .http_mask_path_root // "") | tostring)),
            "multiplex": ((.http_mask_multiplex // "off") | tostring | if . == "" then "off" else . end)
        }
        | del(
            .disable_http_mask,
            .http_mask_mode,
            .http_mask_tls,
            .http_mask_host,
            .path_root,
            .http_mask_path_root,
            .http_mask_multiplex
        )
    ' "${path}" > "${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi

    chmod 600 "${tmp}" >/dev/null 2>&1 || true
    mv "${tmp}" "${path}"
    chmod 600 "${path}" >/dev/null 2>&1 || true
    return 0
}

update_kernel_only() {
    echo ""
    warn "Existing installation detected. Updating binary only (config preserved)."
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        info "Config preserved: ${CONFIG_DIR}/config.json"
    fi

    VERSION=$(get_latest_version)
    download_binary "$VERSION"

    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        info "Validating existing configuration..."
        local test_output=""
        if ! test_output=$("${INSTALL_DIR}/sudoku" -c "${CONFIG_DIR}/config.json" -test 2>&1); then
            warn "Config validation failed; attempting migration for legacy HTTP mask fields..."
            if migrate_legacy_httpmask_config_inplace "${CONFIG_DIR}/config.json"; then
                if test_output=$("${INSTALL_DIR}/sudoku" -c "${CONFIG_DIR}/config.json" -test 2>&1); then
                    success "Config migrated and validated"
                else
                    echo "${test_output}" >&2
                    error "Config remains invalid after migration: ${CONFIG_DIR}/config.json"
                fi
            else
                echo "${test_output}" >&2
                error "Config validation failed: ${CONFIG_DIR}/config.json"
            fi
        else
            success "Config is valid"
        fi
    fi

    restart_service_if_present
    refresh_cf_fallback_if_present
    success "Kernel update complete (${VERSION})"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Key Generation
# ═══════════════════════════════════════════════════════════════════════════════

generate_keypair() {
    info "Generating keypair..."
    
    local keygen_output
    keygen_output=$("${INSTALL_DIR}/sudoku" -keygen 2>&1)
    
    AVAILABLE_PRIVATE_KEY=$(
        printf '%s\n' "$keygen_output" \
            | sed -n 's/.*Available Private Key:[[:space:]]*\([0-9a-fA-F][0-9a-fA-F]*\).*/\1/p' \
            | head -n 1
    )
    MASTER_PUBLIC_KEY=$(
        printf '%s\n' "$keygen_output" \
            | sed -n 's/.*Master Public Key:[[:space:]]*\([0-9a-fA-F][0-9a-fA-F]*\).*/\1/p' \
            | head -n 1
    )
    
    if [[ -z "$AVAILABLE_PRIVATE_KEY" || -z "$MASTER_PUBLIC_KEY" ]]; then
        echo "${keygen_output}" >&2
        error "Failed to generate keypair"
    fi
    
    success "Keypair generated successfully"
}

# ═══════════════════════════════════════════════════════════════════════════════
# IP Detection
# ═══════════════════════════════════════════════════════════════════════════════

get_public_ip() {
    if [[ -n "${SERVER_IP:-}" ]]; then
        success "Public host: ${SERVER_IP}"
        return 0
    fi

    local ip=""
    local apis=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://icanhazip.com"
        "https://ipinfo.io/ip"
        "https://api.ip.sb/ip"
    )
    
    info "Detecting public IP address..."
    
    for api in "${apis[@]}"; do
        ip=$(curl -fsSL --connect-timeout 5 "$api" 2>/dev/null | tr -d '\n')
        if [[ -n "$ip" ]]; then
            # Basic IPv4 / IPv6 check (best effort).
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "$ip" =~ ^[0-9a-fA-F:]+$ ]]; then
                SERVER_IP="$ip"
                success "Public IP: $SERVER_IP"
                return 0
            fi
        fi
    done
    
    error "Failed to detect public IP. Please set SERVER_IP manually."
}

# ═══════════════════════════════════════════════════════════════════════════════
# X/P/V Custom Table (Sudoku v0.1.4+)
# ═══════════════════════════════════════════════════════════════════════════════

rand_uint32() {
    od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' '
}

generate_xpv_table() {
    local chars=(x x p p v v v v)
    local i j tmp r

    for ((i=${#chars[@]}-1; i>0; i--)); do
        r=$(rand_uint32)
        if [[ -z "$r" ]]; then
            r=$RANDOM
        fi
        j=$((r % (i+1)))
        tmp="${chars[i]}"
        chars[i]="${chars[j]}"
        chars[j]="$tmp"
    done

    printf '%s' "${chars[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

create_config() {
    info "Creating server configuration..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "${CONFIG_DIR}/config.json" << EOF
{
  "mode": "server",
  "transport": "tcp",
  "local_port": ${SUDOKU_PORT},
  "server_address": "",
  "fallback_address": "${SUDOKU_FALLBACK}",
  "key": "${MASTER_PUBLIC_KEY}",
  "aead": "chacha20-poly1305",
  "suspicious_action": "fallback",
  "ascii": "prefer_entropy",
  "padding_min": 2,
  "padding_max": 7,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "httpmask": {
    "disable": ${DISABLE_HTTP_MASK},
    "mode": "${HTTP_MASK_MODE}",
    "tls": ${HTTP_MASK_TLS},
    "host": "${HTTP_MASK_HOST}",
    "path_root": "${HTTP_MASK_PATH_ROOT}",
    "multiplex": "${HTTP_MASK_MULTIPLEX}"
  }
}
EOF
    
    chmod 600 "${CONFIG_DIR}/config.json"

    info "Testing server configuration..."
    local test_output
    if ! test_output=$("${INSTALL_DIR}/sudoku" -c "${CONFIG_DIR}/config.json" -test 2>&1); then
        echo "${test_output}" >&2
        error "Config validation failed: ${CONFIG_DIR}/config.json"
    fi
    success "Configuration validated"

    success "Configuration saved to ${CONFIG_DIR}/config.json"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Firewall Configuration
# ═══════════════════════════════════════════════════════════════════════════════

configure_firewall() {
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            info "Configuring UFW firewall..."
            ufw allow "${SUDOKU_PORT}/tcp" > /dev/null 2>&1
            success "UFW: Opened port ${SUDOKU_PORT}/tcp"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            info "Configuring firewalld..."
            firewall-cmd --permanent --add-port="${SUDOKU_PORT}/tcp" > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
            success "firewalld: Opened port ${SUDOKU_PORT}/tcp"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Systemd Service
# ═══════════════════════════════════════════════════════════════════════════════

create_service() {
    info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Sudoku Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/sudoku -c ${CONFIG_DIR}/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" > /dev/null 2>&1
    systemctl start "${SERVICE_NAME}"
    
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        success "Service started successfully"
    else
        warn "Service may have issues. Check: journalctl -u ${SERVICE_NAME}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Generate Short Link
# ═══════════════════════════════════════════════════════════════════════════════

generate_short_link() {
    info "Generating sudoku:// short link..."

    local temp_dir temp_cfg export_output
    temp_dir=$(mktemp -d)
    temp_cfg="${temp_dir}/client.json"
    local server_address
    server_address=$(join_host_port "${SERVER_IP}" "${SUDOKU_PORT}")

    cat > "${temp_cfg}" << EOF
{
  "mode": "client",
  "transport": "tcp",
  "local_port": ${SUDOKU_CLIENT_PORT},
  "server_address": "${server_address}",
  "key": "${AVAILABLE_PRIVATE_KEY}",
  "aead": "chacha20-poly1305",
  "ascii": "prefer_entropy",
  "padding_min": 5,
  "padding_max": 15,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "httpmask": {
    "disable": ${DISABLE_HTTP_MASK},
    "mode": "${HTTP_MASK_MODE}",
    "tls": ${HTTP_MASK_TLS},
    "host": "${HTTP_MASK_HOST}",
    "path_root": "${HTTP_MASK_PATH_ROOT}",
    "multiplex": "${HTTP_MASK_MULTIPLEX}"
  },
  "rule_urls": ["global"]
}
EOF

    export_output=$("${INSTALL_DIR}/sudoku" -c "${temp_cfg}" -export-link 2>&1 || true)
    SHORT_LINK=$(echo "${export_output}" | awk -F 'Short link: ' '/Short link: /{print $2; exit}')
    rm -rf "${temp_dir}"

    if [[ -z "${SHORT_LINK}" ]]; then
        echo "${export_output}" >&2
        error "Failed to generate short link"
    fi
    success "Short link generated"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Generate Clash Config
# ═══════════════════════════════════════════════════════════════════════════════

generate_clash_config() {
    local http_mask_yaml="true"
    if [[ "${DISABLE_HTTP_MASK}" == "true" ]]; then
        http_mask_yaml="false"
    fi

    local lines=(
        "# sudoku"
        "- name: sudoku"
        "  type: sudoku"
        "  server: \"${SERVER_IP}\""
        "  port: ${SUDOKU_PORT}"
        "  key: \"${AVAILABLE_PRIVATE_KEY}\""
        "  aead-method: chacha20-poly1305"
        "  padding-min: 2"
        "  padding-max: 7"
    )

    if [[ -n "${CUSTOM_TABLE:-}" ]]; then
        lines+=("  custom-table: ${CUSTOM_TABLE}")
    fi

    lines+=(
        "  table-type: prefer_entropy"
        "  http-mask: ${http_mask_yaml}"
        "  http-mask-mode: ${HTTP_MASK_MODE}"
        "  http-mask-tls: ${HTTP_MASK_TLS}"
        "  http-mask-multiplex: \"${HTTP_MASK_MULTIPLEX}\""
    )

    if [[ -n "${HTTP_MASK_HOST:-}" ]]; then
        lines+=("  http-mask-host: \"${HTTP_MASK_HOST}\"")
    fi

    lines+=("  enable-pure-downlink: false")

    CLASH_CONFIG=$(printf '%s\n' "${lines[@]}")
}

# ═══════════════════════════════════════════════════════════════════════════════
# Output Results
# ═══════════════════════════════════════════════════════════════════════════════

print_results() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📱 Short Link (for sudoku client):${NC}"
    echo -e "${YELLOW}${SHORT_LINK}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📋 Clash/Mihomo Node Config:${NC}"
    echo -e "${YELLOW}${CLASH_CONFIG}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔑 Keys (save these securely):${NC}"
    echo -e "  Client Key (Private): ${YELLOW}${AVAILABLE_PRIVATE_KEY}${NC}"
    echo -e "  Server Key (Public):  ${YELLOW}${MASTER_PUBLIC_KEY}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}⚙️  Service Management:${NC}"
    echo -e "  Status:  ${YELLOW}systemctl status ${SERVICE_NAME}${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "  Logs:    ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📂 Configuration:${NC}"
    echo -e "  Config file: ${YELLOW}${CONFIG_DIR}/config.json${NC}"
    echo -e "  Binary:      ${YELLOW}${INSTALL_DIR}/sudoku${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}🧹 Uninstall:${NC}"
    printf '  %s%s%s\n' "${YELLOW}" 'sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)" -- --uninstall' "${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Uninstall Function
# ═══════════════════════════════════════════════════════════════════════════════

uninstall() {
    echo -e "${RED}Uninstalling Sudoku...${NC}"
    
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload

    systemctl stop "${FALLBACK_SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${FALLBACK_SERVICE_NAME}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service"
    systemctl daemon-reload
    
    rm -f "${INSTALL_DIR}/sudoku"
    rm -rf "${CONFIG_DIR}"
    rm -rf "${FALLBACK_LIB_DIR}"
    
    # Remove firewall rule
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        ufw delete allow "${SUDOKU_PORT}/tcp" > /dev/null 2>&1 || true
    fi
    
    echo -e "${GREEN}Uninstallation complete.${NC}"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Handle uninstall
    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" || "${0:-}" == "--uninstall" || "${0:-}" == "-u" ]]; then
        uninstall
    fi
    
    print_banner
    
    info "Starting installation..."
    echo ""
    
    # Pre-flight checks
    check_root
    detect_os
    detect_arch
    normalize_settings
    check_dependencies
    
    echo ""

    # If already installed, only update the binary (do not touch config)
    if has_existing_install; then
        update_kernel_only
    fi

    # Get latest version and download
    VERSION=$(get_latest_version)
    download_binary "$VERSION"
    
    # Generate keys and detect IP
    generate_keypair
    get_public_ip

    CUSTOM_TABLE=$(generate_xpv_table)
    success "Custom X/P/V table: ${CUSTOM_TABLE}"
    
    echo ""
    
    # Setup
    setup_cf_fallback
    create_config
    configure_firewall
    create_service
    
    # Generate output
    generate_short_link
    generate_clash_config
    
    # Display results
    print_results
}

main "$@"
