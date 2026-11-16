// Serves `frontend/public` for a local check: `node frontend/tools/preview.mjs`.
// It is not a deployment: GitHub Pages publishes the same folder.

import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("../public", import.meta.url)));
const PORT = Number(process.env.PORT ?? 4173);

const TYPES = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".ico", "image/x-icon"],
  [".txt", "text/plain; charset=utf-8"],
  [".wasm", "application/wasm"],
  [".zip", "application/zip"],
]);

function pathOf(url) {
  const pathname = decodeURIComponent(new URL(url ?? "/", "http://localhost").pathname);
  const relative = normalize(pathname).replace(/^([/\\])+/, "");
  if (relative.startsWith("..")) return null;
  return join(ROOT, relative === "" ? "index.html" : relative);
}

createServer((request, response) => {
  const file = pathOf(request.url);
  if (!file) {
    response.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
    response.end("bad path\n");
    return;
  }
  let path = file;
  try {
    if (statSync(path).isDirectory()) path = join(path, "index.html");
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("not found\n");
    return;
  }
  try {
    const info = statSync(path);
    if (!info.isFile()) throw new Error("not a file");
    response.writeHead(200, {
      "content-type": TYPES.get(extname(path)) ?? "application/octet-stream",
      "content-length": info.size,
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    });
    createReadStream(path).pipe(response);
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("not found\n");
  }
}).listen(PORT, "127.0.0.1", () => {
  console.log(`site: http://127.0.0.1:${PORT}/`);
  console.log("config.js must point workerBase at a running worker (wrangler dev).");
});
