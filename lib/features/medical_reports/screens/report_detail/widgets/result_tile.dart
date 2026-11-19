import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/localization/translations.dart';
import '../../../models/report_result_model.dart';

/// -- One test result: value as printed, the lab's own range, and how it compares.
class XResultTile extends StatelessWidget {
  const XResultTile({super.key, required this.result, this.onEdit, this.onDelete});

  final ReportResultModel result;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static (String, Color) flagStyle(String flag) {
    switch (flag) {
      case 'critical':
        return ('Needs attention'.tr, XColors.error);
      case 'low':
        return ('Below lab range'.tr, XColors.warning);
      case 'high':
        return ('Above lab range'.tr, XColors.warning);
      case 'normal':
        return ('Within lab range'.tr, XColors.success);
      default:
        return ('Nothing to compare'.tr, XColors.darkGrey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (label, color) = flagStyle(result.flag);
    final value = [result.valueText, if (result.unit != null) result.unit!].join(' ');
    final range = result.rangeLabel;

    return Semantics(
      label: '${result.testName}: $value. ${range == null ? 'No lab range printed'.tr : 'Lab range: {range}'.trf({'range': range})}. $label.',
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: XSizes.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Colour bar
              Container(
                width: 4,
                height: 44,
                margin: const EdgeInsets.only(right: XSizes.sm, top: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),

              /// Text
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.testName, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(value, style: textTheme.titleLarge!.apply(color: result.isOutOfRange ? color : null)),
                      Text(range == null ? 'No lab range printed'.tr : 'Lab range: {range}'.trf({'range': range}), style: textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(label, style: textTheme.labelLarge!.apply(color: color)),
                    ],
                  ),
                ),
              ),

              /// Actions (review step only)
              if (onEdit != null)
                IconButton(tooltip: 'Correct {testName}'.trf({'testName': result.testName}), onPressed: onEdit, icon: const Icon(Iconsax.edit_2)),
              if (onDelete != null)
                IconButton(tooltip: 'Remove {testName}'.trf({'testName': result.testName}), onPressed: onDelete, icon: const Icon(Iconsax.trash)),
            ],
          ),
        ),
      ),
    );
  }
}
