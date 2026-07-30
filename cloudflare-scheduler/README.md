# hiwd data scheduler

Cloudflare Workers Cron triggers the existing `Update All Data` GitHub Actions
workflow on weekday market hours. It deliberately has no public route or domain
binding, so it never sits on the `data.hiwd.com` request path.

## One-time secret setup

Create a GitHub fine-grained personal access token scoped only to `hiwdx/data`,
with **Actions: Read and write**. Then run this from this directory:

```sh
/Users/andrew/Documents/claudecode/cf-worker/node_modules/.bin/wrangler secret put GITHUB_TOKEN
```

Paste the token only into the terminal prompt. It is stored by Cloudflare as a
secret and must not be committed or added to `.dev.vars`.

## Deploy

```sh
/Users/andrew/Documents/claudecode/cf-worker/node_modules/.bin/wrangler deploy
```

## Verify

```sh
/Users/andrew/Documents/claudecode/cf-worker/node_modules/.bin/wrangler triggers
```
