/// Small text-formatting helpers used by the screens.

/// 1536 -> "1.5 KB"
String fmtBytes(num? n) {
  double v = (n ?? 0).toDouble();
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(1)} ${units[i]}';
}

/// 93784 seconds -> "1d 2h 3m"
String fmtUptime(num seconds) {
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return '${d}d ${h}h ${m}m';
}

/// "stop" -> "Stop"
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
