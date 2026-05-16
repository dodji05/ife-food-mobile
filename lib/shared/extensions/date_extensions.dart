extension DateX on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${day.toString().padLeft(2,'0')}/${month.toString().padLeft(2,'0')}/$year';
  }

  String get shortDate => '${day.toString().padLeft(2,'0')}/${month.toString().padLeft(2,'0')}/$year';
  String get time => '${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}';
}
