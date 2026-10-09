import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/admin/admin_models.dart';
import 'package:kreen_judge_mobile/admin/admin_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdminStore s;
  setUp(() => s = AdminStore.memory());

  test('seed readiness matches the prototype (Preliminary open, 5/7 required submitted)', () {
    final r = s.getRoundReadiness(1);
    expect((r.contestantsAssigned, r.judgesAssigned, r.requiredJudges, r.requiredSubmitted), (15, 7, 7, 5));
    expect(r.effectiveScoredWeight, 100);
    expect(r.readyToClose, isFalse);
    expect(s.closeRound(1), isFalse);
  });

  test('effective scored weight ignores non-scored parents', () {
    final c = s.getCriteria(1);
    expect(c.firstWhere((x) => x.id == 'interview').isParent, isTrue);
    expect(AdminStore.effectiveScoredWeight(c), 100);
  });

  test('configuration is locked outside Draft', () {
    expect(s.setRoundContestantAssignments(1, [1, 2]), isFalse);
    expect(s.setCriteria(1, []), isFalse);
  });

  test('governance: excuse needs a reason, remove refused with scoring activity, reopen keeps history', () {
    expect(s.updateJudgeAssignment(1, 4, 'excuse').ok, isFalse);
    expect(s.updateJudgeAssignment(1, 4, 'remove').ok, isFalse); // in progress
    expect(s.updateJudgeAssignment(1, 5, 'remove').ok, isTrue); // no activity
    expect(s.reopen(1, 1, '').ok, isFalse);
    expect(s.reopen(1, 1, 'Typo in Stage Presence').ok, isTrue);
    expect(s.getMonitoringJudges(1).firstWhere((j) => j.id == 1).submissionStatus, 'reopened');
    expect(s.getReopens(1).single.reason, 'Typo in Stage Presence');
    expect(s.getAuditEvents().map((e) => e.type), containsAll(['reopen', 'remove']));
  });

  test('full lifecycle: close → results → finalize → visibility → advancement → open next round', () {
    expect(s.updateJudgeAssignment(1, 4, 'excuse', 'Unwell').ok, isTrue);
    expect(s.updateJudgeAssignment(1, 5, 'excuse', 'Delayed flight').ok, isTrue);
    expect(s.getRoundReadiness(1).readyToClose, isTrue);

    expect(s.calculateRoundResults(1).available, isFalse); // still open
    expect(s.closeRound(1), isTrue);

    final result = s.calculateRoundResults(1);
    expect(result.available, isTrue);
    expect(result.eligibleJudgeCount, 5);
    expect(result.items.length, 15);
    expect(result.items.first.rank, 1);
    final excused = result.items.first.judgeScores.firstWhere((j) => j.judgeId == 4);
    expect((excused.included, excused.exclusion), (false, 'Excused — Not Counted'));

    if (result.hasTie) {
      expect(s.finalizeResults(1), isFalse);
      expect(s.acknowledgeTie(1), isTrue);
    }
    expect(s.setResultVisibility(1, true), isFalse); // not finalized yet
    expect(s.finalizeResults(1), isTrue);
    expect(s.getRound(1)!.status, 'finalized');
    expect(s.isResultVisible(1), isFalse); // default OFF
    expect(s.setResultVisibility(1, true), isTrue);
    expect(s.isResultVisible(1), isTrue);

    // Round 2 cannot open before advancement.
    expect(s.canOpenRound(2), isFalse);
    final top10 = s.getDefaultAdvancementIds(1);
    expect(top10.length, 10);
    final manual = [...top10.take(9), result.items.last.contestantId];
    expect(s.confirmAdvancement(1, manual, '').ok, isFalse); // manual needs reason
    expect(s.confirmAdvancement(1, top10, '').ok, isTrue);
    expect(s.getRoundContestants(2).map((c) => c.id).toSet(), top10.toSet());
    expect(s.getAdvancementForTarget(2)!.method, 'top_n');

    expect(s.canOpenRound(2), isTrue);
    expect(s.openRound(2), isTrue);
    expect(s.getRound(2)!.status, 'open');
    expect(s.resetAdvancement(1, 'too late'), isFalse); // target already open
  });

  test('copy configuration only into the next Draft round', () {
    expect(s.copyRoundConfiguration(1, 3, judges: true, criteria: true), isFalse); // not next
    expect(s.copyRoundConfiguration(1, 2, judges: false, criteria: false), isFalse);
    expect(s.copyRoundConfiguration(1, 2, judges: false, criteria: true), isTrue);
    expect(s.getCriteria(2).map((c) => c.id), s.getCriteria(1).map((c) => c.id));
  });

  test('event settings validation-free store + defaults', () {
    expect(s.eventSettings.minScore, 1);
    s.setEventSettings(s.eventSettings.copyWith(eventName: 'KQP 2027'));
    expect(s.eventSettings.eventName, 'KQP 2027');
    expect(s.eventSettings == const EventSettings(), isFalse);
  });
}
