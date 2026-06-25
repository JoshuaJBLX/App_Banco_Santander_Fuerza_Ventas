import 'package:flutter/foundation.dart' show kIsWeb;

/// SQLite solo en movil/desktop nativo. En web no se usa (evita worker colgado).
Future<void> initLocalDatabase() async {
  if (kIsWeb) return;
}
