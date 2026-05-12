#!/usr/bin/env node
/**
 * Strips TS syntax from ui/modules/screenInput.ts when making screenInput.js
 * Tag a top-level statement with @tsExclusive (in a comment above it) to drop
 * it and its window.NAME = NAME export from the output.
 */

const ts = require("typescript");
const fs = require("fs");
const path = require("path");
const prettier = require("prettier");

const SRC = path.join(__dirname, "ui/modules/screenInput.ts");
const OUT = path.join(__dirname, "ui/modules/screenInput.js");

const GENERATED_FILE_HEADER = `/**
 * !!! DO NOT EDIT MANUALLY !!!
 *
 * sneppy snep snep!
 *
 * Be warned (!!!!): using this code means you give
 *     away your soul to the snow leopard gods!
 *
 * Translates BeamNG coordinate events to browser-like events
 *
 * Part of the screenInput framework - makes vehicle HTML displays actually usable
 * by converting 3D raycasts into standard DOM events. Effectively allows the HTML
 * to treat coordinate input as if it was running on a tablet, but also provides
 * the flexibility to handle more complex interactions when needed.
 */
`;

const srcText = fs.readFileSync(SRC, "utf8");

function isTaggedExclusive(node, sourceFile) {
  const fullText = sourceFile.getFullText();
  const ranges = ts.getLeadingCommentRanges(fullText, node.getFullStart());
  return (
    ranges?.some((r) =>
      fullText.slice(r.pos, r.end).includes("@tsExclusive"),
    ) ?? false
  );
}

function getDeclaredName(node) {
  if (ts.isFunctionDeclaration(node) || ts.isClassDeclaration(node))
    return node.name?.text;
  if (ts.isVariableStatement(node)) {
    const decls = node.declarationList.declarations;
    if (decls.length === 1 && ts.isIdentifier(decls[0].name))
      return decls[0].name.text;
  }
}

// (window as any).NAME = NAME  or  window.NAME = NAME
function isWindowExportOf(node, name) {
  if (!ts.isExpressionStatement(node)) return false;
  const expr = node.expression;
  return (
    ts.isBinaryExpression(expr) &&
    expr.operatorToken.kind === ts.SyntaxKind.EqualsToken &&
    ts.isIdentifier(expr.right) &&
    expr.right.text === name &&
    ts.isPropertyAccessExpression(expr.left) &&
    expr.left.name.text === name
  );
}

function stripTypesTransformer(context) {
  return (sourceFile) => {
    const exclusiveNames = new Set(
      sourceFile.statements
        .filter((s) => isTaggedExclusive(s, sourceFile))
        .map((s) => getDeclaredName(s))
        .filter(Boolean),
    );

    function visitTopLevel(node) {
      if (isTaggedExclusive(node, sourceFile)) return undefined;
      if (ts.isInterfaceDeclaration(node) || ts.isTypeAliasDeclaration(node))
        return undefined;
      for (const name of exclusiveNames)
        if (isWindowExportOf(node, name)) return undefined;
      return visitDeep(node);
    }

    function visitDeep(node) {
      if (ts.canHaveModifiers?.(node)) {
        const mods = ts.getModifiers?.(node) ?? node.modifiers;
        if (mods?.some((m) => m.kind === ts.SyntaxKind.ExportKeyword)) {
          return ts.factory.updateModifiers(
            node,
            mods.filter((m) => m.kind !== ts.SyntaxKind.ExportKeyword),
          );
        }
      }
      return ts.visitEachChild(node, visitDeep, context);
    }

    return ts.visitEachChild(sourceFile, visitTopLevel, context);
  };
}

const result = ts.transpileModule(srcText, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.None,
    removeComments: false,
    useDefineForClassFields: false,
  },
  transformers: { before: [stripTypesTransformer] },
  fileName: "screenInput.ts",
});

let js = result.outputText;

// Clean up transpileModule artifacts
js = js.replace(/\/\/# sourceMappingURL=.*\n?$/, "");
js = js.replace(/^"use strict";\s*/m, "");
js = js.replace(
  /^Object\.defineProperty\(exports,\s*"__esModule"[^;]*;\s*\n?/m,
  "",
);
js = js.replace(/^\/\/\/\s*<reference[^>]*\/>\s*\n/gm, "");

(async () => {
  js = await prettier.format(js, { parser: "babel", tabWidth: 2 });
  js = GENERATED_FILE_HEADER + js;
  fs.writeFileSync(OUT, js, "utf8");
  console.log(`Built: ${OUT}`);
})();
