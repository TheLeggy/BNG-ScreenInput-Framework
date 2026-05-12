// TypeScript JIT runtime

// Load sucrase.js BEFORE this script, then include this script before any TS
// Handles <script type="text/typescript"> tags and exposes loadTS(url) for external .ts files

(function () {
  var moduleCache = {};

  function compile(src) {
    return sucrase.transform(src, { transforms: ["typescript", "imports"] })
      .code;
  }

  // resolve a relative require id against the url of the requiring module
  function resolveUrl(id, fromUrl) {
    if (!fromUrl) return id;
    var base = fromUrl.substring(0, fromUrl.lastIndexOf("/") + 1);
    var parts = (base + id).split("/");
    var resolved = [];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] === "..") {
        resolved.pop();
      } else if (parts[i] !== ".") {
        resolved.push(parts[i]);
      }
    }
    return resolved.join("/");
  }

  // extract relative require ids from compiled JS source
  function scanRequires(code) {
    var ids = [];
    var re = /require\(["'](\.\.?\/[^"']+)["']\)/g;
    var m;
    while ((m = re.exec(code)) !== null) {
      ids.push(m[1]);
    }
    return ids;
  }

  // execute compiled code with a module-scoped require bound to fromUrl
  function execModule(code, mod, fromUrl) {
    var require = function (id) {
      if (id.charAt(0) === ".") {
        var abs = resolveUrl(id, fromUrl);
        var cached = moduleCache[abs];
        if (!cached) {
          throw new Error(
            "[tsRuntime] Module not pre-loaded: " +
              abs +
              " (required from " +
              fromUrl +
              ")",
          );
        }
        if (cached.status === "loading") {
          throw new Error(
            "[tsRuntime] Circular dependency detected: " +
              abs +
              " <-> " +
              fromUrl,
          );
        }
        return cached.exports;
      }
      return window[id] || {};
    };
    // eslint-disable-next-line no-new-func
    new Function("module", "exports", "require", code)(
      mod,
      mod.exports,
      require,
    );
  }

  // if url has no extension, try appending .ts
  function resolveExtension(url) {
    if (/\.[^/]+$/.test(url)) return Promise.resolve(url);
    return fetch(url + ".ts").then(function (r) {
      return r.ok ? url + ".ts" : url;
    });
  }

  // recursively fetch, compile, and pre-load a module and all its dependencies
  function loadModule(url) {
    if (moduleCache[url]) {
      if (moduleCache[url].status === "loading") {
        return Promise.reject(
          new Error("[tsRuntime] Circular dependency detected at: " + url),
        );
      }
      return Promise.resolve(moduleCache[url].exports);
    }

    return resolveExtension(url).then(function (resolvedUrl) {
      if (resolvedUrl !== url) {
        return loadModule(resolvedUrl).then(function (exports) {
          moduleCache[url] = moduleCache[resolvedUrl];
          return exports;
        });
      }

      var entry = { exports: {}, status: "loading" };
      moduleCache[resolvedUrl] = entry;

      return fetch(resolvedUrl)
        .then(function (r) {
          if (!r.ok)
            throw new Error(
              "[tsRuntime] HTTP " + r.status + " loading " + resolvedUrl,
            );
          return r.text();
        })
        .then(function (src) {
          var code = compile(src);
          var relIds = scanRequires(code);
          var depUrls = relIds.map(function (id) {
            return resolveUrl(id, resolvedUrl);
          });

          return depUrls
            .reduce(function (chain, depUrl) {
              return chain.then(function () {
                return loadModule(depUrl);
              });
            }, Promise.resolve())
            .then(function () {
              try {
                execModule(code, entry, resolvedUrl);
              } catch (e) {
                console.error(
                  "[tsRuntime] Error executing " + resolvedUrl + ":",
                  e,
                );
                throw e;
              }
              entry.status = "done";
              return entry.exports;
            });
        })
        .catch(function (e) {
          delete moduleCache[resolvedUrl];
          console.error("[tsRuntime] Failed to load " + resolvedUrl + ":", e);
          throw e;
        });
    });
  }

  function execScript(code, src) {
    try {
      var mod = { exports: {} };
      execModule(code, mod, src || null);
      Object.assign(window, mod.exports);
    } catch (e) {
      console.error(
        "[tsRuntime] Error executing" + (src ? " " + src : "") + ":",
        e,
      );
    }
  }

  // process all <script type="text/typescript"> already in the document
  function processInlineScripts() {
    document
      .querySelectorAll('script[type="text/typescript"]')
      .forEach(function (el) {
        execScript(compile(el.textContent));
      });
  }

  // fetch and execute an external .ts file, returns a Promise
  window.loadTS = function (url) {
    return loadModule(url).then(function (exports) {
      Object.assign(window, exports);
    });
  };

  // run after DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", processInlineScripts);
  } else {
    processInlineScripts();
  }
})();
