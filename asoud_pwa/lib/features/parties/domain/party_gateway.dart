import 'package:asoud_pwa/features/parties/domain/party_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class PartyGateway {
  Future<PartySnapshot> load(WorkContext context, {String search = ''});

  Future<Map<String, String>> previewCodes(
    WorkContext context,
    Set<String> roles,
  );

  Future<PartyProfile> loadDetail(WorkContext context, String name);

  Future<void> save(WorkContext context, PartyDraft draft);
}
