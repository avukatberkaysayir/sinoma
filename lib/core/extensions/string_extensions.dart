extension StringX on String {
  bool get containsChinese => RegExp(r'[一-鿿]').hasMatch(this);
  bool get containsOnlyChinese => RegExp(r'^[一-鿿]+$').hasMatch(this);

  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }

  String get toPinyin => replaceAll(RegExp(r'[1-5]'), '').trim();
}
