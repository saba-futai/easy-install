import {
  buildClientConfig,
  buildClashNode,
  buildShortLinkFromClientConfig,
} from "../src/sudoku-config.mjs";

function usage() {
  console.error(`Usage:
  node cf-worker/tools/build-shortlink.mjs --host worker.example.com --key <key> [options]

Options:
  --local-port <port>         Client local port, default 10233
  --path-root <segment>       Optional fixed HTTP mask path root; export uses /<segment>, omitted => derive a stable random segment from key
  --preferred-address <addr>  Optional preferred ingress IP/domain:port for exported node, while keeping --host as Host/SNI
  --host-header <host>        Optional HTTP Host/SNI override
  --aead <name>               AEAD, default none
  --ascii <mode>              prefer_entropy / prefer_ascii / up_*_down_*, default prefer_entropy
  --packed-downlink <bool>    true enables packed downlink, default true
  --mux <mode>                off / auto / on, default off
  --node-name <name>          Clash node name, default sudoku-cf-worker
`);
  process.exit(1);
}

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) usage();
    const value = argv[i + 1];
    if (value === undefined || value.startsWith("--")) usage();
    result[key.slice(2)] = value;
    i += 1;
  }
  return result;
}

function parseBoolean(value, fallback) {
  if (value === undefined) return fallback;
  const raw = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(raw)) return true;
  if (["0", "false", "no", "off"].includes(raw)) return false;
  usage();
}

const args = parseArgs(process.argv.slice(2));
if (!args.host || !args.key) {
  usage();
}

const config = buildClientConfig({
  publicHost: args.host,
  serverAddress: args["preferred-address"] || "",
  key: args.key,
  localPort: args["local-port"] || "10233",
  pathRoot: args["path-root"] || "",
  httpMaskHost: args["host-header"] || (args["preferred-address"] ? args.host : ""),
  aead: args.aead || "none",
  ascii: args.ascii || "prefer_entropy",
  enablePureDownlink: !parseBoolean(args["packed-downlink"], true),
  httpMaskMultiplex: args.mux || "off",
});

const shortLink = buildShortLinkFromClientConfig(config);
const clash = buildClashNode(config, args["node-name"] || "sudoku-cf-worker-pure");

process.stdout.write(`${shortLink}\n\n`);
process.stdout.write(`${JSON.stringify(config, null, 2)}\n\n`);
process.stdout.write(clash);
