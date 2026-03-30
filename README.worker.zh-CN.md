# Sudoku Pure Cloudflare Worker 部署

纯 Cloudflare Worker 的 Sudoku 服务端实现。


## TODO

暂不覆盖：

- `chacha20-poly1305`
- packed downlink
- `stream/poll/auto`
- UoT / mux / reverse
- split private key 恢复成 public key

所以当前建议直接使用同一个共享 `key`，不要用依赖公私钥恢复的 split key 形态。

## 目录说明

- `cf-worker/wrangler.toml`
- `cf-worker/src/go-rand.mjs`
- `cf-worker/src/sudoku-table.mjs`
- `cf-worker/src/sudoku-protocol.mjs`
- `cf-worker/src/sudoku-config.mjs`
- `cf-worker/src/index.mjs`
- `cf-worker/tools/build-shortlink.mjs`

## 部署步骤

1. 把当前仓库推到你自己的 GitHub 仓库。
2. 在 Cloudflare 控制台进入 `Workers 和 Pages`。
3. 选择 `导入存储库`。
4. 选择这个仓库。
5. 构建根目录选 `cf-worker`。
6. 兼容性日期设为 `2026-01-20`。
7. 部署。

## 必填环境变量

| 变量名 | 示例 | 说明 |
| --- | --- | --- |
| `SUDOKU_KEY` | `my-shared-key` | 纯 Worker 版当前直接使用的共享 key |

## 推荐环境变量

| 变量名 | 示例 | 说明 |
| --- | --- | --- |
| `SUDOKU_MANAGE_TOKEN` | `my-secret` | 管理页路径令牌 |
| `SUDOKU_PUBLIC_HOST` | `sudoku.example.com` | 对外给客户端展示的域名 |
| `SUDOKU_HTTP_MASK_PATH_ROOT` | `aabbcc` | WS 路径前缀，最终入口变成 `/<path_root>/ws` |
| `SUDOKU_CLIENT_PORT` | `10233` | 导出的客户端本地 mixed 端口 |
| `SUDOKU_HTTP_MASK_HOST` | `cdn.example.com` | 可选，覆盖客户端 Host/SNI |
| `SUDOKU_NODE_NAME` | `sudoku-cf-worker-pure` | Clash 节点名 |
| `SUDOKU_AEAD` | `aes-128-gcm` | 当前建议只用这个 |
| `SUDOKU_ASCII` | `prefer_entropy` | `prefer_entropy` 或 `prefer_ascii` |
| `SUDOKU_CUSTOM_TABLE` | `xpxvvpvv` | 可选，自定义表 |

## 部署后路径

假设：

- 域名是 `sudoku.example.com`
- `SUDOKU_MANAGE_TOKEN=my-secret`
- `SUDOKU_HTTP_MASK_PATH_ROOT=aabbcc`

则：

- WS 入口：`wss://sudoku.example.com/aabbcc/ws`
- 管理页：`https://sudoku.example.com/my-secret`
- 短链接：`https://sudoku.example.com/my-secret/shortlink`
- 客户端 JSON：`https://sudoku.example.com/my-secret/client.json`
- Clash 配置：`https://sudoku.example.com/my-secret/clash.yaml`

## 本地生成短链接

```bash
node cf-worker/tools/build-shortlink.mjs \
  --host sudoku.example.com \
  --key 'my-shared-key' \
  --path-root aabbcc \
  --aead aes-128-gcm \
  --node-name sudoku-cf-worker-pure
```

