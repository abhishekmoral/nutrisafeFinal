import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../data/repositories/user/user_repository.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/exceptions/exception_handler.dart';
import '../../../../utils/popups/loaders.dart';
import '../../controllers/user_controller.dart';

/// -- Language + exactly which data the AI agent may read. Everything is off until allowed.
class AiPrivacySettingsScreen extends StatefulWidget {
  const AiPrivacySettingsScreen({super.key});

  @override
  State<AiPrivacySettingsScreen> createState() => _AiPrivacySettingsScreenState();
}

class _AiPrivacySettingsScreenState extends State<AiPrivacySettingsScreen> {
  static const _contextTypes = {
    'profile': ('Basic profile', 'First name, age, gender, activity level, location'),
    'body_metrics': ('Height & weight', 'Used for portion and goal suggestions'),
    'dietary_preferences': ('Dietary preference', 'Vegetarian, vegan, etc.'),
    'allergies': ('Allergies & intolerances', 'So suggestions avoid them'),
    'food_diary': ('Food diary & water', 'What you logged in the last few days'),
    'health_goals': ('Goals & targets', 'Wellness goals and daily nutrition targets'),
    'symptoms': ('Reported symptoms', 'Symptoms you recorded'),
    'progress': ('Progress logs', 'Weight and check-in history'),
    'ai_history': ('Earlier messages', 'Lets the agent remember this conversation'),
  };

  final _repository = UserRepository.instance;
  bool _loading = true;
  AppLanguage _language = AppLanguage.english;
  bool _autoDetect = true;
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.fetchSettings();
      final permissions = await _repository.fetchAiPermissions();
      if (!mounted) return;
      setState(() {
        _language = AppLanguage.fromCode(settings['preferred_language'] as String?);
        _autoDetect = settings['auto_detect_language'] != false;
        _permissions = permissions;
        _loading = false;
      });
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load settings'.tr, message: XExceptionHandler.message(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Apply the change on screen, save it, and roll back if saving fails.
  Future<void> _update(VoidCallback apply, VoidCallback rollback, Future<void> Function() save) async {
    setState(apply);
    try {
      await save();
    } catch (e) {
      if (mounted) setState(rollback);
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('AI & privacy'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(XSizes.defaultSpace),
              children: [
                /// Language
                XSectionHeading(title: 'Language'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                DropdownButtonFormField<AppLanguage>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: 'App language'.tr,
                    helperText: 'Used for every screen and for AI replies'.tr,
                  ),
                  items: AppLanguage.values
                      .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final previous = _language;
                    _update(
                      () => _language = value,
                      () => _language = previous,
                      () => UserController.instance.setLanguage(value),
                    );
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Detect my language automatically'.tr),
                  subtitle: Text('The agent replies in the language you write in'.tr),
                  value: _autoDetect,
                  onChanged: (value) => _update(
                    () => _autoDetect = value,
                    () => _autoDetect = !value,
                    () => _repository.updateSettings({'auto_detect_language': value}),
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// AI data permissions
                XSectionHeading(title: 'What the AI agent may use'.tr, showActionButton: false),
                Text(
                  'The agent only receives the items you switch on. Medical reports have their own permission below.'.tr,
                  style: textTheme.labelMedium,
                ),
                for (final entry in _contextTypes.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value.$1.tr),
                    subtitle: Text(entry.value.$2.tr),
                    value: _permissions[entry.key] ?? false,
                    onChanged: (value) => _update(
                      () => _permissions[entry.key] = value,
                      () => _permissions[entry.key] = !value,
                      () => _repository.setAiPermission(entry.key, value),
                    ),
                  ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Medical reports: a separate permission
                XSectionHeading(title: 'Medical reports'.tr, showActionButton: false),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('AI may read my medical reports'.tr),
                  subtitle: Text(
                    'Needed to copy the values from a report you upload and explain them. The report file is sent to the AI service for this.'.tr,
                  ),
                  value: _permissions['medical_reports'] ?? false,
                  onChanged: (value) => _update(
                    () => _permissions['medical_reports'] = value,
                    () => _permissions['medical_reports'] = !value,
                    () => _repository.setAiPermission('medical_reports', value),
                  ),
                ),
              ],
            ),
    );
  }
}
