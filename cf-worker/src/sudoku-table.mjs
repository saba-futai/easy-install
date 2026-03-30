import { GoMathRand } from "./go-rand.mjs";

const hintPositions = buildHintPositions();
let allGridsCache;
const tableCache = new Map();

function packHintsToKey(hints) {
  const a = hints.slice();
  if (a[0] > a[1]) [a[0], a[1]] = [a[1], a[0]];
  if (a[2] > a[3]) [a[2], a[3]] = [a[3], a[2]];
  if (a[0] > a[2]) [a[0], a[2]] = [a[2], a[0]];
  if (a[1] > a[3]) [a[1], a[3]] = [a[3], a[1]];
  if (a[1] > a[2]) [a[1], a[2]] = [a[2], a[1]];
  return (((a[0] << 24) | (a[1] << 16) | (a[2] << 8) | a[3]) >>> 0);
}

function buildHintPositions() {
  const positions = [];
  for (let a = 0; a < 13; a += 1) {
    for (let b = a + 1; b < 14; b += 1) {
      for (let c = b + 1; c < 15; c += 1) {
        for (let d = c + 1; d < 16; d += 1) {
          positions.push(Uint8Array.from([a, b, c, d]));
        }
      }
    }
  }
  return positions;
}

function generateAllGrids() {
  if (allGridsCache) return allGridsCache;
  const grids = [];
  const grid = new Uint8Array(16);

  function backtrack(idx) {
    if (idx === 16) {
      grids.push(Uint8Array.from(grid));
      return;
    }
    const row = (idx / 4) | 0;
    const col = idx % 4;
    const br = ((row / 2) | 0) * 2;
    const bc = ((col / 2) | 0) * 2;
    for (let num = 1; num <= 4; num += 1) {
      let valid = true;
      for (let i = 0; i < 4; i += 1) {
        if (grid[row * 4 + i] === num || grid[i * 4 + col] === num) {
          valid = false;
          break;
        }
      }
      if (valid) {
        for (let r = 0; r < 2 && valid; r += 1) {
          for (let c = 0; c < 2; c += 1) {
            if (grid[(br + r) * 4 + bc + c] === num) {
              valid = false;
              break;
            }
          }
        }
      }
      if (valid) {
        grid[idx] = num;
        backtrack(idx + 1);
        grid[idx] = 0;
      }
    }
  }

  backtrack(0);
  allGridsCache = grids;
  return grids;
}

function hasUniqueMatch(grids, targetGrid, positions) {
  let matches = 0;
  outer: for (const grid of grids) {
    for (let i = 0; i < 4; i += 1) {
      const pos = positions[i];
      if (grid[pos] !== targetGrid[pos]) continue outer;
    }
    matches += 1;
    if (matches > 1) return false;
  }
  return matches === 1;
}

function resolveLayout(mode, customPattern) {
  const normalized = String(mode || "").trim().toLowerCase();
  if (normalized === "ascii" || normalized === "prefer_ascii") {
    const paddingPool = [];
    for (let i = 0; i < 32; i += 1) paddingPool.push(0x20 + i);
    return {
      name: "ascii",
      paddingPool: Uint8Array.from(paddingPool),
      isHint(b) {
        return (b & 0x40) === 0x40 || b === 0x0a;
      },
      encodeHint(val, pos) {
        const b = 0x40 | ((val & 0x03) << 4) | (pos & 0x0f);
        return b === 0x7f ? 0x0a : b;
      },
    };
  }

  if (String(customPattern || "").trim()) {
    return buildCustomLayout(customPattern);
  }

  return {
    name: "entropy",
    paddingPool: Uint8Array.from([0x80, 0x10, 0x81, 0x11, 0x82, 0x12, 0x83, 0x13, 0x84, 0x14, 0x85, 0x15, 0x86, 0x16, 0x87, 0x17]),
    isHint(b) {
      return (b & 0x90) === 0;
    },
    encodeHint(val, pos) {
      return ((val & 0x03) << 5) | (pos & 0x0f);
    },
  };
}

function buildCustomLayout(pattern) {
  const cleaned = String(pattern).trim().replaceAll(" ", "").toLowerCase();
  if (cleaned.length !== 8) throw new Error("custom table must have 8 symbols");
  const xBits = [];
  const pBits = [];
  const vBits = [];
  for (let i = 0; i < cleaned.length; i += 1) {
    const bit = 7 - i;
    const ch = cleaned[i];
    if (ch === "x") xBits.push(bit);
    else if (ch === "p") pBits.push(bit);
    else if (ch === "v") vBits.push(bit);
    else throw new Error(`invalid custom table char: ${ch}`);
  }
  if (xBits.length !== 2 || pBits.length !== 2 || vBits.length !== 4) {
    throw new Error("custom table must contain exactly 2 x, 2 p, 4 v");
  }
  const xMask = xBits.reduce((acc, bit) => acc | (1 << bit), 0);
  const encodeBits = (val, pos, dropX = -1) => {
    let out = xMask;
    if (dropX >= 0) out &= ~(1 << xBits[dropX]);
    if (val & 0x02) out |= (1 << pBits[0]);
    if (val & 0x01) out |= (1 << pBits[1]);
    for (let i = 0; i < 4; i += 1) {
      if ((pos >> (3 - i)) & 1) out |= (1 << vBits[i]);
    }
    return out;
  };
  const paddingPool = [];
  const seen = new Set();
  for (let drop = 0; drop < xBits.length; drop += 1) {
    for (let val = 0; val < 4; val += 1) {
      for (let pos = 0; pos < 16; pos += 1) {
        const b = encodeBits(val, pos, drop);
        const ones = b.toString(2).replaceAll("0", "").length;
        if (ones >= 5 && !seen.has(b)) {
          seen.add(b);
          paddingPool.push(b);
        }
      }
    }
  }
  paddingPool.sort((a, b) => a - b);
  return {
    name: `custom(${cleaned})`,
    paddingPool: Uint8Array.from(paddingPool),
    isHint(b) {
      return (b & xMask) === xMask;
    },
    encodeHint(val, pos) {
      return encodeBits(val, pos, -1);
    },
  };
}

async function seedFromKey(key) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key)));
  let value = 0n;
  for (let i = 0; i < 8; i += 1) value = (value << 8n) | BigInt(digest[i]);
  return BigInt.asIntN(64, value);
}

export async function buildSudokuTable(key, mode = "prefer_entropy", customPattern = "") {
  const cacheKey = JSON.stringify([key, mode, customPattern]);
  if (tableCache.has(cacheKey)) return tableCache.get(cacheKey);

  const promise = (async () => {
    const layout = resolveLayout(mode, customPattern);
    const grids = generateAllGrids();
    const shuffled = grids.slice();
    const rng = new GoMathRand(await seedFromKey(key));
    rng.shuffle(shuffled.length, (i, j) => {
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    });

    const encodeTable = Array.from({ length: 256 }, () => []);
    const decodeMap = new Map();

    for (let byteVal = 0; byteVal < 256; byteVal += 1) {
      const targetGrid = shuffled[byteVal];
      for (const positions of hintPositions) {
        if (!hasUniqueMatch(grids, targetGrid, positions)) continue;
        const hints = new Uint8Array(4);
        for (let i = 0; i < 4; i += 1) {
          const pos = positions[i];
          hints[i] = layout.encodeHint(targetGrid[pos] - 1, pos);
        }
        encodeTable[byteVal].push(hints);
        decodeMap.set(packHintsToKey(hints), byteVal);
      }
      if (encodeTable[byteVal].length === 0) {
        throw new Error(`empty Sudoku encode table for byte ${byteVal}`);
      }
    }

    return {
      encodeTable,
      decodeMap,
      paddingPool: layout.paddingPool,
      isHint: layout.isHint,
    };
  })();

  tableCache.set(cacheKey, promise);
  return promise;
}

export function decodeSudokuBytes(table, state, chunk) {
  const out = [];
  for (const b of chunk) {
    if (!table.isHint(b)) continue;
    state.hintBuf.push(b);
    if (state.hintBuf.length === 4) {
      const key = packHintsToKey(state.hintBuf);
      const value = table.decodeMap.get(key);
      if (value === undefined) {
        throw new Error("INVALID_SUDOKU_MAP_MISS");
      }
      out.push(value);
      state.hintBuf.length = 0;
    }
  }
  return Uint8Array.from(out);
}

export function encodeSudokuBytes(table, bytes) {
  const out = [];
  for (const b of bytes) {
    const hints = table.encodeTable[b][0];
    out.push(hints[0], hints[1], hints[2], hints[3]);
  }
  return Uint8Array.from(out);
}

export function newSudokuDecodeState() {
  return { hintBuf: [] };
}
