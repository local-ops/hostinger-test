import express from "express";
import { createRemoteJWKSet, jwtVerify } from "jose";

const port = Number(process.env.PORT || 3000);
const appDomain = process.env.APPS_STATIC_AUTH_DEMOS_JWT_API_DOMAIN;
const authDomain = process.env.AUTH_AUTHENTIK_DOMAIN;
const providerSlug = process.env.APPS_STATIC_AUTH_DEMOS_JWT_API_PROVIDER_SLUG;

const issuer = `https://${authDomain}/application/o/${providerSlug}/`;
const jwksUrl = new URL(`${issuer}jwks/`);
const jwks = createRemoteJWKSet(jwksUrl);

const app = express();
app.set("trust proxy", 1);

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/", (_req, res) => {
  res.type("html").send(`<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>auth-jwt-api</title></head>
<body style="font-family:system-ui;margin:2rem;background:#eceff1;color:#263238">
  <h1>auth-jwt-api</h1>
  <p><strong>protection:</strong> bearer JWT (validated in app via JWKS)</p>
  <p>Call <code>GET /api/status</code> with header <code>Authorization: Bearer &lt;access_token&gt;</code>.</p>
  <p>Issuer: <code>${escapeHtml(issuer)}</code></p>
  <p>JWKS: <code>${escapeHtml(jwksUrl.href)}</code></p>
</body>
</html>`);
});

app.get("/api/status", async (req, res) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.set("WWW-Authenticate", 'Bearer realm="auth-jwt-api"');
    return res.status(401).json({ error: "missing_bearer_token" });
  }

  const token = header.slice("Bearer ".length);
  try {
    const { payload } = await jwtVerify(token, jwks, { issuer });
    return res.json({
      service: "auth-jwt-api",
      protection: "bearer-jwt",
      sub: payload.sub,
      iss: payload.iss,
      exp: payload.exp,
    });
  } catch (err) {
    res.set("WWW-Authenticate", 'Bearer realm="auth-jwt-api"');
    return res.status(401).json({
      error: "invalid_token",
      detail: err.message,
    });
  }
});

app.listen(port, () => {
  console.log(`auth-jwt-api listening on :${port} (${appDomain})`);
});
