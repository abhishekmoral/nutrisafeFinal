import 'package:get/get.dart';

import '../../../utils/helpers/helper_function.dart';

/// Relationship choices for a managed profile.
const managedRelationships = {
  'child': 'Child',
  'parent': 'Parent',
  'grandparent': 'Grandparent',
  'spouse': 'Spouse / partner',
  'sibling': 'Sibling',
  'other': 'Other',
};

/// -- A family member without their own account or device (`child_profiles`).
/// No login is created for them; guardians and caregivers manage the profile.
class ManagedProfileModel {
  ManagedProfileModel({
    required this.id,
    required this.managedId,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.relationship,
    this.dietaryPreference,
    this.notes,
    this.myRole,
  });

  final String id;
  final String managedId; // e.g. MP-7QK3RD
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? relationship;
  final String? dietaryPreference;
  final String? notes;
  final String? myRole; // guardian | caregiver | null (no access to details)

  bool get isGuardian => myRole == 'guardian';
  bool get canCare => myRole == 'guardian' || myRole == 'caregiver';

  String get initial => fullName.isEmpty ? '?' : fullName[0].toUpperCase();

  String? get relationshipLabel => managedRelationships[relationship]?.tr;

  int? get age => dateOfBirth == null ? null : XHelperFunctions.calculateAge(dateOfBirth!);

  /// Row from get_family_managed_profiles() (list: no personal details).
  factory ManagedProfileModel.fromListJson(Map<String, dynamic> json) {
    return ManagedProfileModel(
      id: json['id'] as String,
      managedId: json['managed_id'] as String,
      fullName: json['full_name'] as String,
      relationship: json['relationship'] as String?,
      myRole: json['my_role'] as String?,
    );
  }

  /// Row from child_profiles (details, visible to guardians and caregivers only).
  factory ManagedProfileModel.fromJson(Map<String, dynamic> json, {String? myRole}) {
    return ManagedProfileModel(
      id: json['id'] as String,
      managedId: json['managed_id'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] == null ? null : DateTime.parse(json['date_of_birth'] as String),
      gender: json['gender'] as String?,
      relationship: json['relationship'] as String?,
      dietaryPreference: json['dietary_preference'] as String?,
      notes: json['notes'] as String?,
      myRole: myRole,
    );
  }
}

/// -- An adult who looks after a managed profile.
class CarerModel {
  CarerModel({required this.userId, this.fullName, this.nutrisafeId, required this.role});

  final String userId;
  final String? fullName;
  final String? nutrisafeId;
  final String role; // guardian | caregiver

  String get displayName => (fullName ?? '').trim().isEmpty ? 'NutriSafe user'.tr : fullName!.trim();

  factory CarerModel.fromJson(Map<String, dynamic> json) {
    return CarerModel(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      nutrisafeId: json['nutrisafe_id'] as String?,
      role: json['role'] as String,
    );
  }
}
