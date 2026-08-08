import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_models.dart';
import 'package:asoud_pwa/features/parties/presentation/bloc/party_management_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const workContext = WorkContext(company: 'ASOUD', branch: 'MAIN');

  test('previews independent company role codes and saves one identity',
      () async {
    final gateway = _FakePartyGateway();
    final cubit = PartyManagementCubit(gateway, workContext);

    await cubit.create();
    expect(cubit.state.codePreview['Customer'], '10001');

    await cubit.toggleRole('Supplier');
    expect(cubit.state.codePreview['Supplier'], '15001');

    cubit.update(
      cubit.state.draft!.copyWith(
        firstName: 'احمد',
        lastName: 'سماوات',
      ),
    );
    await cubit.save();

    expect(gateway.saved, hasLength(1));
    expect(gateway.saved.single.roles, {'Customer', 'Supplier'});
    expect(gateway.saved.single.companyPolicies.keys,
        containsAll(<String>['Customer', 'Supplier']));
    expect(cubit.state.draft, isNull);
    await cubit.close();
  });

  test('keeps opening balances separate for each selected role', () async {
    final cubit = PartyManagementCubit(_FakePartyGateway(), workContext);
    await cubit.create();
    await cubit.toggleRole('Supplier');

    cubit.updateOpening('Customer', stateValue: 'Debit', amount: 25000000);
    cubit.updateOpening('Supplier', stateValue: 'Credit', amount: 12500000);

    expect(
      cubit.state.draft!.openingBalances['Customer']!.balanceState,
      'Debit',
    );
    expect(
      cubit.state.draft!.openingBalances['Supplier']!.amount,
      12500000,
    );
    await cubit.close();
  });

  test('loads a profile and reuses it as an edit draft', () async {
    final cubit = PartyManagementCubit(_FakePartyGateway(), workContext);
    await cubit.openProfile('PARTY-00001');

    expect(cubit.state.profile!.codes['Customer'], '10001');
    cubit.editProfile();
    expect(cubit.state.profile, isNull);
    expect(cubit.state.draft!.name, 'PARTY-00001');
    expect(cubit.state.draft!.displayName, 'احمد سماوات');
    await cubit.close();
  });

  test('serializes company policy independently from shared identity', () {
    const policy = CompanyPartyPolicy(
      role: 'Customer',
      enabled: false,
      defaultBranch: 'MAIN',
      creditLimit: 25000000,
      defaultAccount: 'Debtors - ASOUD',
    );
    const draft = PartyDraft(companyPolicies: {'Customer': policy});

    final json = draft.toJson();
    final restored = PartyDraft.fromJson({
      ...json,
      'roles': [
        {'role': 'Customer'},
      ],
    });

    expect(restored.companyPolicies['Customer']!.enabled, isFalse);
    expect(restored.companyPolicies['Customer']!.creditLimit, 25000000);
    expect(restored.companyPolicies['Customer']!.defaultBranch, 'MAIN');
  });
}

class _FakePartyGateway implements PartyGateway {
  final saved = <PartyDraft>[];

  @override
  Future<PartySnapshot> load(
    WorkContext context, {
    String search = '',
  }) async =>
      const PartySnapshot();

  @override
  Future<Map<String, String>> previewCodes(
    WorkContext context,
    Set<String> roles,
  ) async =>
      {
        if (roles.contains('Customer')) 'Customer': '10001',
        if (roles.contains('Supplier')) 'Supplier': '15001',
        if (roles.contains('Employee')) 'Employee': '6001',
      };

  @override
  Future<PartyProfile> loadDetail(
    WorkContext context,
    String name,
  ) async =>
      const PartyProfile(
        draft: PartyDraft(
          name: 'PARTY-00001',
          firstName: 'احمد',
          lastName: 'سماوات',
        ),
        codes: {'Customer': '10001'},
      );

  @override
  Future<void> save(WorkContext context, PartyDraft draft) async {
    saved.add(draft);
  }
}
