import 'package:get/get.dart';

import '../../../data/repositories/family/family_invitation_repository.dart';
import '../../../data/repositories/notifications/notification_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';

/// -- In-app notifications (the bell on Home) and the unread count.
class NotificationsController extends GetxController {
  static NotificationsController get instance => Get.find();

  final _repository = Get.put(NotificationRepository());
  final _invitations = Get.put(FamilyInvitationRepository());
  final items = <Map<String, dynamic>>[].obs;
  final unread = 0.obs;
  final pendingInvitations = 0.obs; // family invitations I can still answer (Home banner)
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshCount();
  }

  Future<void> refreshCount() async {
    try {
      final results = await Future.wait([_repository.unreadCount(), _invitations.fetchReceived()]);
      unread.value = results[0] as int;
      pendingInvitations.value = (results[1] as List).length;
    } catch (_) {
      // The badge and banner are helpers; ignore failures.
    }
  }

  /// Load the list and mark everything as read.
  Future<void> open() async {
    try {
      loading.value = true;
      items.assignAll(await _repository.fetchRecent());
      if (unread.value > 0) {
        await _repository.markAllRead();
        unread.value = 0;
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load notifications'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }
}
