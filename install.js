#!/usr/bin/env node

"use strict";

const { execFile } = require("node:child_process");
const { createWriteStream, mkdtempSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const { Readable } = require("node:stream");
const { pipeline } = require("node:stream/promises");
const pkg = require("./package.json");

async function main() {
  if (process.platform !== "darwin" || process.arch !== "arm64") {
    throw new Error("Seahorse currently requires an Apple Silicon Mac.");
  }

  const fileName = `Seahorse-${pkg.version}.dmg`;
  const downloadURL = `https://github.com/SSBun/Seahorse/releases/download/v${pkg.version}/${fileName}`;
  const destination = join(mkdtempSync(join(tmpdir(), "Seahorse-")), fileName);

  console.log(`Downloading Seahorse ${pkg.version}...`);
  const response = await fetch(downloadURL);
  if (!response.ok || !response.body) {
    throw new Error(`Download failed: ${response.status} ${downloadURL}`);
  }

  await pipeline(Readable.fromWeb(response.body), createWriteStream(destination));
  await new Promise((resolve, reject) => {
    execFile("open", [destination], (error) => error ? reject(error) : resolve());
  });
  console.log("DMG opened. Drag Seahorse to Applications.");
}

main().catch((error) => {
  console.error(`Unable to install Seahorse: ${error.message}`);
  process.exitCode = 1;
});
