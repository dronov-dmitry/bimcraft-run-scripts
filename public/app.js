// The page reads the release channel from the worker and renders it. It never builds HTML
// from the response: every value goes in as text, so a compromised channel cannot run
// script here.

(() => {
  "use strict";

  const config = window.BIMCRAFT_DELIVERY || {};
  const workerBase = String(config.workerBase || "").replace(/\/+$/, "");
  const repository = String(config.repository || "");
  const configured = /^https?:\/\/[^/]+/.test(workerBase) && !workerBase.includes(".example.");

  const state = { channel: null, version: null, os: detectOs() };

  function el(id) {
    return document.getElementById(id);
  }

  function detectOs() {
    const agent = navigator.userAgent || "";
    if (/Windows/i.test(agent)) return "windows";
    if (/Mac OS X|Macintosh/i.test(agent)) return "macos";
    return "linux";
  }

  function setStatus(text) {
    const node = el("status");
    if (node) node.textContent = text;
  }

  function show(node) {
    if (node) node.hidden = false;
  }

  function hide(node) {
    if (node) node.hidden = true;
  }

  async function fetchChannel() {
    if (!configured) return { error: "not-configured" };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(`${workerBase}/v1/manifest.json`, {
        signal: controller.signal,
        headers: { accept: "application/json" },
      });
      if (!response.ok) return { error: `status ${response.status}` };
      const channel = await response.json();
      if (!channel || !Array.isArray(channel.versions)) return { error: "unexpected manifest" };
      return { channel };
    } catch (error) {
      return { error: error instanceof Error ? error.name : String(error) };
    } finally {
      clearTimeout(timer);
    }
  }

  function humanSize(bytes) {
    if (!Number.isFinite(bytes) || bytes <= 0) return "";
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KiB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
  }

  function releaseOf(version) {
    const channel = state.channel;
    if (!channel) return null;
    return channel.versions.find((release) => release.version === version) || null;
  }

  function commandFor(os, version) {
    if (os === "windows") {
      return `iwr -useb ${workerBase}/v1/install.ps1?v=${version} | iex`;
    }
    return `curl -fsSL ${workerBase}/v1/install.sh?v=${version} | bash`;
  }

  function hintFor(os) {
    return os === "windows" ? "Run this in PowerShell." : "Run this in a terminal.";
  }

  function fillVersions(channel) {
    const select = el("version-select");
    if (!select) return;
    select.textContent = "";
    for (const release of channel.versions) {
      const option = document.createElement("option");
      option.value = release.version;
      option.textContent = release.version === channel.latest ? `${release.version} (latest)` : release.version;
      select.append(option);
    }
  }

  function updateCommand() {
    const command = el("command");
    const hint = el("command-hint");
    if (!command || !state.version) return;
    command.textContent = commandFor(state.os, state.version);
    if (hint) hint.textContent = hintFor(state.os);
  }

  function setOs(os) {
    state.os = os;
    for (const button of document.querySelectorAll(".tabs button")) {
      const selected = button.dataset.os === os;
      button.setAttribute("aria-selected", selected ? "true" : "false");
      button.tabIndex = selected ? 0 : -1;
    }
    const panel = el("panel-install");
    if (panel) panel.setAttribute("aria-labelledby", `tab-${os}`);
    updateCommand();
  }

  function selectVersion(version) {
    if (!state.channel || !version) return;
    const release = releaseOf(version);
    if (!release) return;
    state.version = version;

    const select = el("version-select");
    if (select) select.value = version;

    const versionNode = el("release-version");
    if (versionNode) versionNode.textContent = `version ${release.version}`;

    const dateNode = el("release-date");
    if (dateNode) dateNode.textContent = release.released ? `released ${release.released}` : "";

    const download = el("download-link");
    if (download) download.href = `${workerBase}/v1/download/${encodeURIComponent(release.version)}`;

    const size = el("size");
    if (size) size.textContent = humanSize(release.asset && release.asset.size);

    const digest = el("digest");
    if (digest) digest.textContent = release.asset ? release.asset.sha256 : "";

    const notes = el("notes");
    const notesBox = el("notes-box");
    if (notes && notesBox) {
      const text = (release.notes || "").trim();
      notes.textContent = text;
      notesBox.hidden = text.length === 0;
    }

    updateCommand();
  }

  function render(result) {
    if (!configured) {
      setStatus("The delivery service address is not configured yet.");
      show(el("setup"));
      return;
    }
    if (result.error) {
      setStatus("The release channel is unreachable.");
      const link = el("offline-link");
      if (link) link.href = repository || "#";
      show(el("offline"));
      return;
    }

    const channel = result.channel;
    if (!channel || !Array.isArray(channel.versions) || channel.versions.length === 0) {
      setStatus("The delivery service is running; no build is published yet.");
      show(el("empty"));
      return;
    }

    state.channel = channel;
    fillVersions(channel);
    show(el("release"));
    selectVersion(channel.latest || channel.versions[0].version);
    setOs(state.os);
    setStatus(`${channel.versions.length} build${channel.versions.length === 1 ? "" : "s"} published · ABI ${channel.plugin.abi}`);
  }

  function flash(button, label) {
    if (!button) return;
    const original = button.textContent;
    button.textContent = label;
    setTimeout(() => {
      button.textContent = original;
    }, 1600);
  }

  async function copyText(text, button) {
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      flash(button, "Copied");
    } catch {
      flash(button, "Select and copy");
    }
  }

  function wire() {
    const select = el("version-select");
    if (select) select.addEventListener("change", () => selectVersion(select.value));

    for (const button of document.querySelectorAll(".tabs button")) {
      button.addEventListener("click", () => setOs(button.dataset.os || "linux"));
      button.addEventListener("keydown", (event) => {
        if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
        event.preventDefault();
        const order = ["linux", "macos", "windows"];
        const at = order.indexOf(state.os);
        const step = event.key === "ArrowRight" ? 1 : order.length - 1;
        const next = order[(at + step) % order.length];
        setOs(next);
        const node = el(`tab-${next}`);
        if (node) node.focus();
      });
    }

    const copyCommand = el("copy-command");
    if (copyCommand) {
      copyCommand.addEventListener("click", () => {
        const command = el("command");
        copyText(command ? command.textContent || "" : "", copyCommand);
      });
    }

    const copyDigest = el("copy-digest");
    if (copyDigest) {
      copyDigest.addEventListener("click", () => {
        const digest = el("digest");
        copyText(digest ? digest.textContent || "" : "", copyDigest);
      });
    }

    const repoLink = el("repo-link");
    if (repoLink) repoLink.href = repository || "#";

    const healthLink = el("health-link");
    if (healthLink) healthLink.href = configured ? `${workerBase}/v1/health` : "#";
  }

  function start() {
    wire();
    setOs(state.os);
    fetchChannel().then(render);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
