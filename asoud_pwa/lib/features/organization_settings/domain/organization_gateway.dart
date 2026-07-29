import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class OrganizationGateway {
  Future<OrganizationSnapshot> load(WorkContext context);
  Future<void> save(OrganizationDraft draft);
  Future<FinancialSettingsSnapshot> loadFinancial(WorkContext context);
  Future<FinancialSettingsSnapshot> saveFinancial(
    WorkContext context,
    FinancialSettingsDraft draft,
  );
  Future<FinancialSettingsSnapshot> saveFiscalYear(
    WorkContext context,
    FiscalYearDraft draft,
  );
  Future<FinancialSettingsSnapshot> saveFiscalPeriod(
    WorkContext context,
    FiscalPeriodDraft draft,
  );
  Future<FinancialSettingsSnapshot> lockFinancialPeriod(
    WorkContext context,
    PeriodLockDraft draft,
  );
  Future<FinancialSettingsSnapshot> unlockFinancialPeriod(
    WorkContext context,
    String lockName,
    String reason,
  );
  Future<AccountRulesSnapshot> loadAccountRules(WorkContext context);
  Future<AccountRulesSnapshot> saveChartAccount(
    WorkContext context,
    ChartAccountDraft draft,
  );
  Future<FloatingDetailManagementSnapshot> loadFloatingDetails(
    WorkContext context,
  );
  Future<FloatingDetailManagementSnapshot> saveFloatingDetailGroup(
    WorkContext context,
    FloatingDetailGroupDraft draft,
  );
  Future<FloatingDetailManagementSnapshot> saveFloatingDetail(
    WorkContext context,
    FloatingDetailDraft draft,
  );
}
