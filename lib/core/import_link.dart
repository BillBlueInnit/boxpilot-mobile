/// A subscription offered by a provider's one-tap import button.
class ImportLink {
  const ImportLink(this.url, [this.name]);
  final String url;
  final String? name;
}

/// Reads the import links proxy apps share:
/// `clash://install-config?url=…&name=…`, `clashmeta://…` (same form),
/// `sing-box://import-remote-profile?url=…#name` and `boxpilot://install-config?url=…`.
/// Returns `null` for anything else, or when the subscription isn't http(s).
ImportLink? parseImportLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (!const {'clash', 'clashmeta', 'sing-box', 'boxpilot'}.contains(uri.scheme)) return null;
  final url = uri.queryParameters['url']?.trim() ?? '';
  final target = Uri.tryParse(url);
  if (target == null || !(target.isScheme('http') || target.isScheme('https')) || target.host.isEmpty) return null;
  var name = uri.queryParameters['name'];
  if ((name == null || name.isEmpty) && uri.fragment.isNotEmpty) name = Uri.decodeComponent(uri.fragment);
  return ImportLink(url, name == null || name.trim().isEmpty ? null : name.trim());
}
