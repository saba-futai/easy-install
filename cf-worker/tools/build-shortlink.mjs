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
  --path-root <segment>       Optional HTTP mask path root
  --host-header <host>        Optional HTTP Host/SNI override
  --aead <name>               AEAD, default aes-128-gcm
  --ascii <mode>              prefer_entropy / prefer_ascii, default prefer_entropy
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

const args = parseArgs(process.argv.slice(2));
if (!args.host || !args.key) {
  usage();
}

const config = buildClientConfig({
  publicHost: args.host,
  key: args.key,
  localPort: args["local-port"] || "10233",
  pathRoot: args["path-root"] || "",
  httpMaskHost: args["host-header"] || "",
  aead: args.aead || "aes-128-gcm",
  ascii: args.ascii || "prefer_entropy",
});

const shortLink = buildShortLinkFromClientConfig(config);
const clash = buildClashNode(config, args["node-name"] || "sudoku-cf-worker-pure");

process.stdout.write(`${shortLink}\n\n`);
process.stdout.write(`${JSON.stringify(config, null, 2)}\n\n`);
process.stdout.write(clash);
