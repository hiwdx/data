const GITHUB_API_VERSION = "2022-11-28";

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

  const response = await fetch(
    `https://api.github.com/repos/${env.GITHUB_REPO}/actions/workflows/${env.GITHUB_WORKFLOW}/dispatches`,
    {
      method: "POST",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        "User-Agent": "hiwd-data-scheduler",
        "X-GitHub-Api-Version": GITHUB_API_VERSION,
      },
      body: JSON.stringify({ ref: env.GITHUB_REF }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `GitHub workflow dispatch failed (${response.status}): ${await response.text()}`,
    );
  }
}
