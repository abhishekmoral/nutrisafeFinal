import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/utils/helpers/food_search.dart';

void main() {
  // Names and search words exactly as stored in the catalog.
  final rows = <Map<String, dynamic>>[
    {'name': 'Roti / Chapati', 'search_terms': 'roti chapati chapatti phulka रोटी चपाती फुलका'},
    {'name': 'Bread, white', 'search_terms': 'bread white double roti pav ब्रेड'},
    {'name': 'Egg, boiled', 'search_terms': 'egg anda boiled अंडा'},
    {'name': 'Egg omelette', 'search_terms': 'omelette omelet egg anda आमलेट'},
    {'name': 'Beetroot, boiled', 'search_terms': 'beetroot chukandar beet चुकंदर'},
    {'name': 'Onion, raw', 'search_terms': 'onion pyaz pyaaz kanda प्याज'},
    {'name': 'Rice, white, cooked', 'search_terms': 'rice chawal chaval bhaat bhat चावल भात'},
    {'name': 'Rice, brown, cooked', 'search_terms': 'brown rice chawal ब्राउन राइस'},
    {'name': 'Curd / Yogurt, plain, whole milk', 'search_terms': 'curd dahi yogurt yoghurt दही'},
    {'name': 'Dal', 'search_terms': 'dal daal dhal lentil दाल'},
    {'name': 'Lentil curry', 'search_terms': 'dal curry masoor lentil curry दाल'},
  ];

  List<String> find(String query) => XFoodSearch.filterAndRank(
    rows,
    XFoodSearch.words(query),
  ).map((r) => r['name'] as String).toList();

  group('XFoodSearch.words', () {
    test('keeps letters of any script and drops filter characters', () {
      expect(XFoodSearch.words('  Brown,  RICE!! '), ['brown', 'rice']);
      expect(XFoodSearch.words('दही'), ['दही']);
      expect(XFoodSearch.words('a%b"c(d),e'), ['a', 'b', 'c', 'd']);
      expect(XFoodSearch.words('   '), isEmpty);
    });
  });

  group('XFoodSearch.filterAndRank', () {
    test('a Hinglish word finds the food, best name match first', () {
      expect(find('roti'), ['Roti / Chapati', 'Bread, white']);
      expect(find('chawal'), ['Rice, brown, cooked', 'Rice, white, cooked']);
    });

    test('matches whole words only: anda is not chukandar or kanda', () {
      expect(find('anda'), ['Egg omelette', 'Egg, boiled']);
    });

    test('Hindi script works', () {
      expect(find('दही'), ['Curd / Yogurt, plain, whole milk']);
      expect(find('दाल'), ['Dal', 'Lentil curry']);
    });

    test('every typed word must match', () {
      expect(find('brown rice'), ['Rice, brown, cooked']);
      expect(find('white rice'), ['Rice, white, cooked']);
      expect(find('rice pizza'), isEmpty);
    });

    test('typing the start of a word is enough', () {
      expect(find('chap'), ['Roti / Chapati']);
      expect(find('da'), ['Dal', 'Curd / Yogurt, plain, whole milk', 'Lentil curry']);
    });

    test('an exact name comes first', () {
      expect(find('dal').first, 'Dal');
    });
  });
}
