import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/admin/admin_models.dart';
import 'package:kreen_judge_mobile/admin/admin_nav.dart';
import 'package:kreen_judge_mobile/admin/admin_store.dart';
import 'package:kreen_judge_mobile/admin/screens/criteria_screen.dart';
import 'package:kreen_judge_mobile/admin/screens/round_results_screen.dart' show ResultScaleToggle;
import 'package:kreen_judge_mobile/admin/widgets/admin_ui.dart' show AdminCheckbox, AdminToggle;
import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/navigation/judge_nav.dart';
import 'package:kreen_judge_mobile/state/app_scope.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/judge_theme.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_judge_api.dart';

void main() {
  test('parses dashboard event, round and contestant JSON', () {
    final e = AdminEvent.fromApi(FakeAdminApi.eventJson('x', 'Event',
        rounds: {'total': 2, 'draft': 0, 'open': 1, 'closed': 0, 'finalized': 1}));
    expect(e.roundCounts.total, 2);
    expect(e.roundCounts.finalized, 1);
    expect(e.votingOpensAt, DateTime(2026, 9, 24, 10, 6));
    expect(e.grandFinalOn, DateTime(2026, 10, 2));

    final r = AdminRound.fromApi(FakeAdminApi.roundJson('60', 'TOP 5', 2, 'open', topN: 3, contestants: 5));
    expect((r.id, r.order, r.name, r.status, r.advancementCount, r.contestantsCount), ('60', 2, 'TOP 5', 'open', 3, 5));

    final c = ContestantMaster.fromApi(FakeAdminApi.contestantsJson[10], id: 4);
    expect((c.id, c.externalId, c.number, c.name, c.profesi, c.photo), (4, 'f11', 11, 'Finalis 11', '', ''));
  });

  test('opening an event loads API data and sizes prototype data from counts', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    expect(s.needsEvent, isTrue);
    await s.loadEvents();
    expect(s.events.map((e) => e.id), [FakeAdminApi.eventId, FakeAdminApi.emptyEventId]);

    expect(await s.openEvent(FakeAdminApi.eventId), isNull);
    expect(s.eventSettings.eventName, 'Testing Laravel 13 Final');
    expect(s.eventSettings.eventYear, '2026');
    expect(s.orderedRounds.map((r) => (r.id, r.status)), [('59', 'finalized'), ('60', 'open')]);
    expect(s.contestants.length, 11);
    expect(s.getRoundContestants('59').length, 9);
    expect(s.getRoundContestants('60').length, 5);
    expect(s.getRoundReadiness('60').judgesAssigned, 1);
    expect(s.getCriteria('59').length, 4);
    expect(s.getRoundReadiness('59').weightValid, isTrue);
    // Round data is the API's: criteria, official result, advancement info.
    expect(s.getCriteria('59').map((c) => c.name), ['Kerapian', 'Inisiatif', 'Moralitas', 'Kesigapan']);
    expect(s.getRoundResultStatus('59'), 'finalized');
    final top = s.calculateRoundResults('59').items.first;
    expect((top.name, top.combinedScore, top.rank), ('Finalis 1', 79.4, 1));
    expect(s.getMonitoringJudges('59').single.submissionStatus, 'submitted');
    expect(s.getMonitoringJudges('60').single.submissionStatus, 'in-progress');
    expect(s.getAdvancement('59'), isNull); // API `current` is empty
    expect(s.getDefaultAdvancementIds('59').length, 5);
    expect(s.validateAdvancement('59', s.getDefaultAdvancementIds('59'), '').message, contains('sudah open'));
    expect(s.activeRound?.id, '60');

    // Local ids stay stable per id_finalis across reloads.
    final id = s.contestants.firstWhere((c) => c.externalId == 'f3').id;
    await s.refreshEvent();
    expect(s.contestants.firstWhere((c) => c.externalId == 'f3').id, id);
  });

  test('judge master comes from the API; create / update / delete / roles call it', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    expect(s.judges.map((j) => (j.id, j.displayNumber, j.name)),
        [('281', '01', 'Admin Juri Free'), ('282', '02', 'Juri Free Satu'), ('283', '03', 'Juri Free Dua')]);
    expect(s.getJudge('281')!.roles, ['super_admin']);
    // judges_count 1 → the first API judge is assigned (prototype assignment).
    expect(s.getRoundJudges('60').map((e) => e.$2.id), ['281']);

    final added = await s.submitJudge(
      JudgeMaster(id: '', displayNumber: '', name: 'Juri Baru', email: 'baru@test.com', phone: '0812'),
      isNew: true,
      password: 'rahasia123',
    );
    expect(added.ok, isTrue);
    expect(api.judgeCalls.last, 'create baru@test.com rahasia123');
    expect(s.judges.last.name, 'Juri Baru');
    expect(s.judges.last.displayNumber, '04');

    final j = s.getJudge('282')!;
    await s.submitJudge(
      JudgeMaster(id: '282', displayNumber: '09', name: 'Juri Satu', email: j.email, phone: j.phone, status: 'inactive'),
      isNew: false,
    );
    expect(api.judgeCalls.last, 'update 282 ');
    expect((s.getJudge('282')!.name, s.getJudge('282')!.displayNumber, s.getJudge('282')!.active), ('Juri Satu', '09', false));

    await s.setJudgeRoles('283', [('super_admin', null)]);
    expect(s.getJudge('283')!.roles, ['super_admin']);

    expect((await s.deleteJudge('283')).ok, isTrue);
    expect(s.getJudge('283'), isNull);

    api.failNext = const ApiException('The email has already been taken.', statusCode: 422, fieldErrors: {
      'email': ['The email has already been taken.'],
    });
    final dup = await s.submitJudge(
      JudgeMaster(id: '', displayNumber: '', name: 'X', email: 'admin.free@test.com', phone: ''),
      isNew: true,
      password: 'rahasia123',
    );
    expect(dup.message, 'The email has already been taken.');
  });

  testWidgets('Judge drawer: password required on add, delete asks for confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final api = FakeAdminApi();
    final admin = AdminStore.memory(api: api);
    await admin.openEvent(FakeAdminApi.eventId);
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(judgeApi),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.judges))],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Juri Free Satu'), findsOneWidget);

    await tester.tap(find.text('+ Add Judge'));
    await tester.pumpAndSettle();
    // TextField 0 is the page search; the drawer has number, name, email, phone, password.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'Juri Tiga');
    await tester.enterText(fields.at(3), 'tiga@test.com');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
    await tester.enterText(fields.at(5), 'rahasia123');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(api.judgeCalls.last, 'create tiga@test.com rahasia123');
    expect(find.textContaining('Juri Tiga'), findsWidgets);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Roles'), findsOneWidget); // judge 281 has super_admin, read-only
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Judge'));
    await tester.pumpAndSettle();
    expect(api.judgeCalls.last, 'delete 281');
    expect(find.textContaining('Admin Juri Free'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('create round posts to the API and reloads the event', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    final result = await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    expect(result.ok, isTrue);
    expect(api.created.single['name'], 'Final');
    expect(s.orderedRounds.last.name, 'Final');
    expect(s.orderedRounds.last.status, 'draft');

    api.failNext = const ApiException('The name field is required.', statusCode: 422, fieldErrors: {
      'name': ['The name field is required.'],
    });
    final failed = await s.createRound(name: '', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    expect(failed.message, 'The name field is required.');
  });

  test('round actions call the Admin API and reload the round', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = s.orderedRounds.last.id;
    expect(s.getRoundContestants(id), isEmpty);

    // Contestants / judges / criteria on the draft round.
    final f1 = s.contestants.firstWhere((c) => c.externalId == 'f1').id;
    final f2 = s.contestants.firstWhere((c) => c.externalId == 'f2').id;
    expect(await s.setRoundContestantsAction(id, [f1, f2]), isNull);
    expect(s.getRoundContestants(id).map((c) => c.name), ['Finalis 1', 'Finalis 2']);
    expect(await s.setRoundContestantsAction(id, [f1]), isNull);
    expect(api.roundCalls.last, startsWith('remove contestant $id'));
    expect(await s.setJudgeAssignmentAction(id, '282', true), isNull);
    expect(s.getRoundReadiness(id).judgesAssigned, 1);
    // Unchecking Required = PATCH judges/{judgeId} {required:false} on the same assignment.
    expect(await s.setJudgeRequiredAction(id, '282', false), isNull);
    expect(api.roundCalls.last, 'update judge $id 282 required=false');
    expect(s.getRoundReadiness(id).requiredJudges, 0);
    api.ignoreRequired = true; // a server that drops `required` is reported
    expect(await s.setJudgeRequiredAction(id, '282', false), contains('did not save Optional'));
    api.ignoreRequired = false;
    expect(await s.setJudgeRequiredAction(id, '282', true), isNull); // a round needs a Required judge to open/close
    expect(s.getRoundReadiness(id).requiredJudges, 1);
    expect(
      await s.saveCriteriaAction(id, [AdminCriterion(id: 'new', roundId: id, name: 'Final Question', weight: 100, minScore: 0, maxScore: 100)]),
      isNull,
    );
    expect(api.roundCalls.last, 'create criterion $id Final Question 100.0');
    final criterion = s.getCriteria(id).single;
    expect((criterion.name, criterion.weight, criterion.step), ('Final Question', 100.0, 1.0));
    expect(s.canOpenRound(id), isFalse); // the previous round's advancement is not confirmed

    // Lifecycle.
    expect(await s.updateRoundAction(id, name: 'Grand Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: true), isNull);
    expect(s.getRound(id)!.name, 'Grand Final');
    expect(await s.openRoundAction(id), isNull);
    expect(s.getRound(id)!.status, 'open');
    api.sheets[id] = {'282': {for (final rc in api.roundContestantRows[id]!) rc.$1: 'submitted'}};
    await s.loadRound(id);
    expect(s.getRoundReadiness(id).readyToClose, isTrue);
    // Excuse / restore: PATCH assignment_status. The server stops listing an
    // excused judge; the store keeps it so Monitoring can still restore it.
    expect(await s.judgeGovernanceAction(id, '282', 'excuse', ''), 'A reason is required.');
    expect(await s.judgeGovernanceAction(id, '282', 'excuse', 'Sakit'), isNull);
    expect(api.roundCalls.last, 'update judge $id 282 excused (Sakit)');
    final excused = s.getMonitoringJudges(id).single;
    expect((excused.assignmentStatus, excused.submissionStatus), ('excused', 'excused'));
    await s.loadRound(id); // still kept after a reload
    expect(s.getMonitoringJudges(id).single.assignmentStatus, 'excused');
    expect(s.getRoundJudges(id).single.$1.excuseReason, 'Sakit');
    expect(await s.judgeGovernanceAction(id, '282', 'restore', ''), isNull);
    expect(api.roundCalls.last, 'update judge $id 282 assigned');
    expect(s.getMonitoringJudges(id).single.assignmentStatus, 'assigned');
    expect(s.getRoundReadiness(id).readyToClose, isTrue);
    expect(await s.reopenAction(id, '282', 'typo'), isNull);
    expect(api.roundCalls.last, startsWith('reopen $id'));
    expect(s.getMonitoringJudges(id).single.submissionStatus, 'reopened'); // in_progress + reopened_at
    api.sheets[id] = {'282': {for (final rc in api.roundContestantRows[id]!) rc.$1: 'submitted'}};
    await s.loadRound(id);
    expect(s.getMonitoringJudges(id).single.submissionStatus, 'resubmitted'); // submitted again after a reopen
    expect(await s.closeRoundAction(id), isNull);
    expect(s.getRoundResultStatus(id), 'provisional');
    expect(await s.finalizeAction(id), isNull);
    expect(s.getRoundResultStatus(id), 'finalized');
    expect(await s.setResultVisibilityAction(id, true), isNull);
    expect(s.isResultVisible(id), isTrue);

    // Result detail: per-judge criterion scores.
    await s.loadResultDetail('59', s.contestants.firstWhere((c) => c.externalId == 'f1').id);
    final entry = s.judgeScoreEntry('59', '281', s.contestants.firstWhere((c) => c.externalId == 'f1').id)!;
    expect((entry.total, entry.criteriaScores['53']), (80.0, 80.0));

    // Errors come back as messages; delete removes the round after reload.
    api.failNext = const ApiException('Ronde tidak bisa dibuka.', statusCode: 422);
    expect(await s.openRoundAction('59'), 'Ronde tidak bisa dibuka.');
    expect(await s.deleteRoundAction(id), isNull);
    await s.refreshEvent();
    expect(s.getRound(id), isNull);
  });

  test('a new parent group (no children yet) stays a parent after reload, so it can be picked as Parent', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = s.orderedRounds.last.id;
    expect(
      await s.saveCriteriaAction(id, [AdminCriterion(id: 'p', roundId: id, name: 'Interview', isParent: true, isScored: false)]),
      isNull,
    );
    await s.loadRound(id);
    final parent = s.getCriteria(id).single;
    expect((parent.name, parent.isParent, parent.isScored, parent.weight), ('Interview', true, false, 0.0));

    // Then a child pointing at it, as the editor does with the Parent dropdown.
    expect(
      await s.saveCriteriaAction(id, [
        ...s.getCriteria(id),
        AdminCriterion(id: 'c', roundId: id, name: 'Communication', parentId: parent.id, weight: 100),
      ]),
      isNull,
    );
    final child = s.getCriteria(id).firstWhere((c) => c.name == 'Communication');
    expect(child.parentId, parent.id);
    expect(s.getRoundReadiness(id).weightValid, isTrue);
  });

  testWidgets('Round Judges lists only active master judges (an assigned inactive one stays, flagged)', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final api = FakeAdminApi();
    // Live shape: /judge/admin/judges sends flag_aktif as 1 / 0.
    api.judgeRows.add({'id': '492', 'id_merchant': 'm', 'name': 'juri baru', 'email': 'juri.baru@tst.com', 'phone': '', 'flag_aktif': 0, 'capabilities': []});
    final admin = AdminStore.memory(api: api);
    await admin.openEvent(FakeAdminApi.eventId);
    await admin.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = admin.orderedRounds.last.id;
    Future<void> show() async {
      await tester.pumpWidget(AppScope(
        judge: JudgeStore(judgeApi),
        session: session,
        admin: admin,
        child: MaterialApp(
          theme: buildAppTheme(),
          onGenerateRoute: JudgeNav.onGenerateRoute,
          onGenerateInitialRoutes: (_) =>
              [JudgeNav.onGenerateRoute(RouteSettings(name: AdminRoutes.roundJudges, arguments: AdminRoundArgs(id)))],
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show();
    expect(find.textContaining('· Juri Free Satu'), findsOneWidget); // the assignment row
    expect(find.textContaining('juri baru'), findsNothing);

    // Assigned before it was deactivated: still listed, so it can be unassigned.
    api.roundJudgeRows[id] = [('492', true)];
    await admin.loadRound(id);
    await show();
    expect(find.textContaining('juri baru'), findsOneWidget);
    expect(find.text('Inactive in Judges · unassign or reactivate'), findsOneWidget);
    expect(find.text('juri.baru@tst.com'), findsOneWidget); // no trailing " · " without a phone
    expect(tester.takeException(), isNull);
  });

  test('criteria keep their hierarchy; Copy Configuration replaces the target criteria', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = s.orderedRounds.last.id;
    expect(
      await s.saveCriteriaAction(id, [
        AdminCriterion(id: 'p', roundId: id, name: 'Interview', isParent: true, isScored: false),
        AdminCriterion(id: 'c1', roundId: id, name: 'Communication', parentId: 'p', weight: 60, step: 0.5),
        AdminCriterion(id: 'c2', roundId: id, name: 'Gown', weight: 40),
      ]),
      isNull,
    );
    final saved = s.getCriteria(id);
    final parent = saved.firstWhere((c) => c.name == 'Interview');
    final child = saved.firstWhere((c) => c.name == 'Communication');
    expect((parent.isParent, child.parentId, child.step), (true, parent.id, 0.5));
    expect(s.getRoundReadiness(id).weightValid, isTrue);
    // Backend rules: step is numeric (never null); the empty parent is
    // is_scored:false without parent_id; the child points at its new id.
    expect(api.criterionBodies.every((b) => !b.containsKey('step') || b['step'] is num), isTrue);
    final sentParent = api.criterionBodies.firstWhere((b) => b['name'] == 'Interview');
    expect((sentParent['is_scored'], sentParent['parent_id'], sentParent['weight']), (false, null, 0));
    expect(api.criterionBodies.firstWhere((b) => b['name'] == 'Communication')['parent_id'], parent.id);

    // Detaching a child and turning its parent into a scored criterion:
    // the child is updated before the parent.
    api.criterionBodies.clear();
    expect(
      await s.saveCriteriaAction(id, [
        for (final c in s.getCriteria(id))
          c.id == parent.id
              ? (c..isParent = false..isScored = true..weight = 0)
              : c.id == child.id
                  ? (c..parentId = null)
                  : c,
      ]),
      isNull,
    );
    expect([for (final b in api.criterionBodies) b['name']], ['Communication', 'Interview']);

    // Copying twice from the previous round still gives 100%, not 200%.
    final previous = s.getPreviousRound(id)!.id;
    for (var i = 0; i < 2; i++) {
      expect(await s.copyConfigurationAction(previous, id, judges: false, criteria: true), isNull);
    }
    expect(s.getCriteria(id).map((c) => c.name), ['Kerapian', 'Inisiatif', 'Moralitas', 'Kesigapan']);
    expect(s.getRoundReadiness(id).effectiveScoredWeight, 100);
  });

  test('fewer finalists than Top N: advancement still confirms with all of them', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    api.roundRows[1]['promote_top_n'] = 10; // TOP 5 round: Top 10, but only 5 finalists
    api.sheets['60'] = {'281': {for (final rc in api.roundContestantRows['60']!) rc.$1: 'submitted'}};
    await s.loadRound('60');
    expect(await s.closeRoundAction('60'), isNull);
    expect(await s.finalizeAction('60'), isNull);
    expect(s.advancementSlots('60'), 5);
    final everyone = [for (final i in s.calculateRoundResults('60').items) i.contestantId];
    expect(s.validateAdvancement('60', everyone.take(4).toList(), 'x').ok, isFalse); // still all of them
    expect(await s.confirmAdvancementAction('60', everyone, 'All finalists advance'), isNull);
    expect(s.isAdvancementConfirmed('60'), isTrue);
  });

  test('advancement confirm / reset and event settings use the Admin API', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    expect(s.serverSettings?.scoreMode, 'per_round');
    expect(await s.saveServerSettings(s.serverSettings!.copyWith(favoritPromoteEnabled: true)), isNull);
    expect(api.settings.favoritPromoteEnabled, isTrue);

    // TOP 5 is open → the server blocks advancement from TOP 10.
    expect(await s.confirmAdvancementAction('59', s.getDefaultAdvancementIds('59'), ''), contains('sudah open'));

    // A new draft round after TOP 5: finalize TOP 5, then advance its Top 3.
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final finalId = s.orderedRounds.last.id;
    api.sheets['60'] = {'281': {for (final rc in api.roundContestantRows['60']!) rc.$1: 'submitted'}};
    await s.loadRound('60');
    expect(await s.closeRoundAction('60'), isNull);
    expect(await s.finalizeAction('60'), isNull);
    final top3 = s.getDefaultAdvancementIds('60');
    expect(top3.length, 3);
    // Double tap: the second request is refused while the first is in flight.
    final first = s.confirmAdvancementAction('60', top3, '');
    expect(await s.confirmAdvancementAction('60', top3, ''), 'Advancement for this round is already confirmed.');
    expect(await first, isNull);
    expect(s.isAdvancementConfirmed('60'), isTrue);
    expect(await s.confirmAdvancementAction('60', top3, ''), 'Advancement for this round is already confirmed.');
    expect(api.roundCalls.where((c) => c.startsWith('advance 60 ')).length, 1);
    expect(s.getAdvancement('60')?.selectedContestantIds, top3);
    expect(s.getAdvancementForTarget(finalId)?.sourceRoundId, '60'); // not "pending" any more
    expect(s.getRoundContestants(finalId).map((c) => c.id).toSet(), top3.toSet());

    expect(await s.resetAdvancementAction('60', 'x'), 'The reason must be at least 3 characters.');
    expect(await s.resetAdvancementAction('60', 'Withdrawal'), isNull);
    expect(api.roundCalls.last, 'reset advancement 60 Withdrawal');
    expect(s.getAdvancement('60'), isNull);
    expect(s.isAdvancementConfirmed('60'), isFalse); // a reset allows a new confirmation
    expect(s.getRoundContestants(finalId), isEmpty);
  });

  test('an event without rounds has no active round', () async {
    final s = AdminStore.memory(api: FakeAdminApi());
    await s.openEvent(FakeAdminApi.emptyEventId);
    expect(s.rounds, isEmpty);
    expect(s.activeRound, isNull);
  });

  for (final size in [const Size(1280, 800), const Size(852, 393)]) {
    testWidgets('API mode: events → every admin page at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final judgeApi = FakeJudgeApi();
      final session = SessionStore.memory(judgeApi);
      await session.login('owner@test.com', 'password123');
      final admin = AdminStore.memory(api: FakeAdminApi());
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(AppScope(
        judge: JudgeStore(judgeApi),
        session: session,
        admin: admin,
        child: MaterialApp(
          navigatorKey: key,
          theme: buildAppTheme(),
          onGenerateRoute: JudgeNav.onGenerateRoute,
          onGenerateInitialRoutes: JudgeNav.onGenerateInitialRoutes,
          initialRoute: AdminRoutes.overview,
        ),
      ));
      await tester.pumpAndSettle();
      // No event yet → the event list.
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Testing Laravel 13 Final'), findsOneWidget);
      await tester.ensureVisible(find.text('Manage Event →').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Event →').first);
      await tester.pumpAndSettle();
      expect(find.text('Judging Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final (route, args) in <(String, Object?)>[
        (AdminRoutes.rounds, null),
        (AdminRoutes.contestants, null),
        (AdminRoutes.judges, null),
        (AdminRoutes.live, null),
        (AdminRoutes.results, null),
        (AdminRoutes.settings, null),
        (AdminRoutes.audit, null),
        for (final id in ['59', '60']) ...[
          (AdminRoutes.roundOverview, AdminRoundArgs(id)),
          (AdminRoutes.monitoring, AdminRoundArgs(id)),
          (AdminRoutes.roundContestants, AdminRoundArgs(id)),
          (AdminRoutes.roundJudges, AdminRoundArgs(id)),
          (AdminRoutes.criteria, AdminRoundArgs(id)),
          (AdminRoutes.roundResults, AdminRoundArgs(id)),
          (AdminRoutes.advancement, AdminRoundArgs(id)),
        ],
        (AdminRoutes.submission, const AdminRoundArgs('59', judgeId: '1')),
        (AdminRoutes.resultDetail, AdminRoundArgs('59', contestantId: admin.contestants.first.id)),
      ]) {
        key.currentState!.pushReplacementNamed(route, arguments: args);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route $args');
      }
      key.currentState!.pushReplacementNamed(AdminRoutes.contestants);
      await tester.pumpAndSettle();
      expect(find.text('#11 · Finalis 11'), findsOneWidget);

      // Switch to the event without rounds.
      await tester.tap(find.text('Switch Event'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Manage Event →').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Event →').last);
      await tester.pumpAndSettle();
      expect(find.text('No rounds yet'), findsOneWidget);
      key.currentState!.pushReplacementNamed(AdminRoutes.rounds);
      await tester.pumpAndSettle();
      expect(find.text('No rounds yet'), findsOneWidget);
      key.currentState!.pushReplacementNamed(AdminRoutes.live);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Create Round drawer validates and creates', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final api = FakeAdminApi();
    final admin = AdminStore.memory(api: api);
    await admin.openEvent(FakeAdminApi.eventId);
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(judgeApi),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.rounds))],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Create Round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Round').last);
    await tester.pumpAndSettle();
    expect(find.text('Round name is required.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Grand Final');
    await tester.tap(find.text('Create Round').last);
    await tester.pumpAndSettle();
    expect(api.created.single['name'], 'Grand Final');
    expect(find.text('Grand Final'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings: Judge Mode theme list comes from the API and is saved to the event settings', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final adminApi = FakeAdminApi();
    final admin = AdminStore.memory(api: adminApi);
    await admin.openEvent(FakeAdminApi.eventId);
    final themes = JudgeThemeStore();
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(judgeApi),
      session: session,
      admin: admin,
      themes: themes,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.settings))],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Judge Mode Theme'), findsOneWidget);
    expect(themes.themes.map((t) => t.name), ['Default', 'Blue', 'Green']); // live list; id 0 = Default (red)
    expect(find.text('Default'), findsOneWidget);
    await tester.ensureVisible(find.text('Green'));
    await tester.tap(find.text('Green'));
    await tester.pumpAndSettle();
    expect(adminApi.settings.idTheme, 3); // PATCH settings id_theme
    expect(adminApi.settings.toApi()['id_theme'], 3);
    expect(themes.themeIdFor(FakeAdminApi.eventId), 3); // this device switches at once
    // Settings re-opened in the new theme: Admin pages follow the event theme.
    expect(AppColors.palette.accent, EventTheme.builtIn.firstWhere((t) => t.id == 3).paletteFor(light: false).accent);
    await tester.ensureVisible(find.text('Default'));
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(adminApi.settings.idTheme, 0); // back to Default = id_theme 0
    expect(themes.themeIdFor(FakeAdminApi.eventId), 0); // Default (red) on this device too
    expect(AppColors.palette.accent, EventTheme.builtIn.first.paletteFor(light: false).accent); // Default (red)
    expect(tester.takeException(), isNull);
  });

  test('criterion numbers: weight 0–100, whole Min < Max, step within the range', () {
    String? v(String w, String lo, String hi, String st) => validateCriterionScale(weight: w, min: lo, max: hi, step: st);
    expect(v('33.33', '1', '10', '0.25'), isNull);
    expect(v('-5', '1', '10', '0.25'), contains('Weight'));
    expect(v('120', '1', '10', '0.25'), contains('Weight'));
    expect(v('abc', '1', '10', '0.25'), contains('Weight'));
    expect(v('10', '1.5', '10', '0.25'), contains('whole numbers'));
    expect(v('10', '10', '5', '1'), contains('greater than Min'));
    expect(v('10', '1', '10', '0'), contains('Step'));
    expect(v('10', '1', '10', '20'), contains('Step'));
  });

  testWidgets('criterion form: no minus or letters can be typed; Min/Max take whole numbers only', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final admin = AdminStore.memory(api: FakeAdminApi());
    await admin.openEvent(FakeAdminApi.eventId);
    await admin.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(judgeApi),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [
          JudgeNav.onGenerateRoute(RouteSettings(name: AdminRoutes.criteria, arguments: AdminRoundArgs(admin.orderedRounds.last.id))),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Criterion'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    String text(int i) => tester.widget<TextField>(fields.at(i)).controller!.text;
    await tester.enterText(fields.at(1), '-12.345abc'); // Weight
    await tester.enterText(fields.at(2), '-1.5'); // Min
    await tester.enterText(fields.at(4), '0,5'); // Step (comma keyboard)
    await tester.pump();
    expect(text(1), isNot(contains('-')));
    expect(text(1), isNot(contains('a')));
    expect(text(2), isNot(contains('-')));
    expect(text(2), isNot(contains('.')));
    expect(text(4), '0.5');

    await tester.enterText(fields.at(1), '150');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Weight must be a number from 0 to 100.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Results toggle: percent by default, raw points (judges\' average total) when off', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final admin = AdminStore.memory(api: FakeAdminApi());
    await admin.openEvent(FakeAdminApi.eventId);
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(judgeApi),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) =>
            [JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.roundResults, arguments: AdminRoundArgs('59')))],
      ),
    ));
    await tester.pumpAndSettle();
    String? scoreOf(int row) {
      final texts = [
        for (final e in find.byType(RichText).evaluate())
          (e.widget as RichText).text.toPlainText(),
      ].where((t) => RegExp(r'^\S+ / \d+$').hasMatch(t)).toList();
      return row < texts.length ? texts[row] : null;
    }

    final scaleToggle = find.descendant(of: find.byType(ResultScaleToggle), matching: find.byType(AdminToggle));
    expect(admin.resultsAsPercent, isTrue);
    expect(scoreOf(0), '79.40 / 100'); // server avg_score (rank 1)

    await tester.tap(scaleToggle);
    await tester.pumpAndSettle();
    expect(admin.resultsAsPercent, isFalse);
    // Raw: 4 criteria × raw 80 from the one judge = 320 of Σ max 4 × 100.
    expect(scoreOf(0), '320 / 400');
    expect(find.textContaining('out of 400'), findsOneWidget);

    await tester.tap(scaleToggle);
    await tester.pumpAndSettle();
    expect(scoreOf(0), '79.40 / 100');
    expect(tester.takeException(), isNull);
  });

  test('an action reloads only what it changed (not the whole round)', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    await s.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = s.orderedRounds.last.id;

    api.gets.clear();
    expect(await s.setJudgeAssignmentAction(id, '282', true), isNull);
    expect(api.gets, unorderedEquals(['judges $id', 'monitoring $id']));

    api.gets.clear();
    final f1 = s.contestants.firstWhere((c) => c.externalId == 'f1').id;
    expect(await s.setRoundContestantsAction(id, [f1]), isNull);
    expect(api.gets, ['contestants $id']);

    api.gets.clear();
    expect(
      await s.saveCriteriaAction(id, [AdminCriterion(id: 'n', roundId: id, name: 'Q', weight: 100, minScore: 0, maxScore: 100)]),
      isNull,
    );
    expect(api.gets, ['criteria $id']);

    // A round opened for the first time still loads everything once.
    api.gets.clear();
    await s.loadRound('59', only: const {RoundPart.judges});
    expect(api.gets, ['judges 59']);
  });

  testWidgets('a tab loads only its data; tapping a contestant card toggles its checkbox', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final judgeApi = FakeJudgeApi();
    final session = SessionStore.memory(judgeApi);
    await session.login('owner@test.com', 'password123');
    final api = FakeAdminApi();
    final admin = AdminStore.memory(api: api);
    await admin.openEvent(FakeAdminApi.eventId);
    // A Draft round: only there the roster can be edited.
    await admin.createRound(name: 'Final', promoteMode: 'manual', promoteTopN: 1, favoritPromoteEnabled: false);
    final id = admin.orderedRounds.last.id;
    Future<void> open(String route) async {
      api.gets.clear();
      await tester.pumpWidget(AppScope(
        judge: JudgeStore(judgeApi),
        session: session,
        admin: admin,
        child: MaterialApp(
          key: UniqueKey(),
          theme: buildAppTheme(),
          onGenerateRoute: JudgeNav.onGenerateRoute,
          onGenerateInitialRoutes: (_) => [JudgeNav.onGenerateRoute(RouteSettings(name: route, arguments: AdminRoundArgs(id)))],
        ),
      ));
      await tester.pumpAndSettle();
    }

    await open(AdminRoutes.roundJudges);
    expect(api.gets, ['judges $id']);
    await open(AdminRoutes.criteria);
    expect(api.gets, ['criteria $id']);
    await open(AdminRoutes.roundContestants);
    expect(api.gets, ['contestants $id']);

    // Tap the card body (the name), not the checkbox.
    final checkbox = find.byType(AdminCheckbox).first;
    expect(tester.widget<AdminCheckbox>(checkbox).value, isFalse);
    await tester.tap(find.textContaining('· Finalis 1').first);
    await tester.pump();
    expect(tester.widget<AdminCheckbox>(checkbox).value, isTrue);
    await tester.tap(find.textContaining('· Finalis 1').first);
    await tester.pump();
    expect(tester.widget<AdminCheckbox>(checkbox).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('admin contestants show additional name, profession and age when the API has them', () async {
    final api = FakeAdminApi();
    final s = AdminStore.memory(api: api);
    await s.openEvent(FakeAdminApi.eventId);
    final f1 = s.contestants.firstWhere((c) => c.externalId == 'f1');
    expect(f1.details, 'Nama Tambahan 1 · Profesi / Aktivitas 1 · 25 yrs');
    final f11 = s.contestants.firstWhere((c) => c.externalId == 'f11'); // no extra data in the API
    expect(f11.details, '');
  });
}
