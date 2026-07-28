import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/bloc/organization_settings_cubit.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/organization_settings_page.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = WorkContext(company: 'ASOUD');

  test('loads organization snapshot', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(gateway, context);
    await cubit.load();
    expect(cubit.state.phase, OrganizationPhase.ready);
    expect(cubit.state.snapshot.companies.single.title, 'شرکت آسود');
    await cubit.close();
  });

  test('keeps wizard data between steps and saves once', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(gateway, context);
    cubit.start(OrganizationUnitKind.company);
    cubit.update('company_name', 'شرکت جدید');
    cubit.update('abbr', 'NEW');
    cubit.next();
    expect(cubit.state.draft?.step, 1);
    expect(cubit.state.draft?.values['company_name'], 'شرکت جدید');
    expect(await cubit.save(), isTrue);
    expect(gateway.saved, hasLength(1));
    expect(cubit.state.draft, isNull);
    await cubit.close();
  });

  testWidgets('renders settings dashboard and opens unit selector',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationSettingsPage(
            context: context,
            gateway: _FakeGateway(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('داشبورد تنظیمات'), findsWidgets);
    await tester.tap(find.text('واحد سازمانی جدید'));
    await tester.pumpAndSettle();
    expect(find.text('هلدینگ'), findsOneWidget);
    expect(find.text('شرکت یا شخص'), findsOneWidget);
    expect(find.text('شعبه'), findsOneWidget);
  });
}

class _FakeGateway implements OrganizationGateway {
  final saved = <OrganizationDraft>[];

  @override
  Future<OrganizationSnapshot> load(WorkContext context) async =>
      const OrganizationSnapshot(
        companies: [
          OrganizationUnit(
            name: 'ASOUD',
            title: 'شرکت آسود',
            kind: OrganizationUnitKind.company,
          ),
        ],
      );

  @override
  Future<void> save(OrganizationDraft draft) async => saved.add(draft);
}
