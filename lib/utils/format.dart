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
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

/// 1536 -> "1.5 KB/s"
String fmtSpeed(num? bps) => '${fmtBytes(bps)}/s';

/// 93784 seconds -> "1d 2h 3m"
String fmtUptime(num seconds) {
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// "stop" -> "Stop"
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Seconds since 1970 -> "14 Nov 2026, 19:05"
String fmtDate(num? epochSeconds) {
  if (epochSeconds == null) return '';
  final d = DateTime.fromMillisecondsSinceEpoch((epochSeconds * 1000).toInt()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// Seconds since 1970 -> "5 min ago"
String timeAgo(num epochSeconds) {
  final diff = DateTime.now().millisecondsSinceEpoch / 1000 - epochSeconds;
  if (diff < 60) return 'just now';
  if (diff < 3600) return '${(diff / 60).floor()} min ago';
  if (diff < 86400) return '${(diff / 3600).floor()} h ago';
  return '${(diff / 86400).floor()} d ago';
}
