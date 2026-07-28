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
  Future<AccountRulesSnapshot> loadAccountRules(WorkContext context);
  Future<AccountRulesSnapshot> saveChartAccount(
    WorkContext context,
    ChartAccountDraft draft,
  );
}
