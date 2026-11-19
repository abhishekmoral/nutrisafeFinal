import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../../utils/localization/translations.dart';
import '../../../../../utils/validators/validation.dart';
import '../../../models/report_result_model.dart';

/// -- Correct a result or add one the AI missed. Returns the edited result, or null.
class XEditResultSheet extends StatefulWidget {
  const XEditResultSheet({super.key, this.result});

  final ReportResultModel? result; // null = add a new result

  @override
  State<XEditResultSheet> createState() => _XEditResultSheetState();
}

class _XEditResultSheetState extends State<XEditResultSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _unit;
  late final TextEditingController _low;
  late final TextEditingController _high;

  @override
  void initState() {
    super.initState();
    final r = widget.result;
    String number(double? v) => v == null ? '' : XHelperFunctions.formatNumber(v, decimals: 3);
    _name = TextEditingController(text: r?.testName ?? '');
    _value = TextEditingController(text: r?.valueText ?? '');
    _unit = TextEditingController(text: r?.unit ?? '');
    _low = TextEditingController(text: number(r?.referenceLow));
    _high = TextEditingController(text: number(r?.referenceHigh));
  }

  @override
  void dispose() {
    for (final c in [_name, _value, _unit, _low, _high]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optionalNumber(String label, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null ? 'Enter a number for {label}, or leave it empty.'.trf({'label': label}) : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    double? number(TextEditingController c) => c.text.trim().isEmpty ? null : double.parse(c.text.trim());
    final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();
    final base = widget.result ?? ReportResultModel(testName: '', valueText: '');
    Navigator.of(context).pop(
      base.edited(
        testName: _name.text.trim(),
        valueText: _value.text.trim(),
        unit: unit,
        referenceLow: number(_low),
        referenceHigh: number(_high),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.result == null;
    return Padding(
      padding: EdgeInsets.only(
        left: XSizes.defaultSpace,
        right: XSizes.defaultSpace,
        bottom: MediaQuery.of(context).viewInsets.bottom + XSizes.defaultSpace,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isNew ? 'Add a test'.tr : 'Correct this test'.tr, style: Theme.of(context).textTheme.headlineSmall),
              Text('Type it exactly as printed on your report.'.tr, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: XSizes.spaceBtwItems),
              TextFormField(
                controller: _name,
                maxLength: 120,
                validator: (v) => XValidator.validateEmptyText('Test name'.tr, v),
                decoration: InputDecoration(labelText: 'Test name'.tr, counterText: ''),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _value,
                      maxLength: 60,
                      validator: (v) => XValidator.validateEmptyText('Result'.tr, v),
                      decoration: InputDecoration(
                        labelText: 'Result'.tr,
                        helperText: 'e.g. 180, <0.5, Positive'.tr,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unit,
                      maxLength: 30,
                      decoration: InputDecoration(labelText: 'Unit'.tr, counterText: ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Text('Lab range (from the report)'.tr, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: XSizes.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _low,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => _optionalNumber('the lower limit'.tr, v),
                      decoration: InputDecoration(labelText: 'Lower limit'.tr),
                    ),
                  ),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(
                    child: TextFormField(
                      controller: _high,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => _optionalNumber('the upper limit'.tr, v),
                      decoration: InputDecoration(labelText: 'Upper limit'.tr),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwSections),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: Text(isNew ? 'Add test'.tr : 'Save'.tr)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
