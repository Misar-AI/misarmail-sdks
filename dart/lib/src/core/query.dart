/// Query-string encoding shared by every generated GET/DELETE method.
///
/// Returns '' for an empty bag so a generated call site can always append
/// unconditionally.
String encodeQuery(Map<String, String?> params) {
  final entries = params.entries.where((e) => e.value != null);
  if (entries.isEmpty) return '';

  final pairs = entries.map(
    (e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value!)}',
  );
  return '?${pairs.join('&')}';
}
