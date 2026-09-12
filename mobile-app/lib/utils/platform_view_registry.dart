/// Stub for non-web platforms — no-op.
library;

void registerViewFactory(
  String viewType,
  Object Function(int viewId) factory,
) {
  // Not supported on non-web platforms
}
