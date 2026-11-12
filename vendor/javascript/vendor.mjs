#!/usr/bin/env node
import { access, copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "../..");
const checkOnly = process.argv.includes("--check");

// Browser dependencies that the Ruby asset pipeline serves from
// assets/javascripts. Add an entry here when a new npm package needs to be
// vendored. `major` guards against silently replacing a file whose name and
// view references assume a specific major version.
const vendors = [
  {
    name: "d3",
    major: 7,
    source: "node_modules/d3/dist/d3.min.js",
    destination: "assets/javascripts/d3.v7.min.js",
  },
];

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

let stale = false;

for (const vendor of vendors) {
  const packageJsonPath = join(
    here,
    "node_modules",
    vendor.name,
    "package.json",
  );
  const packageJson = JSON.parse(await readFile(packageJsonPath, "utf8"));
  const major = Number.parseInt(packageJson.version.split(".")[0], 10);

  if (major !== vendor.major) {
    throw new Error(
      `${vendor.name} is v${packageJson.version}, but ${vendor.destination} expects v${vendor.major}.x. ` +
        "Update the destination filename and view references before upgrading a major version.",
    );
  }

  const source = join(here, vendor.source);
  const destination = join(repoRoot, vendor.destination);

  if (checkOnly) {
    const upToDate =
      (await exists(destination)) &&
      (await readFile(source)).equals(await readFile(destination));

    if (!upToDate) {
      console.error(`${vendor.destination} is out of date.`);
      stale = true;
    }
  } else {
    await mkdir(dirname(destination), { recursive: true });
    await copyFile(source, destination);
    console.log(
      `vendored ${vendor.name}@${packageJson.version} -> ${relative(repoRoot, destination)}`,
    );
  }
}

if (stale) {
  console.error("Run: npm --prefix vendor/javascript run vendor");
  process.exitCode = 1;
}
