import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/approvals/presentation/bloc/approval_cubit.dart';
import 'package:asoud_pwa/features/approvals/presentation/approval_policy_form.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ApprovalPage extends StatelessWidget {
  const ApprovalPage({
    required this.context,
    required this.gateway,
    this.initialView = ApprovalView.incoming,
    super.key,
  });

  final WorkContext context;
  final ApprovalGateway gateway;
  final ApprovalView initialView;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ApprovalCubit(
          gateway: gateway,
          context: this.context,
          initialView: initialView,
        )..load(),
        child: _ApprovalWorkspace(
          workContext: this.context,
          gateway: gateway,
        ),
      );
}

class _ApprovalWorkspace extends StatelessWidget {
  const _ApprovalWorkspace({
    required this.workContext,
    required this.gateway,
  });

  final WorkContext workContext;
  final ApprovalGateway gateway;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ApprovalCubit, ApprovalState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        },
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffedf3ff),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      color: Color(0xff155bd7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'کارتابل و گردش تأیید',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          workContext.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'به‌روزرسانی',
                    onPressed: context.read<ApprovalCubit>().load,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        state.acting ? null : () => _startRequest(context),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('ارسال سند برای تأیید'),
                  ),
                ],
              ),
            ),
            _ViewNavigation(
              selected: state.view,
              select: context.read<ApprovalCubit>().changeView,
            ),
            const Divider(height: 1),
            if (_isInbox(state.view))
              _ApprovalToolbar(
                view: state.view,
                query: state.query,
                status: state.status,
              ),
            Expanded(
              child: _ApprovalContent(
                state: state,
                workContext: workContext,
                gateway: gateway,
              ),
            ),
          ],
        ),
      );

  Future<void> _startRequest(BuildContext context) async {
    final cubit = context.read<ApprovalCubit>();
    final source = await _startRequestDialog(context);
    if (source == null) return;
    final ok = await cubit.start(source.$1, source.$2);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('درخواست تأیید ارسال شد.')),
      );
    }
  }
}

bool _isInbox(ApprovalView view) =>
    view == ApprovalView.incoming ||
    view == ApprovalView.outgoing ||
    view == ApprovalView.history;

class _ViewNavigation extends StatelessWidget {
  const _ViewNavigation({required this.selected, required this.select});

  final ApprovalView selected;
  final ValueChanged<ApprovalView> select;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _item(ApprovalView.incoming, 'کارتابل من', Icons.inbox_outlined),
            _item(ApprovalView.outgoing, 'ارسالی‌ها', Icons.outbox_outlined),
            _item(ApprovalView.history, 'تاریخچه', Icons.history),
            _item(
              ApprovalView.policies,
              'مسیرهای تأیید',
              Icons.account_tree_outlined,
            ),
            _item(
              ApprovalView.access,
              'کاربران و دسترسی',
              Icons.manage_accounts_outlined,
            ),
          ],
        ),
      );

  Widget _item(ApprovalView view, String label, IconData icon) {
    final active = selected == view;
    return InkWell(
      onTap: () => select(view),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xff155bd7) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? const Color(0xff155bd7) : null,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xff155bd7) : null,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalToolbar extends StatefulWidget {
  const _ApprovalToolbar({
    required this.view,
    required this.query,
    required this.status,
  });

  final ApprovalView view;
  final String query;
  final String status;

  @override
  State<_ApprovalToolbar> createState() => _ApprovalToolbarState();
}

class _ApprovalToolbarState extends State<_ApprovalToolbar> {
  late final TextEditingController search =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant _ApprovalToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != search.text) search.text = widget.query;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xfff8fafd),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth < 420 ? constraints.maxWidth : 360,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    hintText: 'جست‌وجوی شماره، سند، درخواست‌کننده یا مسیر',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'جست‌وجو',
                      onPressed: () => context
                          .read<ApprovalCubit>()
                          .applySearch(search.text),
                      icon: const Icon(Icons.arrow_back, size: 18),
                    ),
                  ),
                  onSubmitted: context.read<ApprovalCubit>().applySearch,
                ),
              ),
              if (widget.view != ApprovalView.incoming)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: widget.status.isEmpty ? '' : widget.status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'وضعیت'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('همه وضعیت‌ها')),
                      DropdownMenuItem(
                          value: 'Pending', child: Text('در انتظار')),
                      DropdownMenuItem(
                          value: 'Approved', child: Text('تأییدشده')),
                      DropdownMenuItem(value: 'Rejected', child: Text('ردشده')),
                      DropdownMenuItem(
                          value: 'Returned', child: Text('بازگشتی')),
                      DropdownMenuItem(
                          value: 'Invalidated', child: Text('باطل‌شده')),
                    ],
                    onChanged: (value) =>
                        context.read<ApprovalCubit>().applyStatus(value ?? ''),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  widget.view == ApprovalView.incoming
                      ? 'درخواست‌های قابل اقدام برای کاربر جاری'
                      : widget.view == ApprovalView.outgoing
                          ? 'درخواست‌های ایجادشده توسط من'
                          : 'سوابق نهایی‌شده و قابل مشاهده',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ApprovalContent extends StatelessWidget {
  const _ApprovalContent({
    required this.state,
    required this.workContext,
    required this.gateway,
  });

  final ApprovalState state;
  final WorkContext workContext;
  final ApprovalGateway gateway;

  @override
  Widget build(BuildContext context) {
    if (state.phase == ApprovalPhase.loading ||
        state.phase == ApprovalPhase.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.phase == ApprovalPhase.failure) {
      return _ErrorPanel(
        error: state.error,
        retry: context.read<ApprovalCubit>().load,
      );
    }
    if (state.view == ApprovalView.policies) {
      Future<void> openForm([ApprovalPolicySummary? policy]) async {
        final draft = await showApprovalPolicyForm(
          context,
          workspace: state.policyWorkspace,
          policy: policy,
        );
        if (draft == null || !context.mounted) return;
        final saved = await context.read<ApprovalCubit>().savePolicy(draft);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved
                ? 'مسیر تأیید با موفقیت ذخیره شد.'
                : 'ذخیره مسیر تأیید انجام نشد.'),
          ),
        );
      }

      return _PolicyTable(
        workspace: state.policyWorkspace,
        saving: state.policySaving,
        onCreate: openForm,
        onEdit: openForm,
      );
    }
    if (state.view == ApprovalView.access) {
      return _AccessTable(
        overview: state.access ?? const AccessOverview(users: []),
        context: workContext,
        gateway: gateway,
        refresh: context.read<ApprovalCubit>().load,
      );
    }
    final list = _InboxTable(
      inbox: state.inbox ??
          const ApprovalInbox(
            items: [],
            incomingCount: 0,
            outgoingCount: 0,
            historyCount: 0,
          ),
      onOpen: context.read<ApprovalCubit>().openDetail,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final detail = _ApprovalDetailPane(state: state);
        if (constraints.maxWidth >= 1150 &&
            (state.detail != null || state.detailLoading)) {
          return Row(
            children: [
              Expanded(child: list),
              const VerticalDivider(width: 1),
              SizedBox(width: 470, child: detail),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: list),
            if (state.detail != null || state.detailLoading)
              Positioned(
                top: 8,
                bottom: 8,
                left: 8,
                width: constraints.maxWidth.clamp(360, 470),
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: detail,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InboxTable extends StatelessWidget {
  const _InboxTable({
    required this.inbox,
    required this.onOpen,
  });

  final ApprovalInbox inbox;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CounterCard(
                  title:
                      '\u062f\u0631 \u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0642\u062f\u0627\u0645 \u0645\u0646',
                  count: inbox.incomingCount,
                  color: Colors.orange,
                ),
                _CounterCard(
                  title:
                      '\u062f\u0631\u062e\u0648\u0627\u0633\u062a\u200c\u0647\u0627\u06cc \u0628\u0627\u0632 \u0645\u0646',
                  count: inbox.outgoingCount,
                  color: Colors.blue,
                ),
                _CounterCard(
                  title: 'سوابق نهایی‌شده من',
                  count: inbox.historyCount,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (inbox.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      '\u062f\u0631\u062e\u0648\u0627\u0633\u062a\u06cc \u062f\u0631 \u0627\u06cc\u0646 \u0628\u062e\u0634 \u0648\u062c\u0648\u062f \u0646\u062f\u0627\u0631\u062f.',
                    ),
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - 34,
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('\u0633\u0646\u062f')),
                        DataColumn(
                            label: Text('\u0634\u0645\u0627\u0631\u0647')),
                        DataColumn(
                            label: Text(
                                '\u062f\u0631\u062e\u0648\u0627\u0633\u062a\u200c\u06a9\u0646\u0646\u062f\u0647')),
                        DataColumn(label: Text('\u0645\u0628\u0644\u063a')),
                        DataColumn(
                            label: Text('\u0645\u0631\u062d\u0644\u0647')),
                        DataColumn(
                            label: Text('\u0648\u0636\u0639\u06cc\u062a')),
                      ],
                      rows: inbox.items
                          .map(
                            (item) => DataRow(
                              onSelectChanged: (_) => onOpen(item.name),
                              cells: [
                                DataCell(
                                    Text(_doctypeLabel(item.sourceDoctype))),
                                DataCell(Text(item.sourceName)),
                                DataCell(Text(item.requestedBy)),
                                DataCell(Text(_amount(item.amount))),
                                DataCell(Text(item.currentSequence.toString())),
                                DataCell(_StatusChip(status: item.status)),
                              ],
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ApprovalDetailPane extends StatelessWidget {
  const _ApprovalDetailPane({required this.state});

  final ApprovalState state;

  @override
  Widget build(BuildContext context) {
    if (state.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = state.detail;
    if (detail == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xffdfe5ee)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'جزئیات درخواست ${detail.summary.name}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'بستن جزئیات',
                  onPressed: context.read<ApprovalCubit>().closeDetail,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _doctypeLabel(detail.summary.sourceDoctype),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            detail.summary.sourceName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: detail.summary.status),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailValue(
                  icon: Icons.apartment_outlined,
                  label: 'زمینه',
                  value:
                      '${detail.summary.company}${detail.summary.branch == null ? '' : ' / ${detail.summary.branch}'}',
                ),
                _DetailValue(
                  icon: Icons.person_outline,
                  label: 'درخواست‌کننده',
                  value: detail.summary.requestedBy,
                ),
                _DetailValue(
                  icon: Icons.payments_outlined,
                  label: 'مبلغ',
                  value: _amount(detail.summary.amount),
                ),
                _DetailValue(
                  icon: Icons.account_tree_outlined,
                  label: 'سیاست',
                  value: detail.summary.policy,
                ),
                const Divider(height: 28),
                Text(
                  'مسیر تأیید',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (final stage in detail.stages)
                  _StageTile(
                    stage: stage,
                    current: detail.summary.status == 'Pending' &&
                        stage.sequence == detail.summary.currentSequence,
                    completed:
                        stage.sequence < detail.summary.currentSequence ||
                            detail.summary.status == 'Approved',
                  ),
                const Divider(height: 28),
                Text(
                  'تاریخچه اقدامات',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (detail.actions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('هنوز اقدامی ثبت نشده است.'),
                    ),
                  ),
                for (final action in detail.actions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Icon(_actionIcon(action.action), size: 17),
                    ),
                    title: Text(
                      '${_actionLabel(action.action)} — ${action.actor}',
                    ),
                    subtitle: Text(
                      '${action.actedOn}${action.comment.isEmpty ? '' : '\n${action.comment}'}',
                    ),
                  ),
              ],
            ),
          ),
          if (detail.canAct && detail.summary.status == 'Pending')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xfff8fafd),
                border: Border(
                  top: BorderSide(color: Color(0xffdfe5ee)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.acting
                          ? null
                          : () => _perform(context, 'Approve'),
                      icon: const Icon(Icons.check),
                      label: const Text('تأیید'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: 'بازگشت برای اصلاح',
                    onPressed:
                        state.acting ? null : () => _perform(context, 'Return'),
                    icon: const Icon(Icons.undo),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: 'رد درخواست',
                    onPressed:
                        state.acting ? null : () => _perform(context, 'Reject'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _perform(BuildContext context, String action) async {
    final comment = await _commentDialog(
      context,
      required: action != 'Approve',
    );
    if (comment == null || !context.mounted) return;
    final ok = await context.read<ApprovalCubit>().act(action, comment);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_actionLabel(action)} با موفقیت ثبت شد.')),
      );
    }
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xff68758a)),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff68758a),
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.stage,
    required this.current,
    required this.completed,
  });

  final ApprovalStage stage;
  final bool current;
  final bool completed;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: current
              ? const Color(0xffedf3ff)
              : completed
                  ? const Color(0xffeaf8f1)
                  : const Color(0xfff7f9fc),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: current ? const Color(0xff9ebeff) : const Color(0xffdfe5ee),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: completed
                  ? const Color(0xff1c9b62)
                  : current
                      ? const Color(0xff155bd7)
                      : const Color(0xffdfe5ee),
              foregroundColor:
                  completed || current ? Colors.white : const Color(0xff68758a),
              child: Icon(
                completed ? Icons.check : Icons.pending_outlined,
                size: 16,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stage.sequence}. ${stage.title}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    stage.approver,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff68758a),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PolicyTable extends StatelessWidget {
  const _PolicyTable({
    required this.workspace,
    required this.saving,
    required this.onCreate,
    required this.onEdit,
  });

  final ApprovalPolicyWorkspace workspace;
  final bool saving;
  final Future<void> Function() onCreate;
  final Future<void> Function(ApprovalPolicySummary policy) onEdit;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.account_tree_outlined,
                color: Color(0xff246bfd),
              ),
              title: const Text(
                'مدیریت مسیرهای تأیید',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'تعریف سیاست و مراحل در محدوده شرکت و شعبه فعال',
              ),
              trailing: FilledButton.icon(
                onPressed: saving ? null : onCreate,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('مسیر تأیید جدید'),
              ),
            ),
          ),
          if (workspace.policies.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  '\u0645\u0633\u06cc\u0631 \u0641\u0639\u0627\u0644\u06cc \u0628\u0631\u0627\u06cc \u0627\u06cc\u0646 \u0645\u062d\u06cc\u0637 \u062a\u0639\u0631\u06cc\u0641 \u0646\u0634\u062f\u0647 \u0627\u0633\u062a.',
                ),
              ),
            ),
          for (final policy in workspace.policies)
            Card(
              child: ListTile(
                onTap: saving ? null : () => onEdit(policy),
                leading: CircleAvatar(
                  backgroundColor: policy.enabled
                      ? const Color(0xffeaf7ef)
                      : const Color(0xfff0f2f5),
                  child: Icon(
                    Icons.route_outlined,
                    color: policy.enabled
                        ? const Color(0xff15803d)
                        : const Color(0xff68758a),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        policy.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(policy.enabled ? 'فعال' : 'غیرفعال'),
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('نسخه ${policy.version}'),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${_doctypeLabel(policy.documentType)}'
                  ' — ${policy.parallelMode == 'All' ? '\u062a\u0623\u06cc\u06cc\u062f \u0647\u0645\u0647' : '\u062a\u0623\u06cc\u06cc\u062f \u06cc\u06a9 \u0646\u0641\u0631'}',
                ),
                trailing: IconButton(
                  tooltip: 'ویرایش مسیر',
                  onPressed: saving ? null : () => onEdit(policy),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
        ],
      );
}

class _AccessTable extends StatelessWidget {
  const _AccessTable({
    required this.overview,
    required this.context,
    required this.gateway,
    required this.refresh,
  });

  final AccessOverview overview;
  final WorkContext context;
  final ApprovalGateway gateway;
  final Future<void> Function() refresh;

  @override
  Widget build(BuildContext buildContext) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text(
                '\u062f\u0633\u062a\u0631\u0633\u06cc\u200c\u0647\u0627 \u0628\u0631\u0627\u0633\u0627\u0633 \u0634\u0631\u06a9\u062a \u0648 \u0634\u0639\u0628\u0647 \u0627\u0639\u0645\u0627\u0644 \u0648 \u062f\u0631 Backend \u062f\u0648\u0628\u0627\u0631\u0647 \u06a9\u0646\u062a\u0631\u0644 \u0645\u06cc\u200c\u0634\u0648\u0646\u062f.',
              ),
            ),
          ),
          if (overview.users.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  '\u06a9\u0627\u0631\u0628\u0631\u06cc \u062f\u0631 \u0627\u06cc\u0646 \u0645\u062d\u062f\u0648\u062f\u0647 \u062a\u0639\u0631\u06cc\u0641 \u0646\u0634\u062f\u0647 \u0627\u0633\u062a.',
                ),
              ),
            ),
          for (final grant in overview.users)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    grant.fullName.isEmpty
                        ? '?'
                        : grant.fullName.characters.first,
                  ),
                ),
                title:
                    Text(grant.fullName.isEmpty ? grant.user : grant.fullName),
                subtitle: Text(
                  '${grant.user}\n'
                  '${grant.branch ?? '\u06a9\u0644 \u0634\u0631\u06a9\u062a'}'
                  '${grant.roles.isEmpty ? '' : ' — ${grant.roles.join('، ')}'}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    if (grant.holdingManager)
                      const Chip(
                        label: Text(
                            '\u0645\u062f\u06cc\u0631 \u0647\u0644\u062f\u06cc\u0646\u06af'),
                      ),
                    Switch(
                      value: grant.enabled,
                      onChanged: (enabled) async {
                        try {
                          await gateway.setAccess(
                            context: context,
                            grant: grant,
                            enabled: enabled,
                            holdingManager: grant.holdingManager,
                          );
                          await refresh();
                        } catch (error) {
                          if (buildContext.mounted) {
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        child: Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(count.toString()),
            ),
            title: Text(title),
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text(_statusLabel(status)),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});

  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString()),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: retry,
              child: const Text(
                  '\u062a\u0644\u0627\u0634 \u0645\u062c\u062f\u062f'),
            ),
          ],
        ),
      );
}

Future<String?> _commentDialog(
  BuildContext context, {
  required bool required,
}) async {
  final controller = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text(
            '\u062a\u0648\u0636\u06cc\u062d \u0627\u0642\u062f\u0627\u0645'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: required
                ? '\u0639\u0644\u062a \u0627\u0644\u0632\u0627\u0645\u06cc'
                : '\u062a\u0648\u0636\u06cc\u062d \u0627\u062e\u062a\u06cc\u0627\u0631\u06cc',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\u0627\u0646\u0635\u0631\u0627\u0641'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) {
                setState(() => error =
                    '\u0639\u0644\u062a \u0627\u0644\u0632\u0627\u0645\u06cc \u0627\u0633\u062a.');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('\u062b\u0628\u062a'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<(String, String)?> _startRequestDialog(BuildContext context) async {
  const documentTypes = {
    'Journal Entry':
        '\u0633\u0646\u062f \u062d\u0633\u0627\u0628\u062f\u0627\u0631\u06cc',
    'Payment Entry':
        '\u062f\u0631\u06cc\u0627\u0641\u062a / \u067e\u0631\u062f\u0627\u062e\u062a',
    'Sales Invoice':
        '\u0641\u0627\u06a9\u062a\u0648\u0631 \u0641\u0631\u0648\u0634',
    'Purchase Invoice':
        '\u0641\u0627\u06a9\u062a\u0648\u0631 \u062e\u0631\u06cc\u062f',
    'Stock Entry':
        '\u0639\u0645\u0644\u06cc\u0627\u062a \u0627\u0646\u0628\u0627\u0631',
    'ASOUD Intercompany Transfer':
        '\u0627\u0646\u062a\u0642\u0627\u0644 \u0628\u06cc\u0646\u200c\u0634\u0631\u06a9\u062a\u06cc',
    'ASOUD Petty Cash Claim': '\u062a\u0646\u062e\u0648\u0627\u0647',
  };
  var documentType = documentTypes.keys.first;
  final name = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text(
          '\u0627\u0631\u0633\u0627\u0644 \u0633\u0646\u062f \u0628\u0631\u0627\u06cc \u062a\u0623\u06cc\u06cc\u062f',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: documentType,
                items: documentTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => documentType = value ?? documentType),
                decoration: const InputDecoration(
                  labelText: '\u0646\u0648\u0639 \u0633\u0646\u062f',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText:
                      '\u0634\u0645\u0627\u0631\u0647 \u0633\u0646\u062f',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\u0627\u0646\u0635\u0631\u0627\u0641'),
          ),
          FilledButton(
            onPressed: () {
              final value = name.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, (documentType, value));
              }
            },
            child: const Text('\u0627\u0631\u0633\u0627\u0644'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  return result;
}

String _amount(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

String _doctypeLabel(String value) =>
    const {
      'Journal Entry':
          '\u0633\u0646\u062f \u062d\u0633\u0627\u0628\u062f\u0627\u0631\u06cc',
      'Payment Entry':
          '\u062f\u0631\u06cc\u0627\u0641\u062a / \u067e\u0631\u062f\u0627\u062e\u062a',
      'Sales Invoice':
          '\u0641\u0627\u06a9\u062a\u0648\u0631 \u0641\u0631\u0648\u0634',
      'Purchase Invoice':
          '\u0641\u0627\u06a9\u062a\u0648\u0631 \u062e\u0631\u06cc\u062f',
      'Stock Entry':
          '\u0639\u0645\u0644\u06cc\u0627\u062a \u0627\u0646\u0628\u0627\u0631',
      'ASOUD Intercompany Transfer':
          '\u0627\u0646\u062a\u0642\u0627\u0644 \u0628\u06cc\u0646\u200c\u0634\u0631\u06a9\u062a\u06cc',
    }[value] ??
    value;

String _statusLabel(String value) =>
    const {
      'Pending': '\u062f\u0631 \u0627\u0646\u062a\u0638\u0627\u0631',
      'Approved': '\u062a\u0623\u06cc\u06cc\u062f\u0634\u062f\u0647',
      'Rejected': '\u0631\u062f\u0634\u062f\u0647',
      'Returned':
          '\u0628\u0627\u0632\u06af\u0634\u062a \u0628\u0631\u0627\u06cc \u0627\u0635\u0644\u0627\u062d',
      'Invalidated': '\u0628\u0627\u0637\u0644\u200c\u0634\u062f\u0647',
    }[value] ??
    value;

String _actionLabel(String value) =>
    const {
      'Approve': '\u062a\u0623\u06cc\u06cc\u062f',
      'Reject': '\u0631\u062f',
      'Return': '\u0628\u0627\u0632\u06af\u0634\u062a',
    }[value] ??
    value;

IconData _actionIcon(String value) => switch (value) {
      'Approve' => Icons.check_circle_outline,
      'Reject' => Icons.cancel_outlined,
      'Return' => Icons.undo,
      _ => Icons.history,
    };
