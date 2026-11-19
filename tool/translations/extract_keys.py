"""Collect every translation key used by the app into assets/translations/_keys.json (sorted list)."""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(sys.argv[1])

from wrap_tr_lib import tokenize, unescape  # noqa: E402

# Files whose const label tables are translated where they are shown.
TABLE_FILES = {
    'lib/utils/constants/enums.dart': ['MealType', 'NutritionQuality', 'NutritionBasis'],
    'lib/features/medical_reports/models/medical_report_model.dart': None,
    'lib/features/family/screens/widgets/member_type_badge.dart': None,
    'lib/features/family/models/managed_profile_model.dart': None,
    'lib/features/family/models/family_member_model.dart': None,
    'lib/features/family/models/family_invitation_model.dart': None,
    'lib/features/personalization/controllers/profile_setup_controller.dart': None,
    'lib/features/family/controllers/managed_profile_form_controller.dart': None,
    'lib/features/personalization/screens/settings/ai_privacy_settings.dart': None,
    'lib/features/ai_agent/controllers/chat_controller.dart': None,
    'lib/common/widgets/texts/section_heading.dart': None,
}
SERVER_TEXTS = [
    # database functions (raise exception)
    'A NutriSafe ID cannot be changed.', 'A child profile must have at least one guardian',
    'A managed profile ID cannot be changed.', 'An invitation to this person is already pending.',
    'Choose a period of up to three months.', 'Create a family first.',
    'Each managed profile needs at least one guardian. Make someone else a guardian first.',
    'Enter a NutriSafe ID like NS-84K92P.', 'Enter a name of up to 80 characters.', 'Enter a valid date of birth.',
    'Invitation not found.', 'No NutriSafe account has this ID.', 'Not allowed.', 'Not authenticated',
    'Not signed in', 'Only the family admin can add members.', 'Only the family admin can create managed profiles.',
    'Only the family admin can do this', 'The owner of a record cannot be changed', 'This invitation is no longer open.',
    'This invitation is no longer pending.', 'This is your own NutriSafe ID.', 'This person is already in your family.',
    'Too many attempts. Please try again in an hour.',
    'You are already in a family. Leave it before accepting this invitation.',
    'You are already in a family. Leave it before creating a new one.',
    'This member is the only guardian of {name}. Make another family member a guardian of {name} first.',
    # notifications
    'Your family data permissions were updated', 'Open Family in NutriSafe to see what is shared with you.',
    'A new managed profile was created', 'Open Family in NutriSafe to see your family members.',
    'You have received a family invitation', 'Open Family in NutriSafe to accept or decline it.',
    'Your family invitation was accepted', 'Your family invitation was rejected',
    'The person you invited declined the invitation.', 'Your invitation was cancelled',
    'A family invitation sent to you was cancelled.',
    # edge functions
    'The AI service could not process this report.', 'This report is too long to read in one go.',
    'The AI did not return an answer. Please try again.', 'The AI service is busy. Please try again in a minute.',
    'The AI agent is not configured correctly (the AI API key was rejected).',
    'The AI service is unavailable right now. Please try again.',
    'Something went wrong while reading the report. Please try again.',
    'The AI agent is not configured yet (the AI API key is missing on the server).', 'Invalid request',
    'Allow AI reading of medical reports first.', 'Report not found',
    'You have analysed many reports in the last hour. Please try again later.',
    'This report has no results to explain yet.', 'The AI did not return an explanation. Please try again.',
    'The explanation could not be saved. Please try again.', 'Account deletion is not available right now.',
    'Could not delete your files. Please try again.', 'Could not delete the account. Please try again.',
    'Message is empty', 'You have sent many messages in the last hour. Please try again later.',
    'Could not start the conversation',
]


def literal_value(group):
    return ''.join(unescape(p[1]) if p[0] == 't' else '{' + p[1] + '}' for l in group for p in l.parts)


keys = set(SERVER_TEXTS)
for p in glob.glob('lib/**/*.dart', recursive=True):
    rel = p.replace(os.sep, '/')
    src = open(p, encoding='utf-8').read()
    lits = tokenize(src)
    groups = []
    for lit in lits:
        if groups and src[groups[-1][-1].end:lit.start].strip() == '':
            groups[-1].append(lit)
        else:
            groups.append([lit])
    for g in groups:
        end = g[-1].end
        after = src[end:end + 6]
        start = g[0].start
        before = src[max(0, start - 1):start]
        is_tr = after.startswith('.tr') and not after.startswith('.trim')
        # ('a' 'b').tr  (XTexts)
        if not is_tr:
            k = end
            while k < len(src) and src[k] in ' \n\r\t':
                k += 1
            if src[k:k + 4] == ').tr' and before in '(\n ' and rel.endswith('text_strings.dart'):
                is_tr = True
        if is_tr:
            if any(p[0] == 'e' for l in g for p in l.parts):
                print('WARN interpolation in key', rel, src[start:end][:80])
                continue
            keys.add(literal_value(g))
        elif rel in TABLE_FILES:
            v = literal_value(g)
            if re.search(r'[A-Za-z]{2,}', v) and not re.fullmatch(r'[a-z0-9_.\-]+', v) and '{' not in v \
                    and not re.fullmatch(r'[A-Z0-9_\-]+', v) and not v.startswith('package:') and not v.startswith('..'):
                keys.add(v)

keys.discard('')
out = sorted(keys)
os.makedirs('assets/translations', exist_ok=True)
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'keys.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=0)
print('keys', len(out))
