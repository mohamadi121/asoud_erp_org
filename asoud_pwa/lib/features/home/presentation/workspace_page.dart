import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/presentation/approval_page.dart';
import 'package:asoud_pwa/features/approvals/presentation/bloc/approval_cubit.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_gateway.dart';
import 'package:asoud_pwa/features/compliance/presentation/compliance_page.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/dashboard/presentation/dashboard_page.dart';
import 'package:asoud_pwa/features/hr/domain/hr_gateway.dart';
import 'package:asoud_pwa/features/hr/presentation/hr_page.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/presentation/item_management_page.dart';
import 'package:asoud_pwa/features/iran_accounting/presentation/page/iran_accounting_page.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/presentation/operations_page.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/organization_settings_page.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/bloc/organization_settings_cubit.dart';
import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/parties/presentation/party_management_page.dart';
import 'package:asoud_pwa/features/reports/domain/reports_gateway.dart';
import 'package:asoud_pwa/features/reports/presentation/reports_page.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:asoud_pwa/features/treasury/presentation/treasury_page.dart';
import 'package:flutter/material.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    required this.context,
    required this.dashboardGateway,
    required this.accountingGateway,
    required this.operationsGateway,
    required this.treasuryGateway,
    required this.reportsGateway,
    required this.complianceGateway,
    required this.approvalGateway,
    required this.hrGateway,
    required this.organizationGateway,
    required this.partyGateway,
    required this.itemGateway,
    required this.contexts,
    required this.switchContext,
    super.key,
  });

  final WorkContext context;
  final DashboardGateway dashboardGateway;
  final IranAccountingGateway accountingGateway;
  final OperationsGateway operationsGateway;
  final TreasuryGateway treasuryGateway;
  final ReportsGateway reportsGateway;
  final ComplianceGateway complianceGateway;
  final ApprovalGateway approvalGateway;
  final HrGateway hrGateway;
  final OrganizationGateway organizationGateway;
  final PartyGateway partyGateway;
  final ItemGateway itemGateway;
  final List<WorkContext> contexts;
  final ValueChanged<WorkContext> switchContext;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  int index = 0;
  bool approvalMode = false;
  ApprovalView approvalView = ApprovalView.incoming;
  SettingsView settingsView = SettingsView.dashboard;
  String? partyRoleFilter;
  bool itemManagementMode = false;
  bool masterDataMode = false;
  late final DashboardController dashboardController = DashboardController();

  @override
  void dispose() {
    dashboardController.dispose();
    super.dispose();
  }

  void _selectModule(int value) {
    dashboardController.closeOverlays();
    setState(() {
      index = value;
      approvalMode = false;
      partyRoleFilter = null;
      itemManagementMode = false;
      masterDataMode = false;
    });
  }

  void _openDashboardOverlay(VoidCallback action) {
    if (index != 0 || approvalMode) {
      setState(() {
        index = 0;
        approvalMode = false;
        partyRoleFilter = null;
        itemManagementMode = false;
        masterDataMode = false;
      });
    }
    action();
  }

  void _openApprovalInbox([
    ApprovalView view = ApprovalView.incoming,
  ]) {
    dashboardController.closeOverlays();
    setState(() {
      approvalMode = true;
      approvalView = view;
      partyRoleFilter = null;
      itemManagementMode = false;
      masterDataMode = false;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _TopNavigation(
            selectedIndex: index,
            modules: _modules,
            workContext: widget.context,
            selectModule: _selectModule,
            openQuickAccess: () => _openDashboardOverlay(
              dashboardController.toggleQuickAccess,
            ),
            openNotifications: () => _openDashboardOverlay(
              dashboardController.toggleNotifications,
            ),
            search: _search,
            help: _showHelp,
            profile: _showProfile,
          ),
          _Ribbon(
            moduleIndex: approvalMode ? 9 : index,
            workContext: widget.context,
            onCommand: _handleCommand,
            contexts: widget.contexts,
            switchContext: widget.switchContext,
          ),
          const Divider(height: 1),
          Expanded(child: _currentPage()),
        ],
      );

  void _handleCommand(String command) {
    switch (command) {
      case 'home':
        _selectModule(0);
        return;
      case 'quick_access':
        _openDashboardOverlay(dashboardController.toggleQuickAccess);
        return;
      case 'quick_create':
        _selectModule(6);
        return;
      case 'new_document':
        _openDashboardOverlay(dashboardController.showQuickCreate);
        return;
      case 'receipt_payment':
        _openDashboardOverlay(
          () => dashboardController.showQuickCreate('Payment Entry'),
        );
        return;
      case 'invoice':
        _openDashboardOverlay(
          () => dashboardController.showQuickCreate('Sales Invoice'),
        );
        return;
      case 'notifications':
        _openDashboardOverlay(dashboardController.toggleNotifications);
        return;
      case 'approvals':
        _openApprovalInbox();
        return;
      case 'outgoing':
        _openApprovalInbox(ApprovalView.outgoing);
        return;
      case 'history':
        _openApprovalInbox(ApprovalView.history);
        return;
      case 'policies':
        _openApprovalInbox(ApprovalView.policies);
        return;
      case 'delegation':
        _openApprovalInbox(ApprovalView.access);
        return;
      case 'refresh':
        if (index == 0) {
          dashboardController.refresh();
        } else {
          setState(() => index = index);
        }
        return;
      case 'customize':
        _openDashboardOverlay(dashboardController.toggleQuickAccess);
        return;
      case 'journal':
      case 'ledger':
      case 'numbering':
      case 'period':
      case 'lock':
      case 'closing':
      case 'opening':
        _selectModule(1);
        return;
      case 'bank':
      case 'cash':
      case 'petty_cash':
      case 'cheques':
      case 'reconcile':
      case 'cash_count':
        _selectModule(2);
        return;
      case 'customer':
        setState(() {
          index = 3;
          approvalMode = false;
          partyRoleFilter = 'Customer';
          itemManagementMode = false;
          masterDataMode = false;
        });
        return;
      case 'sales_order':
        _selectModule(3);
        return;
      case 'purchase_invoice':
        _selectModule(4);
        return;
      case 'supplier':
        setState(() {
          index = 4;
          approvalMode = false;
          partyRoleFilter = 'Supplier';
          itemManagementMode = false;
          masterDataMode = false;
        });
        return;
      case 'purchase_order':
        _selectModule(4);
        return;
      case 'stock_entry':
      case 'warehouses':
        _selectModule(5);
        return;
      case 'items':
        setState(() {
          index = 5;
          approvalMode = false;
          partyRoleFilter = null;
          itemManagementMode = true;
          masterDataMode = false;
        });
        return;
      case 'employees':
        setState(() {
          index = 6;
          approvalMode = false;
          partyRoleFilter = 'Employee';
          itemManagementMode = false;
          masterDataMode = false;
        });
        return;
      case 'organization':
      case 'positions':
      case 'work_report':
      case 'communications':
      case 'actions':
        _selectModule(6);
        return;
      case 'trial_balance':
      case 'profit_loss':
      case 'financial_position':
        _selectModule(7);
        return;
      case 'company_settings':
      case 'settings_dashboard':
        setState(() => settingsView = SettingsView.dashboard);
        _selectModule(8);
        return;
      case 'organization_structure':
        setState(() => settingsView = SettingsView.structure);
        _selectModule(8);
        return;
      case 'financial_settings':
        setState(() => settingsView = SettingsView.financial);
        _selectModule(8);
        return;
      case 'document_sequences':
        _selectModule(1);
        return;
      case 'organization_access':
        _openApprovalInbox(ApprovalView.access);
        return;
      case 'approval_settings':
        _openApprovalInbox(ApprovalView.policies);
        return;
      case 'iran_settings':
        _selectModule(1);
        return;
      case 'master_data':
        setState(() {
          index = 8;
          approvalMode = false;
          partyRoleFilter = null;
          itemManagementMode = false;
          masterDataMode = true;
        });
        return;
      case 'control_locks':
        setState(() => settingsView = SettingsView.financial);
        _selectModule(8);
        return;
      case 'access':
      case 'compliance':
        _selectModule(8);
        return;
      case 'fullscreen':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برای تمام‌صفحه‌شدن PWA از کلید F11 مرورگر استفاده کنید.',
            ),
          ),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _search() async {
    final target = await showSearch<int>(
      context: context,
      delegate: _WorkspaceSearchDelegate(index),
    );
    if (target != null) _selectModule(target);
  }

  Future<void> _showHelp() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline),
              SizedBox(width: 8),
              Text('راهنمای میزکار آسود'),
            ],
          ),
          content: const SizedBox(
            width: 500,
            child: Text(
              'از منوی اصلی، حوزه کاری را انتخاب کنید. ریبون زیر آن فرمان‌های همان حوزه را نشان می‌دهد. '
              'دسترسی سریع برای نماهای پرکاربرد، علامت + برای ایجاد سند، و زنگ برای اعلان‌هاست. '
              'شرکت و شعبه فعال از بخش زمینه قابل تغییر است.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      );

  Future<void> _showProfile() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('پروفایل و زمینه فعال'),
          content: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: const Text('کاربر جاری'),
            subtitle: Text(widget.context.label),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectModule(8);
              },
              child: const Text('تنظیمات و دسترسی'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        ),
      );

  Widget _currentPage() {
    if (approvalMode) {
      return ApprovalPage(
        key: ValueKey(approvalView),
        context: widget.context,
        gateway: widget.approvalGateway,
        initialView: approvalView,
      );
    }
    if (partyRoleFilter != null) {
      return PartyManagementPage(
        key: ValueKey('${widget.context.company}|$partyRoleFilter'),
        context: widget.context,
        gateway: widget.partyGateway,
        initialRole: partyRoleFilter,
      );
    }
    if (itemManagementMode) {
      return ItemManagementPage(
        key: ValueKey('${widget.context.company}|items'),
        context: widget.context,
        gateway: widget.itemGateway,
      );
    }
    if (masterDataMode) {
      return _MasterDataHub(
        openParties: () => setState(() {
          masterDataMode = false;
          partyRoleFilter = 'Customer';
        }),
        openItems: () => setState(() {
          masterDataMode = false;
          itemManagementMode = true;
          index = 5;
        }),
      );
    }
    return switch (index) {
      0 => DashboardPage(
          context: widget.context,
          gateway: widget.dashboardGateway,
          operationsGateway: widget.operationsGateway,
          controller: dashboardController,
          openModule: _selectModule,
          openApprovals: _openApprovalInbox,
        ),
      1 => IranAccountingPage(
          context: widget.context,
          gateway: widget.accountingGateway,
        ),
      2 => TreasuryPage(
          context: widget.context,
          gateway: widget.treasuryGateway,
        ),
      3 || 4 || 5 => OperationsPage(
          context: widget.context,
          gateway: widget.operationsGateway,
          documentTypes: index == 3
              ? const {'Sales Invoice'}
              : index == 4
                  ? const {'Purchase Invoice'}
                  : const {'Stock Entry'},
        ),
      6 => HrPage(
          context: widget.context,
          gateway: widget.hrGateway,
        ),
      7 => ReportsPage(
          context: widget.context,
          gateway: widget.reportsGateway,
        ),
      8 => OrganizationSettingsPage(
          key: ValueKey(settingsView),
          context: widget.context,
          gateway: widget.organizationGateway,
          initialView: settingsView,
          onOpenDestination: _handleCommand,
        ),
      _ => CompliancePage(
          context: widget.context,
          gateway: widget.complianceGateway,
        ),
    };
  }
}

class _MasterDataHub extends StatelessWidget {
  const _MasterDataHub({required this.openParties, required this.openItems});

  final VoidCallback openParties;
  final VoidCallback openItems;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AsoudColors.canvas,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'اطلاعات پایه',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'مدیریت هویت‌های مشترک هلدینگ و سیاست مستقل شرکت فعال',
              style: TextStyle(color: AsoudColors.muted),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MasterDataCard(
                  title: 'اشخاص و طرف‌حساب‌ها',
                  subtitle: 'مشتری، تأمین‌کننده، پرسنل و سایر نقش‌ها',
                  icon: Icons.people_outline,
                  open: openParties,
                ),
                _MasterDataCard(
                  title: 'کالا و خدمات',
                  subtitle: 'کالا، خدمت و سیاست عملیاتی هر شرکت',
                  icon: Icons.inventory_2_outlined,
                  open: openItems,
                ),
              ],
            ),
          ],
        ),
      );
}

class _MasterDataCard extends StatelessWidget {
  const _MasterDataCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.open,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 360,
        height: 150,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Icon(icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: AsoudColors.muted)),
                        const Spacer(),
                        const Text('باز کردن مدیریت',
                            style: TextStyle(
                                fontSize: 11, color: AsoudColors.primary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left,
                      size: 18, color: AsoudColors.muted),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.selectedIndex,
    required this.modules,
    required this.workContext,
    required this.selectModule,
    required this.openQuickAccess,
    required this.openNotifications,
    required this.search,
    required this.help,
    required this.profile,
  });

  final int selectedIndex;
  final List<_Module> modules;
  final WorkContext workContext;
  final ValueChanged<int> selectModule;
  final VoidCallback openQuickAccess;
  final VoidCallback openNotifications;
  final VoidCallback search;
  final VoidCallback help;
  final VoidCallback profile;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AsoudColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.change_history,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'آسود ERP',
                      style: TextStyle(
                        color: AsoudColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    IconButton(
                      tooltip: 'دسترسی سریع',
                      onPressed: openQuickAccess,
                      icon: const Icon(Icons.menu_open, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (var moduleIndex = 0;
                          moduleIndex < modules.length;
                          moduleIndex++)
                        Builder(
                          builder: (context) {
                            final selected = moduleIndex == selectedIndex;
                            return InkWell(
                              onTap: () => selectModule(moduleIndex),
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: selected
                                          ? AsoudColors.primary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  modules[moduleIndex].label,
                                  style: TextStyle(
                                    color: selected
                                        ? AsoudColors.primary
                                        : AsoudColors.navy,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      child: TextField(
                        readOnly: true,
                        onTap: search,
                        decoration: const InputDecoration(
                          hintText: 'جست‌وجو...',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'اعلان‌ها',
                      onPressed: openNotifications,
                      icon: const Badge(
                        smallSize: 8,
                        child: Icon(Icons.notifications_outlined),
                      ),
                    ),
                    IconButton(
                      tooltip: 'راهنما',
                      onPressed: help,
                      icon: const Icon(Icons.help_outline),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: profile,
                      child: const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مدیر سیستم',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            workContext.company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AsoudColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.moduleIndex,
    required this.workContext,
    required this.onCommand,
    required this.contexts,
    required this.switchContext,
  });

  final int moduleIndex;
  final WorkContext workContext;
  final ValueChanged<String> onCommand;
  final List<WorkContext> contexts;
  final ValueChanged<WorkContext> switchContext;

  @override
  Widget build(BuildContext context) {
    final groups = _ribbonGroups[moduleIndex] ?? _ribbonGroups[0]!;
    return Material(
      color: const Color(0xfffbfcfe),
      child: SizedBox(
        height: 116,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: groups.length + (moduleIndex == 0 ? 1 : 0),
          separatorBuilder: (_, __) => const VerticalDivider(width: 22),
          itemBuilder: (context, groupIndex) {
            if (moduleIndex == 0 && groupIndex == groups.length) {
              return _ContextFilters(
                workContext: workContext,
                contexts: contexts,
                switchContext: switchContext,
                openFiscalYear: () => onCommand('period'),
              );
            }
            return _RibbonGroup(
              group: groups[groupIndex],
              onCommand: onCommand,
            );
          },
        ),
      ),
    );
  }
}

class _RibbonGroup extends StatelessWidget {
  const _RibbonGroup({required this.group, required this.onCommand});

  final _CommandGroup group;
  final ValueChanged<String> onCommand;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (final command in group.commands)
                  SizedBox(
                    width: 86,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onCommand(command.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              command.icon,
                              size: 27,
                              color: AsoudColors.navy,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              command.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            group.title,
            style: const TextStyle(fontSize: 10, color: AsoudColors.muted),
          ),
        ],
      );
}

class _ContextFilters extends StatelessWidget {
  const _ContextFilters({
    required this.workContext,
    required this.contexts,
    required this.switchContext,
    required this.openFiscalYear,
  });

  final WorkContext workContext;
  final List<WorkContext> contexts;
  final ValueChanged<WorkContext> switchContext;
  final VoidCallback openFiscalYear;

  Future<void> _chooseContext(BuildContext context, bool companyOnly) async {
    final choices = companyOnly
        ? {
            for (final item in contexts) item.company: item,
          }.values.toList(growable: false)
        : contexts
            .where((item) => item.company == workContext.company)
            .toList(growable: false);
    final selected = await showDialog<WorkContext>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(companyOnly ? 'انتخاب شرکت' : 'انتخاب شعبه'),
        children: [
          for (final item in choices)
            RadioListTile<WorkContext>(
              value: item,
              groupValue: workContext,
              title: Text(companyOnly ? item.company : item.label),
              onChanged: (value) => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (selected != null) switchContext(selected);
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _FilterButton(
                  icon: Icons.apartment_outlined,
                  label: workContext.company,
                  onPressed: () => _chooseContext(context, true),
                ),
                const SizedBox(width: 6),
                _FilterButton(
                  icon: Icons.store_outlined,
                  label: workContext.branchName ?? 'تمام شعب',
                  onPressed: () => _chooseContext(context, false),
                ),
                const SizedBox(width: 6),
                _FilterButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'سال مالی ۱۴۰۵',
                  onPressed: openFiscalYear,
                ),
              ],
            ),
          ),
          const Text(
            'فیلتر زمینه',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted),
          ),
        ],
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 125),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

class _Module {
  const _Module(this.label);

  final String label;
}

class _Command {
  const _Command(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

class _CommandGroup {
  const _CommandGroup(this.title, this.commands);

  final String title;
  final List<_Command> commands;
}

const _modules = [
  _Module('داشبورد'),
  _Module('مالی'),
  _Module('خزانه‌داری'),
  _Module('فروش'),
  _Module('خرید'),
  _Module('انبار'),
  _Module('منابع انسانی'),
  _Module('گزارش‌ها'),
  _Module('تنظیمات'),
];

const _ribbonGroups = <int, List<_CommandGroup>>{
  0: [
    _CommandGroup('نمای کلی', [
      _Command('home', 'خانه', Icons.home_outlined),
      _Command('approvals', 'کارتابل', Icons.business_center_outlined),
      _Command('quick_access', 'فعالیت‌ها', Icons.fact_check_outlined),
    ]),
    _CommandGroup('ایجاد سریع', [
      _Command('new_document', 'سند جدید', Icons.note_add_outlined),
      _Command('receipt_payment', 'دریافت/پرداخت', Icons.sync_alt),
      _Command('invoice', 'فاکتور', Icons.receipt_long_outlined),
      _Command('quick_create', 'گزارش کار', Icons.assignment_outlined),
    ]),
    _CommandGroup('نمایش', [
      _Command('refresh', 'به‌روزرسانی', Icons.refresh),
      _Command('customize', 'شخصی‌سازی', Icons.tune),
      _Command('fullscreen', 'تمام‌صفحه', Icons.fullscreen),
    ]),
  ],
  1: [
    _CommandGroup('اسناد حسابداری', [
      _Command('new_document', 'سند جدید', Icons.note_add_outlined),
      _Command('journal', 'دفتر روزنامه', Icons.menu_book_outlined),
      _Command('ledger', 'دفتر کل', Icons.library_books_outlined),
      _Command('numbering', 'شماره‌گذاری', Icons.tag),
    ]),
    _CommandGroup('دوره مالی', [
      _Command('period', 'دوره‌ها', Icons.date_range_outlined),
      _Command('lock', 'قفل دوره', Icons.lock_outline),
      _Command('closing', 'اختتامیه', Icons.logout_outlined),
      _Command('opening', 'افتتاحیه', Icons.login_outlined),
    ]),
  ],
  2: [
    _CommandGroup('خزانه', [
      _Command('bank', 'حساب‌های بانکی', Icons.account_balance_outlined),
      _Command('cash', 'صندوق‌ها', Icons.point_of_sale_outlined),
      _Command('petty_cash', 'تنخواه‌ها', Icons.wallet_outlined),
      _Command('cheques', 'چک‌ها', Icons.receipt_long_outlined),
    ]),
    _CommandGroup('کنترل', [
      _Command('reconcile', 'مغایرت بانکی', Icons.rule_outlined),
      _Command('cash_count', 'شمارش نقد', Icons.calculate_outlined),
    ]),
  ],
  3: [
    _CommandGroup('فروش', [
      _Command('invoice', 'فاکتور فروش', Icons.receipt_long_outlined),
      _Command('customer', 'مشتریان', Icons.people_outline),
      _Command('sales_order', 'سفارش‌ها', Icons.shopping_cart_outlined),
    ]),
  ],
  4: [
    _CommandGroup('خرید', [
      _Command('purchase_invoice', 'فاکتور خرید', Icons.receipt_long_outlined),
      _Command('supplier', 'تأمین‌کنندگان', Icons.groups_outlined),
      _Command('purchase_order', 'سفارش خرید', Icons.shopping_bag_outlined),
    ]),
  ],
  5: [
    _CommandGroup('انبار', [
      _Command('stock_entry', 'رسید و حواله', Icons.swap_horiz),
      _Command('warehouses', 'انبارها', Icons.warehouse_outlined),
      _Command('items', 'کالا و خدمات', Icons.inventory_2_outlined),
    ]),
  ],
  6: [
    _CommandGroup('پرسنل و سازمان', [
      _Command('employees', 'پرسنل', Icons.badge_outlined),
      _Command('organization', 'چارت سازمانی', Icons.account_tree_outlined),
      _Command('positions', 'سمت‌ها', Icons.work_outline),
    ]),
    _CommandGroup('فعالیت سازمانی', [
      _Command('work_report', 'گزارش روزانه', Icons.fact_check_outlined),
      _Command('communications', 'مکاتبات', Icons.mail_outline),
      _Command('actions', 'اقدامات', Icons.task_alt_outlined),
    ]),
  ],
  7: [
    _CommandGroup('گزارش‌های مالی', [
      _Command('trial_balance', 'تراز آزمایشی', Icons.balance_outlined),
      _Command('profit_loss', 'سود و زیان', Icons.show_chart),
      _Command('financial_position', 'وضعیت مالی', Icons.pie_chart_outline),
    ]),
  ],
  8: [
    _CommandGroup('تنظیمات پایه', [
      _Command(
          'settings_dashboard', 'داشبورد تنظیمات', Icons.dashboard_outlined),
      _Command('organization_structure', 'ساختار سازمانی',
          Icons.account_tree_outlined),
      _Command(
          'financial_settings', 'تنظیمات مالی', Icons.receipt_long_outlined),
      _Command('document_sequences', 'شماره‌گذاری', Icons.tag),
    ]),
    _CommandGroup('کنترل و دسترسی', [
      _Command('organization_access', 'کاربران و نقش‌ها',
          Icons.manage_accounts_outlined),
      _Command('approval_settings', 'گردش تأیید', Icons.alt_route),
      _Command('iran_settings', 'حسابداری ایران', Icons.flag_outlined),
      _Command('master_data', 'داده‌های پایه', Icons.dataset_outlined),
      _Command('control_locks', 'قفل و کنترل', Icons.lock_outline),
    ]),
  ],
  9: [
    _CommandGroup('کارتابل', [
      _Command('approvals', 'در انتظار من', Icons.inbox_outlined),
      _Command('outgoing', 'ارسالی‌ها', Icons.outbox_outlined),
      _Command('history', 'تاریخچه', Icons.history),
    ]),
    _CommandGroup('گردش تأیید', [
      _Command('policies', 'سیاست‌ها', Icons.account_tree_outlined),
      _Command('delegation', 'جانشینی', Icons.people_alt_outlined),
    ]),
  ],
};

class _WorkspaceSearchDelegate extends SearchDelegate<int> {
  _WorkspaceSearchDelegate(this.currentModule);

  final int currentModule;

  @override
  String get searchFieldLabel => 'جست‌وجوی ماژول یا فرمان...';

  List<({int module, String label, IconData icon})> get _entries => [
        for (var module = 0; module < _modules.length; module++)
          (
            module: module,
            label: _modules[module].label,
            icon: Icons.apps_outlined,
          ),
        for (final entry in _ribbonGroups.entries)
          for (final group in entry.value)
            for (final command in group.commands)
              (
                module: entry.key == 9 ? 0 : entry.key,
                label: '${command.label} — ${group.title}',
                icon: command.icon,
              ),
      ];

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'پاک‌کردن',
            onPressed: () => query = '',
            icon: const Icon(Icons.clear),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'بازگشت',
        onPressed: () => close(context, currentModule),
        icon: const Icon(Icons.arrow_forward),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = _entries
        .where((entry) =>
            normalized.isEmpty ||
            entry.label.toLowerCase().contains(normalized))
        .toList(growable: false);
    return ListView(
      children: [
        for (final entry in matches)
          ListTile(
            leading: Icon(entry.icon),
            title: Text(entry.label),
            subtitle: Text(_modules[entry.module].label),
            onTap: () => close(context, entry.module),
          ),
      ],
    );
  }
}
