import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/family/family_invitation_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../models/family_invitation_model.dart';
import 'family_controller.dart';
import '../../../utils/localization/translations.dart';

/// State of the "Add existing account" screen.
enum LookupState { idle, searching, found, notFound, failed, sending, sent }

/// -- Find an existing account by NutriSafe ID and send it a family invitation.
class AddMemberController extends GetxController {
  static AddMemberController get instance => Get.find();

  static final _validId = RegExp(r'^NS-[2-9A-HJKMNP-Z]{6}$');

  /// Variables
  final _repository = Get.put(FamilyInvitationRepository());
  final idField = TextEditingController();
  final state = LookupState.idle.obs;
  final result = Rxn<AccountLookupModel>();
  final message = RxnString();

  /// "ns 84k92p", "NS84K92P" and "84K92P" all become "NS-84K92P"; null when not an ID.
  static String? normalize(String input) {
    var code = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length == 8 && code.startsWith('NS')) code = code.substring(2);
    if (code.length != 6) return null;
    final id = 'NS-$code';
    return _validId.hasMatch(id) ? id : null;
  }

  void onChanged(String _) {
    if (state.value != LookupState.idle) {
      state.value = LookupState.idle;
      result.value = null;
      message.value = null;
    }
  }

  Future<void> find() async {
    final id = normalize(idField.text);
    if (id == null) {
      state.value = LookupState.failed;
      message.value = 'Enter a NutriSafe ID like NS-84K92P. It is shown on the Profile screen of the person you want to add.'.tr;
      return;
    }
    idField.text = id;
    state.value = LookupState.searching;
    result.value = null;
    try {
      final found = await _repository.findAccount(id);
      if (found == null) {
        state.value = LookupState.notFound;
        message.value = 'No NutriSafe account has the ID {id}. Check it with the person you want to add.'.trf({'id': id});
      } else {
        result.value = found;
        state.value = LookupState.found;
      }
    } catch (e) {
      state.value = LookupState.failed;
      message.value = _networkMessage(e);
    }
  }

  Future<void> sendInvitation() async {
    final found = result.value;
    if (found == null || found.relation != 'none') return;
    state.value = LookupState.sending;
    try {
      await _repository.invite(found.nutrisafeId);
      state.value = LookupState.sent;
      if (Get.isRegistered<FamilyController>()) FamilyController.instance.load();
    } catch (e) {
      state.value = LookupState.found;
      message.value = _networkMessage(e);
    }
  }

  static String _networkMessage(Object e) {
    if (e is SocketException || e is TimeoutException) {
      return 'No connection. Check your internet and try again.'.tr;
    }
    return XExceptionHandler.message(e);
  }

  @override
  void onClose() {
    idField.dispose();
    super.onClose();
  }
}
