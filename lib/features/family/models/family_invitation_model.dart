import 'package:get/get.dart';

/// -- An invitation to join a family, sent to an existing account by NutriSafe ID.
class FamilyInvitationModel {
  FamilyInvitationModel({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.familyName,
    this.invitedByName,
    this.inviteeName,
    this.inviteeNutrisafeId,
  });

  final String id;
  final String status; // pending | accepted | rejected | expired | revoked
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? familyName; // received invitations
  final String? invitedByName; // received invitations
  final String? inviteeName; // sent invitations
  final String? inviteeNutrisafeId; // sent invitations

  bool get isPending => status == 'pending';

  static const statusLabels = {
    'pending': 'Pending',
    'accepted': 'Accepted',
    'rejected': 'Declined',
    'expired': 'Expired',
    'revoked': 'Cancelled',
  };

  String get statusLabel => (statusLabels[status] ?? status).tr;

  /// From get_my_family_invitations()
  factory FamilyInvitationModel.received(Map<String, dynamic> json) {
    return FamilyInvitationModel(
      id: json['id'] as String,
      status: 'pending',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      familyName: json['family_name'] as String?,
      invitedByName: json['invited_by_name'] as String?,
    );
  }

  /// From get_family_invitations()
  factory FamilyInvitationModel.sent(Map<String, dynamic> json) {
    return FamilyInvitationModel(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      inviteeName: json['invitee_name'] as String?,
      inviteeNutrisafeId: json['invitee_nutrisafe_id'] as String?,
    );
  }
}

/// -- Result of looking up a NutriSafe ID. Contains no email, phone or internal id.
class AccountLookupModel {
  AccountLookupModel({required this.nutrisafeId, required this.displayName, required this.relation});

  final String nutrisafeId;
  final String displayName;
  final String relation; // none | self | member | invited

  factory AccountLookupModel.fromJson(Map<String, dynamic> json) {
    return AccountLookupModel(
      nutrisafeId: json['nutrisafe_code'] as String,
      displayName: json['display_name'] as String,
      relation: json['relation'] as String,
    );
  }
}
