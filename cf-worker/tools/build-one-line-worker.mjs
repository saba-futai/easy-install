import { mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(import.meta.dirname, "..", "..");
const entryFile = resolve(repoRoot, "cf-worker", "src", "index.mjs");
const outFile = resolve(repoRoot, "cf-worker", "dashboard", "sudoku-worker.one.js");
const tempFile = resolve(repoRoot, "cf-worker", "dashboard", ".sudoku-worker.one.tmp.js");

mkdirSync(dirname(outFile), { recursive: true });

const args = [
  "--yes",
  "esbuild",
  entryFile,
  "--bundle",
  "--format=esm",
  "--platform=browser",
  "--target=es2022",
  "--minify",
  "--external:cloudflare:sockets",
  `--outfile=${tempFile}`,
];

const result = spawnSync("npx", args, {
  cwd: repoRoot,
  encoding: "utf8",
});

if (result.status !== 0) {
  process.stderr.write(result.stdout || "");
  process.stderr.write(result.stderr || "");
  process.exit(result.status ?? 1);
}

const bundled = readFileSync(tempFile, "utf8");
unlinkSync(tempFile);
const oneLine = bundled.replace(/\r?\n+/g, "");
writeFileSync(outFile, `${oneLine}\n`);
process.stdout.write(`${outFile}\n`);
