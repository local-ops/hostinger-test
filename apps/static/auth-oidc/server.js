import express from "express";
import session from "cookie-session";
import * as client from "openid-client";

const port = Number(process.env.PORT || 3000);
const appDomain = process.env.APPS_STATIC_AUTH_DEMOS_OIDC_DOMAIN;
const authDomain = process.env.AUTH_AUTHENTIK_DOMAIN;
const providerSlug = process.env.APPS_STATIC_AUTH_DEMOS_OIDC_PROVIDER_SLUG;
const clientId = process.env.APPS_STATIC_AUTH_DEMOS_OIDC_CLIENT_ID;
const clientSecret = process.env.APPS_STATIC_AUTH_DEMOS_OIDC_CLIENT_SECRET;
const sessionSecret = process.env.APPS_STATIC_AUTH_DEMOS_OIDC_SESSION_SECRET;

const baseUrl = `https://${appDomain}`;
const issuerUrl = new URL(
  `https://${authDomain}/application/o/${providerSlug}/`,
);

let oidcConfig;

const app = express();
app.set("trust proxy", 1);
app.use(
  session({
    name: "auth_oidc_sess",
    keys: [sessionSecret],
    maxAge: 24 * 60 * 60 * 1000,
    httpOnly: true,
    secure: true,
    sameSite: "lax",
  }),
);

async function getOidcConfig() {
  if (!oidcConfig) {
    oidcConfig = await client.discovery(issuerUrl, clientId, clientSecret);
  }
  return oidcConfig;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function renderPage(title, body) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; background: #f3e5f5; color: #4a148c; }
    pre { background: #fff; padding: 1rem; border-radius: 6px; overflow: auto; }
    a { color: #6a1b9a; }
  </style>
</head>
<body>
  <h1>auth-oidc</h1>
  <p><strong>protection:</strong> native OIDC (app is OAuth client)</p>
  ${body}
</body>
</html>`;
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/", async (req, res) => {
  if (!req.session?.claims) {
    return res.redirect("/login");
  }
  const claimsJson = JSON.stringify(req.session.claims, null, 2);
  res
    .type("html")
    .send(
      renderPage(
        "auth-oidc",
        `<p>Logged in. <a href="/logout">Logout</a></p><pre>${escapeHtml(claimsJson)}</pre>`,
      ),
    );
});

app.get("/login", async (req, res) => {
  const config = await getOidcConfig();
  const codeVerifier = client.randomPKCECodeVerifier();
  const codeChallenge = await client.calculatePKCECodeChallenge(codeVerifier);
  const state = client.randomState();

  req.session.codeVerifier = codeVerifier;
  req.session.oauthState = state;

  const redirectTo = client.buildAuthorizationUrl(config, {
    redirect_uri: `${baseUrl}/callback`,
    scope: "openid profile email",
    code_challenge: codeChallenge,
    code_challenge_method: "S256",
    state,
  });

  res.redirect(redirectTo.href);
});

app.get("/callback", async (req, res) => {
  try {
    const config = await getOidcConfig();
    const currentUrl = new URL(`${baseUrl}${req.originalUrl}`);

    const tokens = await client.authorizationCodeGrant(config, currentUrl, {
      pkceCodeVerifier: req.session.codeVerifier,
      expectedState: req.session.oauthState,
    });

    const claims = tokens.claims();
    req.session.claims = claims;
    delete req.session.codeVerifier;
    delete req.session.oauthState;

    res.redirect("/");
  } catch (err) {
    res
      .status(400)
      .type("html")
      .send(
        renderPage(
          "auth-oidc — error",
          `<p>OIDC callback failed.</p><pre>${escapeHtml(err.message)}</pre><p><a href="/login">Try again</a></p>`,
        ),
      );
  }
});

app.get("/logout", (req, res) => {
  req.session = null;
  res.redirect("/");
});

app.listen(port, () => {
  console.log(`auth-oidc listening on :${port} (${appDomain})`);
});
