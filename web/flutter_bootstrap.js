{{flutter_js}}
{{flutter_build_config}}

// No service worker: it kept phones playing an old copy of the game after every deploy. The
// browser's normal cache (which checks for a new build) is all we need.
_flutter.loader.load();
