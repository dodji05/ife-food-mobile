extension StringX on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  String truncate(int maxLength, {String suffix = '…'}) =>
    length <= maxLength ? this : '${substring(0, maxLength)}$suffix';
}

extension DoubleX on double {
  String formatCFA({String symbol = 'F'}) => '${toStringAsFixed(0)} $symbol';
  String formatKm() => toStringAsFixed(1);
}
