// TypeScript JIT runtime

// Load sucrase.js BEFORE this script, then include this script before any TS
// Handles <script type="text/typescript"> tags and exposes loadTS(url) for external .ts files

(function () {
  function compile(src) {
    return sucrase.transform(src, { transforms: ["typescript", "imports"] }).code;
  }

  function execScript(code, src) {
    try {
      // shim CommonJS globals so exports land on window
      var mod = { exports: {} };
      var require = function (id) { return window[id] || {}; };
      // eslint-disable-next-line no-new-func
      new Function("module", "exports", "require", code)(mod, mod.exports, require);
      Object.assign(window, mod.exports);
    } catch (e) {
      console.error("[tsRuntime] Error executing" + (src ? " " + src : "") + ":", e);
    }
  }

  // process all <script type="text/typescript"> already in the document
  function processInlineScripts() {
    document.querySelectorAll('script[type="text/typescript"]').forEach(function (el) {
      execScript(compile(el.textContent));
    });
  }

  // fetch and execute an external .ts file, returns a Promise
  window.loadTS = function (url) {
    return fetch(url)
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status + " loading " + url);
        return r.text();
      })
      .then(function (src) {
        execScript(compile(src), url);
      })
      .catch(function (e) {
        console.error("[tsRuntime] Failed to load " + url + ":", e);
      });
  };

  // run after DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", processInlineScripts);
  } else {
    processInlineScripts();
  }
})();
