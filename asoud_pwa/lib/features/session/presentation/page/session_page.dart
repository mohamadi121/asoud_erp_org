import 'package:asoud_pwa/features/session/domain/session_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_gateway.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/session/presentation/bloc/session_cubit.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/home/presentation/workspace_page.dart';
import 'package:asoud_pwa/features/hr/domain/hr_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:asoud_pwa/features/reports/domain/reports_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({
    required this.gateway,
    required this.accountingGateway,
    required this.operationsGateway,
    required this.treasuryGateway,
    required this.reportsGateway,
    required this.complianceGateway,
    required this.approvalGateway,
    required this.hrGateway,
    required this.dashboardGateway,
    required this.organizationGateway,
    required this.partyGateway,
    super.key,
  });

  final SessionGateway gateway;
  final IranAccountingGateway accountingGateway;
  final OperationsGateway operationsGateway;
  final TreasuryGateway treasuryGateway;
  final ReportsGateway reportsGateway;
  final ComplianceGateway complianceGateway;
  final ApprovalGateway approvalGateway;
  final HrGateway hrGateway;
  final DashboardGateway dashboardGateway;
  final OrganizationGateway organizationGateway;
  final PartyGateway partyGateway;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SessionCubit(gateway),
        child: _SessionView(
          accountingGateway: accountingGateway,
          operationsGateway: operationsGateway,
          treasuryGateway: treasuryGateway,
          reportsGateway: reportsGateway,
          complianceGateway: complianceGateway,
          approvalGateway: approvalGateway,
          hrGateway: hrGateway,
          dashboardGateway: dashboardGateway,
          organizationGateway: organizationGateway,
          partyGateway: partyGateway,
        ),
      );
}

class _SessionView extends StatefulWidget {
  const _SessionView({
    required this.accountingGateway,
    required this.operationsGateway,
    required this.treasuryGateway,
    required this.reportsGateway,
    required this.complianceGateway,
    required this.approvalGateway,
    required this.hrGateway,
    required this.dashboardGateway,
    required this.organizationGateway,
    required this.partyGateway,
  });

  final IranAccountingGateway accountingGateway;
  final OperationsGateway operationsGateway;
  final TreasuryGateway treasuryGateway;
  final ReportsGateway reportsGateway;
  final ComplianceGateway complianceGateway;
  final ApprovalGateway approvalGateway;
  final HrGateway hrGateway;
  final DashboardGateway dashboardGateway;
  final OrganizationGateway organizationGateway;
  final PartyGateway partyGateway;

  @override
  State<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<_SessionView> {
  final username = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BlocBuilder<SessionCubit, SessionState>(
          builder: (context, state) {
            if (state.phase == SessionPhase.ready) {
              return WorkspacePage(
                context: state.selected!,
                contexts: state.contexts,
                switchContext: context.read<SessionCubit>().switchContext,
                accountingGateway: widget.accountingGateway,
                operationsGateway: widget.operationsGateway,
                treasuryGateway: widget.treasuryGateway,
                reportsGateway: widget.reportsGateway,
                complianceGateway: widget.complianceGateway,
                approvalGateway: widget.approvalGateway,
                hrGateway: widget.hrGateway,
                dashboardGateway: widget.dashboardGateway,
                organizationGateway: widget.organizationGateway,
                partyGateway: widget.partyGateway,
              );
            }
            return Column(
              children: [
                AppBar(title: const Text('\u0622\u0633\u0648\u062f ERP')),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: state.phase == SessionPhase.loading
                            ? const Center(child: CircularProgressIndicator())
                            : state.phase == SessionPhase.selectingContext
                                ? _contextSelector(context, state)
                                : _login(context, state),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _login(BuildContext context, SessionState state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '\u0648\u0631\u0648\u062f \u0628\u0647 \u0633\u0627\u0645\u0627\u0646\u0647',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: username,
            decoration: const InputDecoration(
              labelText:
                  '\u0646\u0627\u0645 \u06a9\u0627\u0631\u0628\u0631\u06cc',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: '\u0631\u0645\u0632 \u0639\u0628\u0648\u0631'),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context
                .read<SessionCubit>()
                .login(username.text, password.text),
            child: const Text('\u0648\u0631\u0648\u062f'),
          ),
        ],
      );

  Widget _contextSelector(BuildContext context, SessionState state) {
    if (state.contexts.isEmpty) {
      return const Text(
        '\u0647\u06cc\u0686 \u0634\u0631\u06a9\u062a \u06cc\u0627 \u0634\u0639\u0628\u0647 \u0641\u0639\u0627\u0644\u06cc \u0628\u0631\u0627\u06cc \u0627\u06cc\u0646 \u06a9\u0627\u0631\u0628\u0631 \u062a\u0639\u0631\u06cc\u0641 \u0646\u0634\u062f\u0647 \u0627\u0633\u062a.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '\u0627\u0646\u062a\u062e\u0627\u0628 \u0645\u062d\u06cc\u0637 \u06a9\u0627\u0631\u06cc',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<WorkContext>(
          isExpanded: true,
          value: state.selected,
          items: state.contexts
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item.label)))
              .toList(growable: false),
          onChanged: context.read<SessionCubit>().selectContext,
          decoration: const InputDecoration(
            labelText: '\u0634\u0631\u06a9\u062a / \u0634\u0639\u0628\u0647',
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: state.selected == null
              ? null
              : () => context.read<SessionCubit>().continueToWorkspace(),
          child: const Text('\u0627\u062f\u0627\u0645\u0647'),
        ),
      ],
    );
  }
}
