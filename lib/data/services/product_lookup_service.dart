import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/nutrition/models/product_draft.dart';
import '../../utils/constants/api_constants.dart';

/// -- Finds a packaged product by barcode in every product database at once
/// (NutriSafe, Open Food Facts, USDA FoodData Central, Nutritionix, FatSecret).
/// The search runs on the server so the database keys never ship inside the app.
class ProductLookupService {
  ProductLookupService._();

  static const _timeout = Duration(seconds: 25);

  /// Throws when the server cannot be reached (the caller shows "no connection",
  /// never "product not found"). [format] is the barcode type, e.g. "upce".
  static Future<ProductDraft> lookup(String barcode, {String? format}) async {
    final response = await Supabase.instance.client.functions
        .invoke(XApiConstants.productLookupFunction, body: {'barcode': barcode, 'format': ?format})
        .timeout(_timeout);
    return ProductDraft.fromLookup(Map<String, dynamic>.from(response.data as Map));
  }
}
