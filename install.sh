#!/bin/bash
#
# Sudoku Server One-Click Installation Script
# https://github.com/SUDOKU-ASCII/sudoku
#
# Usage:
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
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
import datetime as _dt
import html
import json
import socketserver
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


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

        def _render(self) -> bytes:
            params = dict(base_params or {})
            params.setdefault("title", "500 Internal Server Error")
            params.setdefault("headline", "Internal Server Error")
            params.setdefault("subtitle", "The web server is returning an unknown error")
            params.setdefault("footer", "cloudflare")

            ray = self._ray_id()
            cip = self._client_ip()
            now = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

            def esc(x: object) -> str:
                return html.escape("" if x is None else str(x), quote=True)

            # Minimal Cloudflare-like style (no external deps; safe for restricted networks).
            css = """
            :root{--bg:#f2f2f2;--fg:#313131;--muted:#777;--card:#fff;--border:#e5e5e5;}
            *{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,'Noto Sans',sans-serif;background:var(--bg);color:var(--fg)}
            .wrap{max-width:720px;margin:0 auto;padding:32px 16px}
            .card{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:24px}
            h1{font-size:22px;margin:0 0 6px}h2{font-size:14px;color:var(--muted);margin:0 0 16px;font-weight:600}
            .hr{height:1px;background:var(--border);margin:18px 0}
            .meta{display:grid;grid-template-columns:1fr;gap:8px;font-size:13px;color:var(--muted)}
            .mono{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,'Liberation Mono','Courier New',monospace}
            .badge{display:inline-block;padding:2px 8px;border-radius:999px;border:1px solid var(--border);background:#fafafa}
            .footer{margin-top:14px;font-size:12px;color:var(--muted);text-transform:lowercase;letter-spacing:.06em}
            """.strip()

            html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(params.get("title"))}</title>
  <style>{css}</style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="badge mono">Error 500</div>
      <h1>{esc(params.get("headline"))}</h1>
      <h2>{esc(params.get("subtitle"))}</h2>
      <div class="hr"></div>
      <div class="meta">
        <div>Ray ID: <span class="mono">{esc(ray) if ray else "-"}</span></div>
        <div>Your IP: <span class="mono">{esc(cip) if cip else "-"}</span></div>
        <div>Timestamp: <span class="mono">{esc(now)}</span></div>
      </div>
      <div class="footer">{esc(params.get("footer"))}</div>
    </div>
  </div>
</body>
</html>
"""
            return html_doc.encode("utf-8", errors="replace")

        def _send_500(self) -> None:
            body = self._render()
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
            # Quiet by default; this service is only for decoy fallback.
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
  "title": "500 Internal Server Error",
  "headline": "Internal Server Error",
  "subtitle": "The web server is returning an unknown error",
  "footer": "cloudflare"
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
            | sed -n 's/.*Available Private Key:[[:space:]]*\\([0-9a-fA-F][0-9a-fA-F]*\\).*/\\1/p' \
            | head -n 1
    )
    MASTER_PUBLIC_KEY=$(
        printf '%s\n' "$keygen_output" \
            | sed -n 's/.*Master Public Key:[[:space:]]*\\([0-9a-fA-F][0-9a-fA-F]*\\).*/\\1/p' \
            | head -n 1
    )
    
    if [[ -z "$AVAILABLE_PRIVATE_KEY" || -z "$MASTER_PUBLIC_KEY" ]]; then
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
    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
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
