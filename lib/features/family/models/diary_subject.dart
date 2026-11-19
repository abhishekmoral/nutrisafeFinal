/// -- Whose food diary is being shown or written to, and what the viewer may do there.
/// Exactly one subject: a managed profile ([childId]) or an adult account ([ownerId]).
class DiarySubject {
  const DiarySubject._({
    required this.name,
    this.ownerId,
    this.childId,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
  });

  /// A managed profile: its guardians and caregivers keep its diary.
  const DiarySubject.managed({required String name, required String childId})
    : this._(name: name, childId: childId, canAdd: true, canEdit: true, canDelete: true);

  /// Another adult's diary, with the permissions they granted.
  const DiarySubject.sharedAdult({
    required String name,
    required String ownerId,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
  }) : this._(name: name, ownerId: ownerId, canAdd: canAdd, canEdit: canEdit, canDelete: canDelete);

  final String name;
  final String? ownerId; // set for an adult's diary
  final String? childId; // set for a managed profile's diary
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  bool get isManaged => childId != null;
}
