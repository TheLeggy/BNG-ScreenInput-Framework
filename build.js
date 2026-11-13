#!/usr/bin/env node

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const prettier = require("prettier");

const OUT = path.join(__dirname, "ui/modules/screenInput.js");
const TSC = path.join(
  path.dirname(require.resolve("typescript/package.json")),
  "bin/tsc",
);

const GENERATED_FILE_HEADER = `/**
 * !!! DO NOT EDIT MANUALLY !!!
 */
`;

execFileSync(
  process.execPath,
  [TSC, "-p", path.join(__dirname, "tsconfig.build.json")],
  {
    stdio: "inherit",
  },
);

(async () => {
  const js = await prettier.format(fs.readFileSync(OUT, "utf8"), {
    parser: "babel",
  });
  fs.writeFileSync(OUT, GENERATED_FILE_HEADER + js, "utf8");
  console.log(`Built: ${OUT}`);
})();
