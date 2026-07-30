const GITHUB_API_VERSION = "2022-11-28";
const MAX_ATTEMPTS = 3;
const RETRY_DELAY_MS = 1_500;

/**
 * Cron-only Worker. `GITHUB_TOKEN` is a Cloudflare secret, never source code.
 * The token needs fine-grained access to hiwdx/data with Actions: Read and write.
 */
export default {
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(dispatchUpdate(env));
  },

  async fetch() {
    return new Response("Not found", { status: 404 });
  },
};

async function dispatchUpdate(env) {
  if (!env.GITHUB_TOKEN) {
    throw new Error("GITHUB_TOKEN secret is not configured");
  }

  const url = `https://api.github.com/repos/${env.GITHUB_REPO}/actions/workflows/${env.GITHUB_WORKFLOW}/dispatches`;
  let lastError;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/vnd.github+json",
          Authorization: `Bearer ${env.GITHUB_TOKEN}`,
          "Content-Type": "application/json",
          "User-Agent": "hiwd-data-scheduler",
          "X-GitHub-Api-Version": GITHUB_API_VERSION,
        },
        body: JSON.stringify({ ref: env.GITHUB_REF }),
      });

      // GitHub returns 204 when it has accepted the workflow dispatch.
      if (response.status === 204) {
        console.log(`GitHub update workflow accepted (attempt ${attempt}).`);
        return;
      }

      const detail = (await response.text()).slice(0, 500);
      // Permission and request errors need human attention; retrying them only
      // creates duplicate noise. Transient GitHub errors are retried below.
      if (response.status < 500 && response.status !== 429) {
        const error = new Error(`GitHub workflow dispatch failed (${response.status}): ${detail}`);
        error.retryable = false;
        throw error;
      }
      lastError = new Error(`GitHub workflow dispatch transient failure (${response.status}): ${detail}`);
    } catch (error) {
      lastError = error;
    }

    if (lastError?.retryable === false) {
      throw lastError;
    }

    if (attempt < MAX_ATTEMPTS) {
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS * attempt));
    }
  }

  throw lastError;
}
