import { joinHostPort, splitHostPort } from "./sudoku-protocol.mjs";

const remoteCache = new Map();
const DEFAULT_WETEST_SOURCES = [
  "https://www.wetest.vip/page/cloudflare/address_v4.html",
  "https://www.wetest.vip/page/cloudflare/address_v6.html",
];

function uniqByAddress(entries) {
  const seen = new Set();
  const out = [];
  for (const entry of entries) {
    if (!entry?.address || seen.has(entry.address)) continue;
    seen.add(entry.address);
    out.push(entry);
  }
  return out;
}

function parseMaybeNumber(value) {
  const raw = String(value ?? "").trim().replace(/,/g, "");
  if (!raw) return null;
  const num = Number(raw);
  return Number.isFinite(num) ? num : null;
}

function normalizeAddress(value, defaultPort = 443) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  try {
    const { host, port } = splitHostPort(raw);
    return joinHostPort(host, port);
  } catch {
    if (raw.includes(":") && !raw.startsWith("[") && raw.includes("::")) {
      return joinHostPort(raw, defaultPort);
    }
    return joinHostPort(raw, defaultPort);
  }
}

function normalizeEntry(value, defaultPort = 443) {
  if (!value) return null;
  if (typeof value === "string") {
    const raw = value.trim();
    if (!raw || raw.startsWith("#") || raw.startsWith("//")) return null;
    const hashIndex = raw.indexOf("#");
    const addressPart = hashIndex >= 0 ? raw.slice(0, hashIndex).trim() : raw;
    const namePart = hashIndex >= 0 ? raw.slice(hashIndex + 1).trim() : "";
    const address = normalizeAddress(addressPart, defaultPort);
    if (!address) return null;
    return { address, name: namePart || "", latencyMs: null, downloadMbps: null, score: null, sourceIndex: 0 };
  }

  if (typeof value === "object") {
    const address = normalizeAddress(
      value.address || value.addr || value.endpoint || (value.ip || value.host ? joinHostPort(value.ip || value.host, Number.parseInt(String(value.port || defaultPort), 10) || defaultPort) : ""),
      defaultPort,
    );
    if (!address) return null;
    const name = String(value.name || value.label || value.remark || value.title || "").trim();
    return {
      address,
      name,
      latencyMs: parseMaybeNumber(value.latency ?? value.delay ?? value.ping ?? value.latency_ms),
      downloadMbps: parseMaybeNumber(value.download ?? value.speed ?? value.download_mbps ?? value.bandwidth),
      score: parseMaybeNumber(value.score ?? value.rank_score),
      sourceIndex: Number.isInteger(value.sourceIndex) ? value.sourceIndex : 0,
    };
  }

  return null;
}

function parseCsvEntries(input, defaultPort = 443) {
  const lines = String(input || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length < 2 || !lines[0].includes(",")) return [];

  const headers = lines[0].split(",").map((header) => header.trim().toLowerCase());
  const idx = (names) => names.map((name) => headers.indexOf(name)).find((value) => value >= 0) ?? -1;
  const ipIdx = idx(["ip", "address", "host"]);
  const portIdx = idx(["port"]);
  const latencyIdx = idx(["latency", "delay", "ping", "latency_ms"]);
  const speedIdx = idx(["download", "downloadmbps", "download_mbps", "speed", "bandwidth"]);
  const regionIdx = idx(["region", "colo", "datacenter", "loc", "city", "label", "name"]);
  const scoreIdx = idx(["score", "rank", "rank_score"]);
  if (ipIdx < 0) return [];

  const entries = [];
  for (let i = 1; i < lines.length; i += 1) {
    const cols = lines[i].split(",").map((col) => col.trim());
    const host = cols[ipIdx];
    const port = portIdx >= 0 ? cols[portIdx] : "";
    const address = normalizeAddress(port ? joinHostPort(host, Number.parseInt(port, 10) || defaultPort) : host, defaultPort);
    if (!address) continue;
    entries.push({
      address,
      name: regionIdx >= 0 ? cols[regionIdx] || "" : "",
      latencyMs: latencyIdx >= 0 ? parseMaybeNumber(cols[latencyIdx]) : null,
      downloadMbps: speedIdx >= 0 ? parseMaybeNumber(cols[speedIdx]) : null,
      score: scoreIdx >= 0 ? parseMaybeNumber(cols[scoreIdx]) : null,
      sourceIndex: i - 1,
    });
  }
  return uniqByAddress(entries);
}

function parseJsonEntries(input, defaultPort = 443) {
  let parsed;
  try {
    parsed = JSON.parse(input);
  } catch {
    return [];
  }

  if (Array.isArray(parsed)) {
    return uniqByAddress(parsed.map((item) => normalizeEntry(item, defaultPort)).filter(Boolean));
  }

  if (parsed && typeof parsed === "object") {
    for (const key of ["addresses", "ips", "data", "result", "list", "items"]) {
      if (Array.isArray(parsed[key])) {
        return uniqByAddress(parsed[key].map((item) => normalizeEntry(item, defaultPort)).filter(Boolean));
      }
    }
    const single = normalizeEntry(parsed, defaultPort);
    return single ? [single] : [];
  }

  return [];
}

function stripHtmlTags(value) {
  return String(value || "").replace(/<[^>]*>/g, "").replace(/&nbsp;/gi, " ").trim();
}

function parseWetestHtml(input, defaultPort = 443) {
  const html = String(input || "");
  if (!html.includes('data-label="优选地址"')) return [];

  const results = [];
  const rowRegex = /<tr[\s\S]*?<\/tr>/gi;
  const cellRegex = /<td[^>]*data-label="线路名称"[^>]*>([\s\S]*?)<\/td>[\s\S]*?<td[^>]*data-label="优选地址"[^>]*>([\d.:a-fA-F]+)<\/td>[\s\S]*?<td[^>]*data-label="数据中心"[^>]*>([\s\S]*?)<\/td>/i;

  let row;
  while ((row = rowRegex.exec(html)) !== null) {
    const match = row[0].match(cellRegex);
    if (!match) continue;
    const lineName = stripHtmlTags(match[1]);
    const host = stripHtmlTags(match[2]);
    const colo = stripHtmlTags(match[3]);
    const address = normalizeAddress(host, defaultPort);
    if (!address) continue;
    const name = [lineName, colo].filter(Boolean).join(" | ");
    results.push({
      address,
      name,
      latencyMs: null,
      downloadMbps: null,
      score: null,
      sourceIndex: results.length,
    });
  }

  return uniqByAddress(results);
}

export function parsePreferredIpList(input, defaultPort = 443) {
  const raw = String(input || "").trim();
  if (!raw) return [];
  if (raw.includes('data-label="优选地址"')) {
    const parsed = parseWetestHtml(raw, defaultPort);
    if (parsed.length > 0) return parsed;
  }
  if (raw.startsWith("[") || raw.startsWith("{")) {
    const parsed = parseJsonEntries(raw, defaultPort);
    if (parsed.length > 0) return parsed;
  }
  if (raw.includes(",") && raw.includes("\n")) {
    const csvEntries = parseCsvEntries(raw, defaultPort);
    if (csvEntries.length > 0) return csvEntries;
  }
  const entries = raw
    .split(/[\n,]+/)
    .map((part, index) => {
      const entry = normalizeEntry(part, defaultPort);
      if (entry) entry.sourceIndex = index;
      return entry;
    })
    .filter(Boolean);
  return uniqByAddress(entries);
}

export const CFNEW_DEFAULT_PREFERRED_ENTRIES = [];

async function loadBuiltInPreferredEntries(defaultPort, cacheTtlMs) {
  const cacheKey = "__builtin_wetest__";
  const now = Date.now();
  const cached = remoteCache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.entries;
  }

  const settled = await Promise.allSettled(
    DEFAULT_WETEST_SOURCES.map((source) =>
      fetch(source, {
        headers: { accept: "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8" },
        cf: { cacheTtl: 0, cacheEverything: false },
      }).then(async (response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return parseWetestHtml(await response.text(), defaultPort);
      }),
    ),
  );

  const entries = uniqByAddress(
    settled.flatMap((result) => (result.status === "fulfilled" ? result.value : [])),
  ).map((entry, index) => ({ ...entry, sourceIndex: index }));

  remoteCache.set(cacheKey, { entries, expiresAt: now + Math.max(cacheTtlMs, 0) });
  return entries;
}

export function isLiteralIpHost(host) {
  const raw = String(host || "").trim();
  return /^(\d{1,3}\.){3}\d{1,3}$/.test(raw) || raw.includes(":");
}

export function classifyPreferredEntry(entry) {
  const { host } = splitHostPort(entry.address);
  return isLiteralIpHost(host) ? "ip" : "domain";
}

export function filterPreferredEntries(entries, { enableIPs = true, enableDomains = true, region = "" } = {}) {
  const regionNeedle = String(region || "").trim().toUpperCase();
  return entries.filter((entry) => {
    const kind = classifyPreferredEntry(entry);
    if (kind === "ip" && !enableIPs) return false;
    if (kind === "domain" && !enableDomains) return false;
    if (!regionNeedle) return true;
    const haystack = `${entry.name || ""} ${entry.address}`.toUpperCase();
    return haystack.includes(regionNeedle);
  });
}

async function loadFromRemoteUrl(source, defaultPort, cacheTtlMs) {
  const now = Date.now();
  const cached = remoteCache.get(source);
  if (cached && cached.expiresAt > now) {
    return cached;
  }
  const response = await fetch(source, {
    headers: { accept: "application/json,text/plain;q=0.9,*/*;q=0.8" },
    cf: { cacheTtl: 0, cacheEverything: false },
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const text = await response.text();
  const remoteEntries = parsePreferredIpList(text, defaultPort);
  const result = { entries: remoteEntries, text };
  remoteCache.set(source, { ...result, expiresAt: now + Math.max(cacheTtlMs, 0) });
  return result;
}

export async function loadPreferredIpPool({ inlineList = "", sourceUrl = "", defaultPort = 443, cacheTtlMs = 0, kv = null, kvKey = "", defaultEntries = [], enableBuiltIn = false }) {
  const inlineEntries = parsePreferredIpList(inlineList, defaultPort);
  let builtInEntries = Array.isArray(defaultEntries) ? defaultEntries : [];
  let kvEntries = [];
  const kvStorageKey = String(kvKey || "").trim();
  if (kv && kvStorageKey) {
    try {
      kvEntries = parsePreferredIpList((await kv.get(kvStorageKey, "text")) || "", defaultPort);
    } catch {}
  }
  const source = String(sourceUrl || "").trim();
  if (!source && enableBuiltIn && kvEntries.length === 0 && inlineEntries.length === 0 && builtInEntries.length === 0) {
    try {
      builtInEntries = await loadBuiltInPreferredEntries(defaultPort, cacheTtlMs);
    } catch {}
  }
  if (!source) {
    return {
      entries: uniqByAddress([...kvEntries, ...inlineEntries, ...builtInEntries]),
      preferredSource: kvEntries.length > 0 ? "kv" : inlineEntries.length > 0 ? "inline" : builtInEntries.length > 0 ? "builtin-wetest" : "",
      preferredError: "",
    };
  }

  try {
    const { entries: remoteEntries } = await loadFromRemoteUrl(source, defaultPort, cacheTtlMs);
    return {
      entries: uniqByAddress([...remoteEntries, ...kvEntries, ...inlineEntries, ...builtInEntries]),
      preferredSource: remoteEntries.length > 0 ? source : kvEntries.length > 0 ? "kv" : inlineEntries.length > 0 ? "inline" : "",
      preferredError: remoteEntries.length > 0 || kvEntries.length > 0 || inlineEntries.length > 0 || builtInEntries.length > 0 ? "" : "preferred IP source returned no usable entries",
    };
  } catch (error) {
    return {
      entries: uniqByAddress([...kvEntries, ...inlineEntries, ...builtInEntries]),
      preferredSource: kvEntries.length > 0 ? "kv" : inlineEntries.length > 0 ? "inline" : builtInEntries.length > 0 ? "builtin-wetest" : "",
      preferredError: error instanceof Error ? error.message : String(error),
    };
  }
}

export function normalizePreferredIpStrategy(value) {
  const raw = String(value || "").trim().toLowerCase();
  if (!raw || raw === "best") return "best";
  if (raw === "first" || raw === "rotate" || raw === "random") return raw;
  throw new Error(`invalid preferred IP strategy: ${value}`);
}

function comparePreferredEntries(a, b) {
  const aScore = a.score;
  const bScore = b.score;
  if (aScore !== null && bScore !== null && aScore !== bScore) return bScore - aScore;

  const aLatency = a.latencyMs;
  const bLatency = b.latencyMs;
  if (aLatency !== null && bLatency !== null && aLatency !== bLatency) return aLatency - bLatency;

  const aSpeed = a.downloadMbps;
  const bSpeed = b.downloadMbps;
  if (aSpeed !== null && bSpeed !== null && aSpeed !== bSpeed) return bSpeed - aSpeed;

  return (a.sourceIndex || 0) - (b.sourceIndex || 0);
}

export function pickPreferredEntry(entries, strategy = "best", seed = "") {
  if (!entries?.length) return null;
  if (strategy === "best") {
    const sorted = [...entries].sort(comparePreferredEntries);
    return sorted[0];
  }
  if (strategy === "first") return entries[0];
  if (strategy === "random") return entries[Math.floor(Math.random() * entries.length)];

  let hash = 0x811c9dc5;
  const input = new TextEncoder().encode(`${seed}|${Math.floor(Date.now() / 60000)}`);
  for (const byte of input) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return entries[hash % entries.length];
}
