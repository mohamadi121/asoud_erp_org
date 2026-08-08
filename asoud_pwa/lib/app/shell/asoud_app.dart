import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/approvals/data/frappe_approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/compliance/data/frappe_compliance_gateway.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_gateway.dart';
import 'package:asoud_pwa/features/dashboard/data/frappe_dashboard_gateway.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/hr/data/frappe_hr_gateway.dart';
import 'package:asoud_pwa/features/hr/domain/hr_gateway.dart';
import 'package:asoud_pwa/features/iran_accounting/data/frappe_iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/items/data/frappe_item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/operations/data/frappe_operations_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/data/frappe_organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/parties/data/frappe_party_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/reports/data/frappe_reports_gateway.dart';
import 'package:asoud_pwa/features/reports/domain/reports_gateway.dart';
import 'package:asoud_pwa/features/session/data/frappe_session_gateway.dart';
import 'package:asoud_pwa/features/session/domain/session_gateway.dart';
import 'package:asoud_pwa/features/session/presentation/page/session_page.dart';
import 'package:asoud_pwa/features/treasury/data/frappe_treasury_gateway.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:flutter/material.dart';

String _apiBaseUrl() => Uri.base.scheme == 'http' || Uri.base.scheme == 'https'
    ? Uri.base.origin
    : 'http://localhost';

class AsoudApp extends StatelessWidget {
  factory AsoudApp({
    Key? key,
    SessionGateway? sessionGateway,
    IranAccountingGateway? accountingGateway,
    OperationsGateway? operationsGateway,
    TreasuryGateway? treasuryGateway,
    ReportsGateway? reportsGateway,
    ComplianceGateway? complianceGateway,
    ApprovalGateway? approvalGateway,
    HrGateway? hrGateway,
    DashboardGateway? dashboardGateway,
    OrganizationGateway? organizationGateway,
    PartyGateway? partyGateway,
    ItemGateway? itemGateway,
  }) {
    final client = AsoudApiClient(baseUrl: _apiBaseUrl());
    return AsoudApp._(
      key: key,
      sessionGateway: sessionGateway ?? FrappeSessionGateway(client),
      accountingGateway:
          accountingGateway ?? FrappeIranAccountingGateway(client),
      operationsGateway: operationsGateway ?? FrappeOperationsGateway(client),
      treasuryGateway: treasuryGateway ?? FrappeTreasuryGateway(client),
      reportsGateway: reportsGateway ?? FrappeReportsGateway(client),
      complianceGateway: complianceGateway ?? FrappeComplianceGateway(client),
      approvalGateway: approvalGateway ?? FrappeApprovalGateway(client),
      hrGateway: hrGateway ?? FrappeHrGateway(client),
      dashboardGateway: dashboardGateway ?? FrappeDashboardGateway(client),
      organizationGateway:
          organizationGateway ?? FrappeOrganizationGateway(client),
      partyGateway: partyGateway ?? FrappePartyGateway(client),
      itemGateway: itemGateway ?? FrappeItemGateway(client),
    );
  }

  const AsoudApp._({
    required this.sessionGateway,
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
    required this.itemGateway,
    super.key,
  });

  final SessionGateway sessionGateway;
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
  final ItemGateway itemGateway;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'آسود ERP',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: SessionPage(
          gateway: sessionGateway,
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
          itemGateway: itemGateway,
        ),
      );
}
