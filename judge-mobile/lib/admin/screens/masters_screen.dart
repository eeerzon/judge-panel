// admin/contestants.html + admin/judges.html — event master data with
// search, status filter and add/edit drawer (admin-master.js).
// Photo is set by URL (file upload needs a picker plugin; not in this pass).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';

class AdminContestantsScreen extends StatelessWidget {
  const AdminContestantsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _MasterScreen(contestants: true);
}

class AdminJudgesScreen extends StatelessWidget {
  const AdminJudgesScreen({super.key});
  @override
  Widget build(BuildContext context) => const _MasterScreen(contestants: false);
}

class _MasterScreen extends StatefulWidget {
  const _MasterScreen({required this.contestants});
  final bool contestants;

  @override
  State<_MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<_MasterScreen> {
  String _term = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final c = widget.contestants;
    final term = _term.toLowerCase();
    final filterBar = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Flex(
        direction: AdminLayout.tiny(context) ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: AdminLayout.tiny(context) ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: AdminLayout.tiny(context) ? FlexFit.loose : FlexFit.tight,
            child: AdminSearchField(
              hint: c ? 'Search name, number' : 'Search name, number, email, or phone',
              onChanged: (t) => setState(() => _term = t),
            ),
          ),
          const SizedBox(width: 10, height: 10),
          SizedBox(
            width: AdminLayout.tiny(context) ? null : 200,
            child: AdminSelect<String>(
              value: _status,
              items: const [('all', 'Status: All'), ('active', 'Active'), ('inactive', 'Inactive')],
              onChanged: (v) => setState(() => _status = v),
            ),
          ),
        ],
      ),
    );

    final Widget body;
    if (c) {
      final rows = admin.contestants
          .where((x) =>
              (term.isEmpty || '${x.number} ${x.name} ${x.profesi}'.toLowerCase().contains(term)) &&
              (_status == 'all' || x.status == _status))
          .toList();
      body = rows.isEmpty
          ? const AdminStateCard(title: 'No contestants found', description: 'Try another search or add a new contestant.')
          : AdminGrid(
              columns: AdminLayout.tiny(context) ? 1 : (AdminLayout.narrow(context) ? 2 : (MediaQuery.sizeOf(context).width >= 1680 ? 4 : 3)),
              children: [
                for (final x in rows)
                  _ContestantCard(item: x, rounds: admin.roundsForContestant(x.id), onEdit: () => _openContestant(context, admin, x)),
              ],
            );
    } else {
      final rows = admin.judges
          .where((x) =>
              (term.isEmpty || '${x.displayNumber} ${x.name} ${x.email} ${x.phone}'.toLowerCase().contains(term)) &&
              (_status == 'all' || x.status == _status))
          .toList();
      final narrow = AdminLayout.narrow(context);
      body = rows.isEmpty
          ? const AdminStateCard(title: 'No judges found', description: 'Try another search or add a new judge.')
          : AdminList(
              header: narrow
                  ? null
                  : const AdminListHead(columns: [('Judge', 12), ('Contact', 10), ('Assigned rounds', 10), ('Status', 0), ('Action', 0)]),
              children: [
                for (final x in rows)
                  _JudgeRow(item: x, rounds: admin.roundsForJudge(x.id), onEdit: () => _openJudge(context, admin, x)),
              ],
            );
    }

    return AdminShell(activeNav: c ? 'contestants' : 'judges', children: [
      AdminPageHeader(
        title: c ? 'Contestants' : 'Judges',
        description: c
            ? 'Manage contestant identity, status, and round participation.'
            : 'Manage judge identity, contact details, status, and round participation.',
        actions: [
          c
            ? SizedBox.shrink()
            : AdminBtn(
                '+ Add Judge', 
                variant: AdminBtnVariant.primary, 
                onTap: () => _openJudge(context, admin, null)),
          // AdminBtn(c ? '+ Add Contestant' : '+ Add Judge',
          //     variant: AdminBtnVariant.primary,
          //     onTap: () => c ? _openContestant(context, admin, null) : _openJudge(context, admin, null)),
        ],
      ),
      filterBar,
      body,
    ]);
  }

  void _openContestant(BuildContext context, AdminStore admin, ContestantMaster? item) {
    final number = TextEditingController(text: '${item?.number ?? admin.contestants.length + 1}');
    final name = TextEditingController(text: item?.name ?? '');
    final profesi = TextEditingController(text: item?.profesi ?? '');
    final photo = TextEditingController(text: item?.photo ?? '');
    var status = TextEditingController(text: item?.status ?? 'active');
    showAdminDrawer<void>(
      context,
      title: item == null ? 'Detail Contestant' : 'Detail Contestant',
      body: (ctx, setState) {
        final words = name.text.trim();
        final preview = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Photo preview', style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 17, runSpacing: 10, children: [
            Container(
              width: 164,
              height: 206,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderStrong)),
              child: AdminPhoto(photo: photo.text.trim(), name: words.isEmpty ? '—' : words, initialsSize: 32),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${number.text.trim().isEmpty ? '' : '#${number.text.trim().padLeft(2, '0')} · '}${words.isEmpty ? 'New contestant' : words}',
                  style: ts(14, weight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(photo.text.trim().isEmpty ? 'No photo selected' : 'Photo URL preview',
                  style: ts(12, color: AppColors.textSecondary)),
            ]),
          ]),
        ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          preview,
          const SizedBox(height: 22),
          AdminFormField(
              label: 'Number',
              child: AdminTextField(controller: number, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), isEnabled: false)),
          const SizedBox(height: 22),
          AdminFormField(label: 'Name', child: AdminTextField(controller: name, onChanged: (_) => setState(() {}), isEnabled: false)),
          const SizedBox(height: 22),
          AdminFormField(label: 'Profession', child: AdminTextField(controller: profesi, isEnabled: false)),
          const SizedBox(height: 22),
          AdminFormField(
              label: 'Photo URL',
              child: AdminTextField(controller: photo, hint: 'https://…/photo.jpg', onChanged: (_) => setState(() {}), isEnabled: false)),
          const SizedBox(height: 22),
          AdminFormField(label: 'Status', child: AdminTextField(controller: status, isEnabled: false)),
            // child: AdminSelect<String>(
            //   value: status,
            //   items: const [('active', 'Active'), ('inactive', 'Inactive')],
            //   onChanged: (v) => setState(() => status = v),
            // ),
          
          const SizedBox(height: 22),
          Text(
              admin.connected
                  ? 'Contestant changes are stored on this device only (the contestant API is not available yet) '
                      'and are replaced by the server data on the next reload.'
                  : 'Changes are stored locally until the Admin API is available.',
              style: ts(12, color: AppColors.textSecondary, height: 1.5)),
        ]);
      },
      footer: (ctx, _) => [
        AdminBtn('Close', onTap: () => Navigator.of(ctx).pop()),
        // AdminBtn('Save changes', variant: AdminBtnVariant.primary, onTap: () {
        //   final id = item?.id ?? admin.nextContestantId();
        //   admin.saveContestant(ContestantMaster(
        //     id: id,
        //     number: int.tryParse(number.text.trim()) ?? id,
        //     name: name.text.trim().isEmpty ? 'Unnamed contestant' : name.text.trim(),
        //     profesi: profesi.text.trim().isEmpty ? '—' : profesi.text.trim(),
        //     photo: photo.text.trim(),
        //     status: status,
        //     externalId: item?.externalId, // keep the API link (id_finalis)
        //   ));
        //   Navigator.of(ctx).pop();
        // }),
      ],
    );
  }

  void _openJudge(BuildContext context, AdminStore admin, JudgeMaster? item) {
    final number = TextEditingController(text: item?.displayNumber ?? (admin.judges.length + 1).toString().padLeft(2, '0'));
    final name = TextEditingController(text: item?.name ?? '');
    final email = TextEditingController(text: item?.email ?? '');
    final phone = TextEditingController(text: item?.phone ?? '');
    final password = TextEditingController();
    var status = item?.status ?? 'active';
    var saving = false;
    String? error;
    final remote = admin.connected;
    showAdminDrawer<void>(
      context,
      title: item == null ? 'Add Judge' : 'Edit Judge',
      body: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminFormField(label: 'Display Number', child: AdminTextField(controller: number)),
        const SizedBox(height: 22),
        AdminFormField(label: 'Name', child: AdminTextField(controller: name)),
        const SizedBox(height: 22),
        AdminFormField(label: 'Email', child: AdminTextField(controller: email, keyboardType: TextInputType.emailAddress)),
        const SizedBox(height: 22),
        AdminFormField(label: 'Phone', child: AdminTextField(controller: phone, keyboardType: TextInputType.phone)),
        if (remote) ...[
          const SizedBox(height: 22),
          AdminFormField(
            label: item == null ? 'Password' : 'New Password',
            child: AdminTextField(
              controller: password,
              obscureText: true,
              hint: item == null ? 'At least 8 characters' : 'Leave empty to keep the current password',
            ),
          ),
        ],
        const SizedBox(height: 22),
        AdminFormField(
          label: 'Status',
          child: AdminSelect<String>(
            value: status,
            items: const [('active', 'Active'), ('inactive', 'Inactive')],
            onChanged: (v) => setState(() => status = v),
          ),
        ),
        if (remote && item != null && item.roles.isNotEmpty) ...[
          const SizedBox(height: 22),
          AdminFormField(
            label: 'Roles',
            child: Wrap(spacing: 5, runSpacing: 5, children: [for (final r in item.roles) AdminRoundChip(_roleLabel(r))]),
          ),
        ],
        const SizedBox(height: 22),
        if (error != null)
          Text(error!, style: ts(13, color: AppColors.statusErrorColor, height: 1.5))
        else if (!remote)
          Text('Changes are stored locally until the Admin API is available.',
              style: ts(12, color: AppColors.textSecondary, height: 1.5))
        else
          Text('Display Number is shown in this app only.', style: ts(12, color: AppColors.textSecondary, height: 1.5)),
      ]),
      footer: (ctx, setState) => [
        if (remote && item != null)
          AdminBtn('Delete', variant: AdminBtnVariant.danger, onTap: saving ? null : () => _deleteJudge(ctx, admin, item)),
        AdminBtn('Cancel', onTap: () => Navigator.of(ctx).pop()),
        AdminBtn(saving ? 'Saving…' : 'Save changes',
            variant: AdminBtnVariant.primary,
            onTap: saving
                ? null
                : () async {
                    if (remote && (name.text.trim().isEmpty || email.text.trim().isEmpty)) {
                      setState(() => error = 'Name and email are required.');
                      return;
                    }
                    if (remote && item == null && password.text.length < 8) {
                      setState(() => error = 'Password must be at least 8 characters.');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final id = item?.id ?? admin.nextJudgeId();
                    final result = await admin.submitJudge(
                      JudgeMaster(
                        id: id,
                        displayNumber: number.text.trim().isEmpty ? id.toString().padLeft(2, '0') : number.text.trim(),
                        name: name.text.trim().isEmpty ? 'Unnamed judge' : name.text.trim(),
                        email: email.text.trim(),
                        phone: phone.text.trim(),
                        status: status,
                        roles: item?.roles ?? const [],
                      ),
                      isNew: item == null,
                      password: password.text,
                    );
                    if (!ctx.mounted) return;
                    if (result.ok) {
                      Navigator.of(ctx).pop();
                    } else {
                      setState(() {
                        saving = false;
                        error = result.message;
                      });
                    }
                  }),
      ],
    );
  }

  /// Confirm, `DELETE /judge/admin/judges/{id}`, close the drawer.
  Future<void> _deleteJudge(BuildContext drawer, AdminStore admin, JudgeMaster item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAdminModal(
      drawer,
      title: 'Delete ${item.name}?',
      body: 'The judge account is removed from the judge master. This cannot be undone.',
      confirmLabel: 'Delete Judge',
      confirmVariant: AdminBtnVariant.danger,
      onConfirm: (_) => null,
    );
    if (!confirmed) return;
    final result = await admin.deleteJudge(item.id);
    if (result.ok && drawer.mounted) Navigator.of(drawer).pop();
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceRaised,
      content: Text(result.ok ? 'Judge deleted.' : result.message ?? 'Unable to delete the judge.', style: ts(14)),
    ));
  }
}

String _roleLabel(String role) =>
    role.split('_').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

Widget _roundChips(List<String> rounds) => rounds.isEmpty
    ? Text('No rounds assigned', style: ts(12, color: AppColors.textSecondary))
    : Wrap(spacing: 5, runSpacing: 5, children: [for (final r in rounds) AdminRoundChip(r)]);

/// `.admin-contestant-row` roster card (square photo, identity, rounds, status, Edit).
class _ContestantCard extends StatelessWidget {
  const _ContestantCard({required this.item, required this.rounds, required this.onEdit});
  final ContestantMaster item;
  final List<String> rounds;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: AdminPhoto(photo: item.photo, name: item.name, fit: BoxFit.contain, initialsSize: 42),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.numberLabel} · ${item.name}', style: ts(17, weight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 6),
              Text(item.profesi, style: ts(13, color: AppColors.textSecondary, height: 1.35)),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: _roundChips(rounds)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(children: [
              AdminStatus(item.active ? 'active' : 'inactive'),
              const Spacer(),
              AdminBtn('Detail', small: true, onTap: onEdit),
            ]),
          ),
        ]),
      );
}

/// `.admin-judge-row` (table in landscape, stacked ≤1100px).
class _JudgeRow extends StatelessWidget {
  const _JudgeRow({required this.item, required this.rounds, required this.onEdit});
  final JudgeMaster item;
  final List<String> rounds;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(AdminPhoto.initials(item.name), style: ts(12, weight: FontWeight.w800, color: AppColors.accent)),
    );
    final identity = Row(children: [
      avatar,
      const SizedBox(width: 12),
      Expanded(child: Text('Judge ${item.displayNumber} · ${item.name}', style: ts(14, weight: FontWeight.w700, height: 1.35))),
    ]);
    final contact = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.email, style: ts(13, height: 1.35)),
      const SizedBox(height: 4),
      Text(item.phone, style: ts(13, color: AppColors.textSecondary, height: 1.35)),
    ]);
    final status = AdminStatus(item.active ? 'active' : 'inactive');
    final edit = AdminBtn('Edit', small: true, onTap: onEdit);

    if (AdminLayout.narrow(context)) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          identity,
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: contact), const SizedBox(width: 16), status]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ROUNDS', style: ts(11, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacingEm: 0.06)),
                const SizedBox(height: 5),
                _roundChips(rounds),
              ]),
            ),
            const SizedBox(width: 16),
            edit,
          ]),
        ]),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(children: [
        Expanded(flex: 12, child: identity),
        const SizedBox(width: 14),
        Expanded(flex: 10, child: contact),
        const SizedBox(width: 14),
        Expanded(flex: 10, child: _roundChips(rounds)),
        const SizedBox(width: 14),
        SizedBox(width: 90, child: Align(alignment: Alignment.centerLeft, child: status)),
        const SizedBox(width: 14),
        SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: edit)),
      ]),
    );
  }
}
