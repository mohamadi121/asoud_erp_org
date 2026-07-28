import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class OrganizationGateway {
  Future<OrganizationSnapshot> load(WorkContext context);
  Future<void> save(OrganizationDraft draft);
}
