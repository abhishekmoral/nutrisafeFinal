/// -- Finds allergens in label text, including the Hindi/Hinglish words used on Indian packs
/// (maida, ghee, kaju, til, sarson ...). Names match the allergen list of the profile screens.
/// The same list is used by the product-lookup Edge Function (merge.ts).
class XAllergenWords {
  XAllergenWords._();

  static final List<(String, RegExp)> _words = [
    ('Wheat / Gluten', RegExp(r'\b(gluten|wheat|maida|atta|sooji|suji|rava|semolina|barley|rye|oats?)\b', caseSensitive: false)),
    ('Milk', RegExp(r'\b(milk|dairy|lactose|whey|casein|(?<!(cocoa|peanut|nut|shea) )butter|ghee|cream|cheese|paneer|khoa|khoya|curd|dahi)\b', caseSensitive: false)),
    ('Egg', RegExp(r'\beggs?\b', caseSensitive: false)),
    ('Peanut', RegExp(r'\b(peanuts?|groundnuts?|moongphali)\b', caseSensitive: false)),
    ('Tree nuts', RegExp(r'\b(tree ?nuts?|nuts|almonds?|badam|cashews?|kaju|pistachios?|pista|walnuts?|akhrot|hazelnuts?|pecans?|macadamia)\b', caseSensitive: false)),
    ('Soy', RegExp(r'\b(soy|soya|soybeans?)\b', caseSensitive: false)),
    ('Fish', RegExp(r'\bfish\b', caseSensitive: false)),
    ('Shellfish', RegExp(r'\b(shellfish|crustaceans?|prawns?|shrimps?|crabs?|lobsters?|molluscs?)\b', caseSensitive: false)),
    ('Sesame', RegExp(r'\b(sesame|til|gingelly)\b', caseSensitive: false)),
    ('Mustard', RegExp(r'\b(mustard|sarson|rai)\b', caseSensitive: false)),
    ('Celery', RegExp(r'\bcelery\b', caseSensitive: false)),
    ('Lupin', RegExp(r'\blupin\b', caseSensitive: false)),
    ('Sulphites', RegExp(r'\b(sulph?ites?|sulfites?|sulphur dioxide|sulfur dioxide)\b', caseSensitive: false)),
  ];

  /// Every allergen named in [text], in list order, without duplicates.
  static List<String> find(String text) =>
      [for (final (name, pattern) in _words) if (pattern.hasMatch(text)) name];

  /// Allergen names the app knows, in list order.
  static List<String> get names => [for (final (name, _) in _words) name];

  /// True when [allergen] (a name from a profile, e.g. "Wheat / Gluten" or "Peanuts") is
  /// named in [text], directly or through one of its label words.
  static bool mentions(String text, String allergen) {
    final lower = text.toLowerCase();
    final parts = allergen.toLowerCase().split(RegExp(r'[/,]')).map((w) => w.trim()).where((w) => w.isNotEmpty);
    if (parts.any(lower.contains)) return true;
    final found = find(text);
    // Map the profile name to the app's allergen group ("Peanuts" -> "Peanut", "Eggs" -> "Egg").
    final groups = find(allergen);
    return groups.any(found.contains);
  }
}
