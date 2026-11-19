import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/family/controllers/add_member_controller.dart';
import 'package:nutrisafe/features/family/models/diary_subject.dart';
import 'package:nutrisafe/features/family/models/family_invitation_model.dart';
import 'package:nutrisafe/features/family/models/family_member_model.dart';
import 'package:nutrisafe/features/family/models/managed_profile_model.dart';

void main() {
  group('NutriSafe ID input', () {
    test('accepts the ways people type an ID (same rules as the server)', () {
      expect(AddMemberController.normalize('NS-84K92P'), 'NS-84K92P');
      expect(AddMemberController.normalize('ns 84k92p'), 'NS-84K92P');
      expect(AddMemberController.normalize('NS84K92P'), 'NS-84K92P');
      expect(AddMemberController.normalize('84k92p'), 'NS-84K92P');
    });

    test('rejects text that cannot be an ID', () {
      expect(AddMemberController.normalize(''), isNull);
      expect(AddMemberController.normalize('NS-84K92'), isNull); // too short
      expect(AddMemberController.normalize('NS-84K92PQ'), isNull); // too long
      expect(AddMemberController.normalize('NS-84O92P'), isNull); // letter O is never used
      expect(AddMemberController.normalize('NS-841I2P'), isNull); // 1 and I are never used
      expect(AddMemberController.normalize('someone@mail.com'), isNull);
    });
  });

  group('DiarySubject', () {
    test('a managed profile diary can be kept fully by its carers', () {
      const s = DiarySubject.managed(name: 'Aarav', childId: 'c1');
      expect(s.isManaged, isTrue);
      expect(s.ownerId, isNull);
      expect([s.canAdd, s.canEdit, s.canDelete], [true, true, true]);
    });

    test("another adult's diary allows exactly what they granted", () {
      const s = DiarySubject.sharedAdult(name: 'Rahul', ownerId: 'u1', canAdd: true, canEdit: false, canDelete: false);
      expect(s.isManaged, isFalse);
      expect(s.childId, isNull);
      expect([s.canAdd, s.canEdit, s.canDelete], [true, false, false]);
    });
  });

  group('Family models', () {
    test('member from get_family_members()', () {
      final m = FamilyMemberModel.fromJson({
        'user_id': 'u1',
        'role': 'admin',
        'full_name': 'Rahul Sharma',
        'nutrisafe_id': 'NS-84K92P',
        'joined_at': '2026-11-15T09:00:00Z',
      });
      expect(m.isAdmin, isTrue);
      expect(m.initial, 'R');
      expect(m.nutrisafeId, 'NS-84K92P');
    });

    test('a member without a name is shown as a NutriSafe user', () {
      final m = FamilyMemberModel.fromJson({'user_id': 'u2', 'role': 'member', 'joined_at': '2026-11-15T09:00:00Z'});
      expect(m.displayName, 'NutriSafe user');
      expect(m.isAdmin, isFalse);
    });

    test('managed profile list row has a role only for carers', () {
      final p = ManagedProfileModel.fromListJson({
        'id': 'c1',
        'managed_id': 'MP-7QK3RD',
        'full_name': 'Aarav Sharma',
        'relationship': 'child',
        'my_role': null,
      });
      expect(p.canCare, isFalse);
      expect(p.isGuardian, isFalse);
      expect(p.relationshipLabel, 'Child');
      final g = ManagedProfileModel.fromListJson({...{'id': 'c1', 'managed_id': 'MP-7QK3RD', 'full_name': 'A'}, 'my_role': 'caregiver'});
      expect(g.canCare, isTrue);
      expect(g.isGuardian, isFalse);
    });

    test('invitation status labels', () {
      final i = FamilyInvitationModel.sent({
        'id': 'i1',
        'status': 'revoked',
        'created_at': '2026-11-15T09:00:00Z',
        'expires_at': '2026-11-22T09:00:00Z',
        'invitee_name': 'Meera',
        'invitee_nutrisafe_id': 'NS-2345AB',
      });
      expect(i.statusLabel, 'Cancelled');
      expect(i.isPending, isFalse);
    });

    test('account lookup contains no internal id', () {
      final a = AccountLookupModel.fromJson({'nutrisafe_code': 'NS-84K92P', 'display_name': 'Rahul', 'relation': 'none'});
      expect(a.nutrisafeId, 'NS-84K92P');
      expect(a.relation, 'none');
    });

    test('every sharing permission from the PRD is offered', () {
      expect(FamilyScope.all.map((s) => s.$1).toSet(), {
        'view_profile', 'view_food_diary', 'add_food', 'edit_food', 'delete_food', 'view_allergies', 'view_insights',
      });
      expect(FamilyScope.label('add_food'), 'Add food');
    });
  });
}
