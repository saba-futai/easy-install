import { buildKIPMessage, encodeAddress, joinHostPort, splitHostPort } from "./sudoku-protocol.mjs";

export function normalizePathRoot(value) {
  const raw = String(value || "").trim().replace(/^\/+|\/+$/g, "");
  if (!raw) return "";
  if (!/^[A-Za-z0-9_-]+$/.test(raw)) {
    throw new Error("SUDOKU_HTTP_MASK_PATH_ROOT must be [A-Za-z0-9_-]");
  }
  return raw;
}

export function buildWSPath(pathRoot) {
  return pathRoot ? `/${pathRoot}/ws` : "/ws";
}

export function buildClientConfig(options) {
  const serverAddress = joinHostPort(options.publicHost, 443);
  return {
    mode: "client",
    transport: "tcp",
    local_port: Number.parseInt(String(options.localPort || 10233), 10),
    server_address: serverAddress,
    key: String(options.key || "").trim(),
    aead: String(options.aead || "aes-128-gcm").trim() || "aes-128-gcm",
    ascii: String(options.ascii || "prefer_entropy").trim() || "prefer_entropy",
    padding_min: 0,
    padding_max: 0,
    enable_pure_downlink: true,
    httpmask: {
      disable: false,
      mode: "ws",
      tls: true,
      host: String(options.httpMaskHost || "").trim(),
      path_root: normalizePathRoot(options.pathRoot),
      multiplex: "off",
    },
    rule_urls: ["global"],
  };
}

export function buildShortLinkFromClientConfig(config) {
  const { host, port } = splitHostPort(config.server_address);
  const payload = {
    h: host,
    p: port,
    k: config.key,
    a: config.ascii === "prefer_ascii" ? "ascii" : "entropy",
    e: config.aead,
    m: config.local_port,
    ht: true,
    hm: "ws",
    x: false,
  };
  if (config.httpmask?.host) payload.hh = config.httpmask.host;
  if (config.httpmask?.path_root) payload.hy = config.httpmask.path_root;
  return `sudoku://${toBase64Url(JSON.stringify(payload))}`;
}

export function buildClashNode(config, nodeName = "sudoku-cf-worker-pure") {
  const { host, port } = splitHostPort(config.server_address);
  const lines = [
    "# sudoku",
    `- name: ${nodeName}`,
    "  type: sudoku",
    `  server: "${host}"`,
    `  port: ${port}`,
    `  key: "${config.key}"`,
    `  aead-method: ${config.aead}`,
    "  padding-min: 0",
    "  padding-max: 0",
    `  table-type: ${config.ascii}`,
    "  http-mask: true",
    "  http-mask-mode: ws",
    "  http-mask-tls: true",
    "  http-mask-multiplex: \"off\"",
    "  enable-pure-downlink: true",
  ];
  if (config.httpmask?.host) lines.push(`  http-mask-host: "${config.httpmask.host}"`);
  if (config.httpmask?.path_root) lines.push(`  http-mask-path-root: "${config.httpmask.path_root}"`);
  return `${lines.join("\n")}\n`;
}

export function buildOpenTcpMessage(targetAddress) {
  return buildKIPMessage(0x10, encodeAddress(targetAddress));
}

function toBase64Url(input) {
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
