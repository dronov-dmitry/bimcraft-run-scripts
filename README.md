# BIMCraft Scripts

**English** · [Русский](README_RU.md)

**BIMCraft Scripts** is a BIMCraft plugin that runs small scripts inside the
application and saves you repetitive manual work.

- Install page: <https://dronov-dmitry.github.io/bimcraft-run-scripts/>
- Installation is one command — see "Installation" below.

The first part of this file is for users, the second for whoever publishes the page.

---

# Part 1. For users

## What it gives you

A script does for you what you usually repeat by hand.

- **Less manual work.** One run instead of dozens of identical actions: walk through
  elements, pick the ones you need, count, call commands when a condition holds.
- **Summaries and calculations over your model.** The script collects data, adds it up
  and writes the result to the plugin log, where you read it.
- **The same result for the same data.** A saved script can be run again and again — it
  does not depend on the clock, randomness or machine settings.
- **Safe to use.** The script runs inside BIMCraft in a restricted environment: it has no
  access to the internet or files, and its memory and time are limited. A script error
  stops only that run and shows what went wrong and where; the application keeps working.

The plugin installs with one command, works right after BIMCraft restarts and needs no
setup.

## What it looks like in practice

Say you regularly need a summary of model elements: how many there are, which values they
carry, what changed since last time. Instead of walking through them by hand you run your
script — it goes through the data, adds it up and writes the finished summary to the log.
Next time you just run it again.

## Installation

1. Open the page <https://dronov-dmitry.github.io/bimcraft-run-scripts/>.
2. Pick your system — Linux, macOS or Windows — and copy the command.
3. Paste it into a terminal and press Enter.
4. Confirm the installation and restart BIMCraft.

**Linux and macOS:**

```bash
curl -fsSL https://dronov-dmitry.github.io/bimcraft-run-scripts/install.sh | bash
```

**Windows (PowerShell):**

```powershell
iwr -useb https://dronov-dmitry.github.io/bimcraft-run-scripts/install.ps1 | iex
```

The scripts live on the page itself: installation does not depend on a separate service.
A pinned version has its own path — `.../v1/0.1.0/install.sh`; the page substitutes it
when you pick a version from the list.

When the installer asks, Enter alone accepts the default answer, yes.

The installer downloads the plugin, checks that the file arrived complete and undamaged,
and puts it into the right folder. If the plugin was already installed, the previous
version is not deleted: it is set aside next to it, so you can go back to it.

BIMCraft plugins are not signed by a publisher: the integrity check protects against a
broken download but does not confirm the author. Install the plugin only from a page you
trust, as with any other plugin.

Where the plugin goes:

| System | Folder |
|---|---|
| Linux | `~/.config/bimcraft/plugins` |
| macOS | `~/Library/Application Support/BIMCraft/plugins` |
| Windows | `%APPDATA%\BIMCraft\plugins` |

If you keep plugins elsewhere, set the folder in the `BIMCRAFT_PLUGINS` variable before
running the command.

## Getting started

After the restart, open **Manage → Plugins**. The list shows **BIMCraft Scripts** with
two actions:

- **Project Report** — show what the open project holds: name, units, levels, element
  counts by category, warnings and the library size;
- **Run Script** — run the script;
- **Check Script** — check the script without running anything (useful before a run).

The result goes to the plugin log, which also shows where the script stopped if something
went wrong.

## Updating and removing

- **Update** — the same install command as the first time. The page always offers the
  current version; the previous one stays next to it as a backup.
- **Disable** — in **Manage → Plugins**.
- **Remove** — delete the plugin folder from the plugins folder (you may keep or delete
  the backups).

## If something went wrong

- **The plugin is not in the list** — check that the installation finished without errors
  and that BIMCraft was restarted.
- **The plugin is listed but marked as refused** — the reason is shown next to it and in
  the log; usually it is a BIMCraft version the plugin does not support.
- **The script stopped with a message** — the message says what is wrong and where in the
  script; fix it and run again. The model was not affected.

---

# Part 2. For whoever publishes the page

The folder is self-contained for publishing on **GitHub Pages**: static files, no build,
no dependencies and no Node.js. **It is the root of the git repository for GitHub**:
`scripts/publish-pages.py` initializes the repository here, not in `delivery/`, so the
backend and the root files never reach GitHub.

```
frontend/            ← the git repository root; only this folder goes to GitHub
  public/            ← the GitHub Pages artifact, published as is
    index.html
    404.html         GitHub Pages serves it for addresses that do not exist
    styles.css
    app.js           reads manifest.json next to the page
    config.js        repository link; written by scripts/build-site.py
    manifest.json    the release channel; written by scripts/build-site.py
    install.sh       the installer of the latest version; written by scripts/build-site.py
    install.ps1
    v1/<version>/    installers of pinned versions; written by scripts/build-site.py
    favicon.svg
    robots.txt
    .nojekyll        turns off Jekyll processing
  tools/preview.mjs  local preview; not published
  .github/workflows/ pages.yml — the only workflow of the repository
  README.md          README_RU.md — the English and the Russian texts
```

## How it is published

The delivery files are built before publication: `scripts/build-site.sh` reads the channel
and the templates and rewrites `manifest.json`, `install.sh`, `install.ps1`, `v1/**` and
`config.js`.

`.github/workflows/pages.yml` in this folder, on every push to `main` that touches
`public/**`:

1. checks that `public/` holds the required files and no development files;
2. uploads `public/` as the Pages artifact;
3. deploys.

The repository settings must say **Settings → Pages → Source: GitHub Actions**.
`scripts/publish-pages.py` turns this on through `gh api` when `gh` is authorized.

The project address is `https://<owner>.github.io/<repo>/`. Every link in the page is
**relative** — otherwise on project pages it would go to the domain root and return 404.

The delivery is static: `manifest.json`, the installers and `config.js` are built by
`scripts/build-site.py` and published by `scripts/publish-pages.sh`. The Worker is not in
this repository and takes no part in the installation; Cloudflare is kept for the user
database that will come later.

## Local preview

```bash
pnpm frontend:dev      # from delivery/, http://127.0.0.1:4173
```

To check against a local backend, set `workerBase: "http://127.0.0.1:8787"` in
`public/config.js` and run `pnpm backend:dev`. The page understands both `http` and
`https`.

## `config.js`

The repository link for the page footer:

```js
window.BIMCRAFT_DELIVERY = {
  repository: "https://github.com/<owner>/<repo>",
};
```

`scripts/build-site.py` writes it. The page needs no backend address: it reads versions
and the digest from `manifest.json` next to it, and the installers from `v1/<version>/`.

## Rules

- Generated files (`manifest.json`, `install.sh`, `install.ps1`, `config.js`, `v1/**`) are
  not edited by hand: `scripts/build-site.py` writes them from `releases.json`.
- Do not add here: Node code, a build, `node_modules`, source maps, secrets or addresses
  that must not be published.
- No absolute paths (`/styles.css`): the site lives in a subfolder.
- Data from the network is rendered only through `textContent` — `app.js` never builds
  HTML from the backend's answer.
- Deployment scripts live **outside** this folder: `../../scripts/`.

## Custom domain

1. Put `CNAME` in `public/` with a single domain on the first line.
2. Configure DNS at the registrar (for an apex — `A`/`AAAA` to the GitHub Pages addresses,
   for a subdomain — `CNAME` to `<owner>.github.io`).
3. **Settings → Pages → Custom domain**, turn on HTTPS.

The `CNAME` file is published with the site; without a configured domain it must not be
added.

## Checklist before publishing

- [ ] `public/index.html`, `public/404.html` and `public/config.js` are not empty;
- [ ] `config.js` holds a real backend address, not `example.workers.dev`;
- [ ] `public/` has no `.map`, `node_modules` or `.ts`;
- [ ] the links are relative;
- [ ] `404.html` opens and leads to `./`;
- [ ] the page is readable in the dark and the light theme (colors through
  `prefers-color-scheme`).
