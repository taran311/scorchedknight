{{flutter_js}}
{{flutter_build_config}}

// No service worker: it kept phones playing an old copy of the game after every deploy.
//
// The host lets browsers keep files for 10 minutes without asking, so a phone could go on running
// last update's game long after a deploy. Before starting, ask the server whether the game file
// has changed ("no-cache" = check first; an unchanged file costs one tiny "not modified" reply, a
// new one is fetched and replaces the old copy). Then start as usual: the fresh copy is what loads.
(function () {
  var start = function () { _flutter.loader.load(); };
  var started = false;
  var go = function () { if (!started) { started = true; start(); } };
  try {
    var builds = (_flutter.buildConfig && _flutter.buildConfig.builds) || [];
    var files = builds.map(function (b) { return b.mainJsPath; }).filter(Boolean);
    if (!files.length || !window.fetch) return go();
    Promise.all(files.map(function (f) { return fetch(f, { cache: 'no-cache' }).catch(function () {}); })).then(go, go);
    // On a slow connection, don't wait for ever: start with what we have.
    setTimeout(go, 4000);
  } catch (e) {
    go();
  }
})();
