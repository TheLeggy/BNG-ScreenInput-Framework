#!/usr/bin/env node

const ts = require("typescript");
const fs = require("fs");
const path = require("path");
const prettier = require("prettier");

const SRC = path.join(__dirname, "ui/modules/screenInput.ts");
const OUT = path.join(__dirname, "ui/modules/screenInput.js");

const GENERATED_FILE_HEADER = `/**
 * !!! DO NOT EDIT MANUALLY !!!
 */
`;

const { outputText } = ts.transpileModule(fs.readFileSync(SRC, "utf8"), {
  compilerOptions: {
    target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.Preserve, // a real export would ship as-is and break the script tag
  },
  fileName: "screenInput.ts",
});

(async () => {
  const js = await prettier.format(outputText, { parser: "babel" });
  fs.writeFileSync(OUT, GENERATED_FILE_HEADER + js, "utf8");
  console.log(`Built: ${OUT}`);
})();
