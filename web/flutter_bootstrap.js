{{flutter_js}}
{{flutter_build_config}}

// Service worker intentionally disabled — causes stale-cache hangs on every
// new deploy. Flutter 3.22+ marks its own SW as deprecated anyway.
_flutter.loader.load({});
