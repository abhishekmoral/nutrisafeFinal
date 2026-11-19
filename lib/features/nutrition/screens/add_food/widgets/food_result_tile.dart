import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../models/food_item_model.dart';

class XFoodResultTile extends StatelessWidget {
  const XFoodResultTile({super.key, required this.food, required this.onTap});

  final FoodItemModel food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final calories = food.nutrition.calories;
    final details = [
      if (food.brand != null && food.brand!.isNotEmpty) food.brand!,
      calories == null
          ? 'Nutrition unknown'.tr
          : '${XHelperFunctions.formatNumber(calories, decimals: 0)} kcal ${food.basis.label}',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(XSizes.cardRadiusSm),
        child: food.imageUrl == null
            ? const _Placeholder()
            : Image.network(
                food.imageUrl!,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _Placeholder(),
              ),
      ),
      title: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Iconsax.add_circle, color: XColors.primary),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      color: XColors.primaryBackground,
      child: const Icon(Iconsax.reserve, color: XColors.primary),
    );
  }
}
