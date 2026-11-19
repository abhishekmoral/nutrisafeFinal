/// -- Text matching for the food catalog search (English, Hinglish and Hindi words).
class XFoodSearch {
  XFoodSearch._();

  static final _notWordChars = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

  /// The words of what the user typed: letters, marks and digits of any script only,
  /// so they are safe to place inside a database filter. At most four words.
  static List<String> words(String query) {
    return query.toLowerCase().split(_notWordChars).where((w) => w.isNotEmpty).take(4).toList();
  }

  /// Keeps the rows in which every typed word starts a word of the food name or of its
  /// search words ("anda" finds "Egg ... anda" but not "chukandar"), best matches first.
  static List<Map<String, dynamic>> filterAndRank(
    List<Map<String, dynamic>> rows,
    List<String> queryWords,
  ) {
    if (queryWords.isEmpty) return [];
    final needle = queryWords.join(' ');

    bool matches(Map<String, dynamic> row) {
      final text = '${row['name'] ?? ''} ${row['search_terms'] ?? ''}'.toLowerCase();
      final tokens = text.split(_notWordChars).where((t) => t.isNotEmpty).toList();
      return queryWords.every((word) => tokens.any((token) => token.startsWith(word)));
    }

    int rank(Map<String, dynamic> row) {
      final name = (row['name'] as String? ?? '').toLowerCase();
      if (name == needle) return 0;
      if (name.startsWith(needle)) return 1;
      if (name.contains(needle)) return 2;
      return 3;
    }

    return rows.where(matches).toList()..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
  }
}
