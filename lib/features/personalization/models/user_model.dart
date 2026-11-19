import '../../../utils/helpers/helper_function.dart';

/// -- The signed-in adult's profile (`profiles` table).
class UserModel {
  UserModel({
    required this.id,
    this.email = '',
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.dietaryPreference,
    this.location,
    this.onboardingCompleted = false,
    this.nutrisafeId,
  });

  final String id;
  final String email;
  final String? nutrisafeId; // e.g. NS-84K92P; set by the server, never edited
  String? fullName;
  DateTime? dateOfBirth;
  String? gender;
  double? heightCm;
  double? weightKg;
  String? activityLevel;
  String? dietaryPreference;
  String? location;
  bool onboardingCompleted;

  static UserModel empty() => UserModel(id: '');

  int? get age => dateOfBirth == null ? null : XHelperFunctions.calculateAge(dateOfBirth!);

  String get firstName {
    final name = (fullName ?? '').trim();
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  factory UserModel.fromJson(Map<String, dynamic> json, {String email = ''}) {
    return UserModel(
      id: json['id'] as String,
      email: email,
      nutrisafeId: json['nutrisafe_id'] as String?,
      fullName: json['full_name'] as String?,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      activityLevel: json['activity_level'] as String?,
      dietaryPreference: json['dietary_preference'] as String?,
      location: json['location'] as String?,
      onboardingCompleted: json['onboarding_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'date_of_birth': dateOfBirth == null ? null : XHelperFunctions.toDbDate(dateOfBirth!),
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'activity_level': activityLevel,
      'dietary_preference': dietaryPreference,
      'location': location,
      'onboarding_completed': onboardingCompleted,
    };
  }
}
