import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeOrganizationGateway implements OrganizationGateway {
  const FrappeOrganizationGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<OrganizationSnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.organization_settings_snapshot',
      {'company': context.company},
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ تنظیمات سازمانی معتبر نیست.');
    }
    return OrganizationSnapshot.fromJson(message);
  }

  @override
  Future<void> save(OrganizationDraft draft) async {
    await _client.postForm(
      '/api/method/asoud_core.api.save_organization_unit',
      {
        'payload': jsonEncode(draft.toJson()),
        'idempotency_key':
            'organization-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
  }

  @override
  Future<FinancialSettingsSnapshot> loadFinancial(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.financial_settings_snapshot',
      {'company': context.company},
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ تنظیمات مالی معتبر نیست.');
    }
    return FinancialSettingsSnapshot.fromJson(message);
  }

  @override
  Future<FinancialSettingsSnapshot> saveFinancial(
    WorkContext context,
    FinancialSettingsDraft draft,
  ) async {
    final response = await _client.postForm(
      '/api/method/asoud_iran.api.save_financial_settings',
      {
        'company': context.company,
        'payload': jsonEncode(draft.toJson()),
        'idempotency_key':
            'financial-settings-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ ذخیره تنظیمات مالی معتبر نیست.');
    }
    return FinancialSettingsSnapshot.fromJson(message);
  }

  @override
  Future<FinancialSettingsSnapshot> saveFiscalYear(
    WorkContext context,
    FiscalYearDraft draft,
  ) =>
      _saveFinancialOperation(
        context,
        'save_fiscal_year',
        'fiscal-year',
        {'payload': jsonEncode(draft.toJson())},
      );

  @override
  Future<FinancialSettingsSnapshot> saveFiscalPeriod(
    WorkContext context,
    FiscalPeriodDraft draft,
  ) =>
      _saveFinancialOperation(
        context,
        'save_fiscal_period',
        'fiscal-period',
        {'payload': jsonEncode(draft.toJson())},
      );

  @override
  Future<FinancialSettingsSnapshot> lockFinancialPeriod(
    WorkContext context,
    PeriodLockDraft draft,
  ) =>
      _saveFinancialOperation(
        context,
        'lock_financial_period',
        'period-lock',
        {'payload': jsonEncode(draft.toJson())},
      );

  @override
  Future<FinancialSettingsSnapshot> unlockFinancialPeriod(
    WorkContext context,
    String lockName,
    String reason,
  ) =>
      _saveFinancialOperation(
        context,
        'unlock_financial_period',
        'period-unlock',
        {'lock_name': lockName, 'reason': reason},
      );

  Future<FinancialSettingsSnapshot> _saveFinancialOperation(
    WorkContext context,
    String method,
    String keyPrefix,
    Map<String, String> fields,
  ) async {
    final response = await _client.postForm(
      '/api/method/asoud_iran.api.$method',
      {
        'company': context.company,
        ...fields,
        'idempotency_key':
            '$keyPrefix-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ عملیات دوره مالی معتبر نیست.');
    }
    return FinancialSettingsSnapshot.fromJson(message);
  }

  @override
  Future<AccountRulesSnapshot> loadAccountRules(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.account_detail_rules_snapshot',
      {'company': context.company},
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ نمودار حساب‌ها معتبر نیست.');
    }
    return AccountRulesSnapshot.fromJson(message);
  }

  @override
  Future<AccountRulesSnapshot> saveChartAccount(
    WorkContext context,
    ChartAccountDraft draft,
  ) async {
    final response = await _client.postForm(
      '/api/method/asoud_iran.api.save_chart_account',
      {
        'company': context.company,
        'payload': jsonEncode(draft.toJson()),
        'idempotency_key':
            'chart-account-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ ذخیره حساب معتبر نیست.');
    }
    return AccountRulesSnapshot.fromJson(message);
  }

  @override
  Future<FloatingDetailManagementSnapshot> loadFloatingDetails(
    WorkContext context,
  ) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.floating_detail_management_snapshot',
      {'company': context.company},
    );
    return FloatingDetailManagementSnapshot.fromJson(
      response['message'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FloatingDetailManagementSnapshot> saveFloatingDetailGroup(
    WorkContext context,
    FloatingDetailGroupDraft draft,
  ) =>
      _saveFloating(
        context,
        'save_floating_detail_group',
        'floating-detail-group',
        draft.toJson(),
      );

  @override
  Future<FloatingDetailManagementSnapshot> saveFloatingDetail(
    WorkContext context,
    FloatingDetailDraft draft,
  ) =>
      _saveFloating(
        context,
        'save_floating_detail',
        'floating-detail',
        draft.toJson(),
      );

  Future<FloatingDetailManagementSnapshot> _saveFloating(
    WorkContext context,
    String method,
    String keyPrefix,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.postForm(
      '/api/method/asoud_iran.api.$method',
      {
        'company': context.company,
        'payload': jsonEncode(payload),
        'idempotency_key':
            '$keyPrefix-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return FloatingDetailManagementSnapshot.fromJson(
      response['message'] as Map<String, dynamic>,
    );
  }
}
