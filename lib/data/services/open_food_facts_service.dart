import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/nutrition/models/food_item_model.dart';
import '../../features/nutrition/models/nutrition_values.dart';
import '../../utils/constants/api_constants.dart';
import '../../utils/constants/enums.dart';
import '../../utils/localization/translations.dart';

/// -- Packaged food lookup in the public Open Food Facts database.
/// Data there is crowd-sourced, so values are shown as "estimated" and the user must confirm.
class OpenFoodFactsService {
  OpenFoodFactsService._();

  static const _fields =
      'code,product_name,brands,nutriments,serving_quantity,serving_quantity_unit,'
      'allergens_tags,ingredients_text,image_front_small_url';
  static const _headers = {'User-Agent': 'NutriSafe/1.0 (Flutter app)'};
  static const _timeout = Duration(seconds: 12);

  /// Returns null when the barcode is not in the database.
  static Future<FoodItemModel?> getProductByBarcode(String barcode) async {
    final uri = Uri.parse(
      '${XApiConstants.openFoodFactsBaseUrl}/api/v2/product/${Uri.encodeComponent(barcode)}.json?fields=$_fields',
    );
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw 'Product lookup failed ({statusCode}). Please try again.'.trf({'statusCode': response.statusCode});
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['product'] == null) return null;
    return _toFoodItem(Map<String, dynamic>.from(body['product'] as Map), barcode);
  }

  static Future<List<FoodItemModel>> searchProducts(String query) async {
    final uri = Uri.parse('${XApiConstants.openFoodFactsBaseUrl}/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': query,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '15',
        'fields': _fields,
      },
    );
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw 'Product search failed ({statusCode}). Please try again.'.trf({'statusCode': response.statusCode});
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final products = (body['products'] as List?) ?? const [];
    return products
        .map((p) => _toFoodItem(Map<String, dynamic>.from(p as Map), null))
        .whereType<FoodItemModel>()
        .toList();
  }

  static FoodItemModel? _toFoodItem(Map<String, dynamic> product, String? barcode) {
    final name = (product['product_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    final nutriments = Map<String, dynamic>.from((product['nutriments'] as Map?) ?? const {});
    double? n(String key) {
      final value = nutriments[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final sodiumG = n('sodium_100g');
    final nutrition = NutritionValues(
      calories: n('energy-kcal_100g'),
      proteinG: n('proteins_100g'),
      carbsG: n('carbohydrates_100g'),
      fatG: n('fat_100g'),
      saturatedFatG: n('saturated-fat_100g'),
      fiberG: n('fiber_100g'),
      sugarG: n('sugars_100g'),
      sodiumMg: sodiumG == null ? null : sodiumG * 1000,
    );

    final servingRaw = product['serving_quantity'];
    final serving = servingRaw is num
        ? servingRaw.toDouble()
        : (servingRaw is String ? double.tryParse(servingRaw) : null);
    final servingUnit = (product['serving_quantity_unit'] as String?)?.toLowerCase();
    final isLiquid = servingUnit == 'ml';

    final allergens = ((product['allergens_tags'] as List?) ?? const [])
        .map((e) => e.toString().split(':').last.replaceAll('-', ' '))
        .toList();

    return FoodItemModel(
      barcode: barcode ?? product['code']?.toString(),
      name: name,
      brand: (product['brands'] as String?)?.split(',').first.trim(),
      imageUrl: product['image_front_small_url'] as String?,
      basis: isLiquid ? NutritionBasis.per100ml : NutritionBasis.per100g,
      servingSize: (serving != null && serving > 0) ? serving : null,
      servingUnit: isLiquid ? 'ml' : 'g',
      nutrition: nutrition,
      quality: nutrition.isEmpty ? NutritionQuality.unknown : NutritionQuality.estimated,
      entrySource: 'barcode',
      allergens: allergens,
      ingredientsText: product['ingredients_text'] as String?,
    );
  }
}
