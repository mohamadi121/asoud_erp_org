import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/approvals/presentation/approval_page.dart';
import 'package:asoud_pwa/features/approvals/presentation/bloc/approval_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the RTL cartable and routes the history view',
      (tester) async {
    final gateway = _PageGateway();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ApprovalPage(
              context: const WorkContext(
                company: 'شرکت آسود',
                branch: 'HQ',
                branchName: 'دفتر مرکزی',
              ),
              gateway: gateway,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('کارتابل و گردش تأیید'), findsOneWidget);
    expect(find.text('در انتظار اقدام من'), findsOneWidget);
    expect(find.text('ارسال سند برای تأیید'), findsOneWidget);

    await tester.tap(find.text('تاریخچه'));
    await tester.pumpAndSettle();

    expect(gateway.lastView, 'history');
    expect(find.text('سوابق نهایی‌شده و قابل مشاهده'), findsOneWidget);
  });

  testWidgets('creates an approval route from the policy form', (tester) async {
    final gateway = _PageGateway();
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ApprovalPage(
              context: const WorkContext(company: 'A'),
              gateway: gateway,
              initialView: ApprovalView.policies,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('مسیر تأیید جدید'));
    await tester.pumpAndSettle();
    expect(find.text('ایجاد مسیر تأیید'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'عنوان مسیر *'),
      'تأیید سند حسابداری',
    );
    await tester.tap(find.text('ذخیره مسیر تأیید'));
    await tester.pumpAndSettle();

    expect(gateway.savedDraft?.title, 'تأیید سند حسابداری');
    expect(find.text('مسیر تأیید با موفقیت ذخیره شد.'), findsOneWidget);
  });
}

class _PageGateway implements ApprovalGateway {
  String lastView = '';
  ApprovalPolicyDraft? savedDraft;

  @override
  Future<ApprovalInbox> loadInbox(
    WorkContext context, {
    String view = 'incoming',
    String search = '',
    String status = '',
    int limit = 50,
  }) async {
    lastView = view;
    return const ApprovalInbox(
      items: [],
      incomingCount: 3,
      outgoingCount: 7,
      historyCount: 24,
    );
  }

  @override
  Future<ApprovalDetail> loadDetail(String request) =>
      throw UnimplementedError();

  @override
  Future<ApprovalDetail> act({
    required String request,
    required String action,
    required String comment,
    required String expectedVersion,
  }) =>
      throw UnimplementedError();

  @override
  Future<ApprovalDetail> start({
    required String sourceDoctype,
    required String sourceName,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ApprovalPolicySummary>> loadPolicies(WorkContext context) async =>
      const [];

  @override
  Future<ApprovalPolicyWorkspace> loadPolicyWorkspace(
    WorkContext context,
  ) async =>
      const ApprovalPolicyWorkspace(documentTypes: ['Journal Entry']);

  @override
  Future<ApprovalPolicySummary> savePolicy(
    WorkContext context,
    ApprovalPolicyDraft draft,
  ) async {
    savedDraft = draft;
    return const ApprovalPolicySummary(
      name: 'POL-1',
      title: 'مسیر نمونه',
      documentType: 'Journal Entry',
      parallelMode: 'All',
      minimumAmount: 0,
      maximumAmount: 0,
    );
  }

  @override
  Future<AccessOverview> loadAccess(WorkContext context) async =>
      const AccessOverview(users: []);

  @override
  Future<void> setAccess({
    required WorkContext context,
    required AccessGrantSummary grant,
    required bool enabled,
    required bool holdingManager,
  }) async {}
}
