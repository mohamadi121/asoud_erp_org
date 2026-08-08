import 'package:equatable/equatable.dart';

class ApprovalInbox extends Equatable {
  const ApprovalInbox({
    required this.items,
    required this.incomingCount,
    required this.outgoingCount,
    required this.historyCount,
  });

  factory ApprovalInbox.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    return ApprovalInbox(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ApprovalSummary.fromJson)
          .toList(growable: false),
      incomingCount: (counts['incoming'] as num?)?.toInt() ?? 0,
      outgoingCount: (counts['outgoing'] as num?)?.toInt() ?? 0,
      historyCount: (counts['history'] as num?)?.toInt() ?? 0,
    );
  }

  final List<ApprovalSummary> items;
  final int incomingCount;
  final int outgoingCount;
  final int historyCount;

  @override
  List<Object?> get props =>
      [items, incomingCount, outgoingCount, historyCount];
}

class ApprovalSummary extends Equatable {
  const ApprovalSummary({
    required this.name,
    required this.sourceDoctype,
    required this.sourceName,
    required this.company,
    required this.policy,
    required this.amount,
    required this.requestedBy,
    required this.requestedOn,
    required this.status,
    required this.currentSequence,
    required this.version,
    this.branch,
  });

  factory ApprovalSummary.fromJson(Map<String, dynamic> json) =>
      ApprovalSummary(
        name: json['name']?.toString() ?? '',
        sourceDoctype: json['source_doctype']?.toString() ?? '',
        sourceName: json['source_name']?.toString() ?? '',
        company: json['company']?.toString() ?? '',
        branch: json['branch']?.toString(),
        policy: json['policy']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        requestedBy: json['requested_by']?.toString() ?? '',
        requestedOn: json['requested_on']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        currentSequence: (json['current_sequence'] as num?)?.toInt() ?? 0,
        version: (json['version'] ?? json['modified'])?.toString() ?? '',
      );

  final String name;
  final String sourceDoctype;
  final String sourceName;
  final String company;
  final String? branch;
  final String policy;
  final double amount;
  final String requestedBy;
  final String requestedOn;
  final String status;
  final int currentSequence;
  final String version;

  @override
  List<Object?> get props => [
        name,
        sourceDoctype,
        sourceName,
        company,
        branch,
        policy,
        amount,
        requestedBy,
        requestedOn,
        status,
        currentSequence,
        version,
      ];
}

class ApprovalDetail extends Equatable {
  const ApprovalDetail({
    required this.summary,
    required this.canAct,
    required this.stages,
    required this.actions,
  });

  factory ApprovalDetail.fromJson(Map<String, dynamic> json) => ApprovalDetail(
        summary: ApprovalSummary.fromJson(json),
        canAct: json['can_act'] == true,
        stages: (json['stages'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ApprovalStage.fromJson)
            .toList(growable: false),
        actions: (json['actions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ApprovalAction.fromJson)
            .toList(growable: false),
      );

  final ApprovalSummary summary;
  final bool canAct;
  final List<ApprovalStage> stages;
  final List<ApprovalAction> actions;

  @override
  List<Object?> get props => [summary, canAct, stages, actions];
}

class ApprovalStage extends Equatable {
  const ApprovalStage({
    required this.key,
    required this.sequence,
    required this.title,
    required this.approverType,
    required this.approver,
  });

  factory ApprovalStage.fromJson(Map<String, dynamic> json) => ApprovalStage(
        key: json['key']?.toString() ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        approverType: json['approver_type']?.toString() ?? '',
        approver: json['approver']?.toString() ?? '',
      );

  final String key;
  final int sequence;
  final String title;
  final String approverType;
  final String approver;

  @override
  List<Object?> get props => [key, sequence, title, approverType, approver];
}

class ApprovalAction extends Equatable {
  const ApprovalAction({
    required this.sequence,
    required this.action,
    required this.actor,
    required this.actedOn,
    required this.comment,
    this.actingFor,
  });

  factory ApprovalAction.fromJson(Map<String, dynamic> json) => ApprovalAction(
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        action: json['action']?.toString() ?? '',
        actor: json['actor']?.toString() ?? '',
        actingFor: json['acting_for']?.toString(),
        actedOn: json['acted_on']?.toString() ?? '',
        comment: json['comment']?.toString() ?? '',
      );

  final int sequence;
  final String action;
  final String actor;
  final String? actingFor;
  final String actedOn;
  final String comment;

  @override
  List<Object?> get props =>
      [sequence, action, actor, actingFor, actedOn, comment];
}

class ApprovalPolicySummary extends Equatable {
  const ApprovalPolicySummary({
    required this.name,
    required this.title,
    required this.documentType,
    required this.parallelMode,
    required this.minimumAmount,
    required this.maximumAmount,
    this.enabled = true,
    this.priority = 0,
    this.version = 1,
    this.allowSelfApproval = false,
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.stages = const [],
    this.company,
    this.branch,
  });

  factory ApprovalPolicySummary.fromJson(Map<String, dynamic> json) =>
      ApprovalPolicySummary(
        name: json['name']?.toString() ?? '',
        title: json['policy_title']?.toString() ?? '',
        documentType: json['document_type']?.toString() ?? '',
        company: json['company']?.toString(),
        branch: json['branch']?.toString(),
        parallelMode: json['parallel_mode']?.toString() ?? 'All',
        minimumAmount: (json['minimum_amount'] as num?)?.toDouble() ?? 0,
        maximumAmount: (json['maximum_amount'] as num?)?.toDouble() ?? 0,
        enabled: json['enabled'] == true || json['enabled'] == 1,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        version: (json['policy_version'] as num?)?.toInt() ?? 1,
        allowSelfApproval: json['allow_self_approval'] == true ||
            json['allow_self_approval'] == 1,
        effectiveFrom: json['effective_from']?.toString() ?? '',
        effectiveTo: json['effective_to']?.toString() ?? '',
        stages: (json['stages'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ApprovalPolicyStage.fromJson)
            .toList(growable: false),
      );

  final String name;
  final String title;
  final String documentType;
  final String? company;
  final String? branch;
  final String parallelMode;
  final double minimumAmount;
  final double maximumAmount;
  final bool enabled;
  final int priority;
  final int version;
  final bool allowSelfApproval;
  final String effectiveFrom;
  final String effectiveTo;
  final List<ApprovalPolicyStage> stages;

  @override
  List<Object?> get props => [
        name,
        title,
        documentType,
        company,
        branch,
        parallelMode,
        minimumAmount,
        maximumAmount,
        enabled,
        priority,
        version,
        allowSelfApproval,
        effectiveFrom,
        effectiveTo,
        stages,
      ];
}

class ApprovalPolicyStage extends Equatable {
  const ApprovalPolicyStage({
    required this.sequence,
    required this.title,
    required this.approverType,
    this.user = '',
    this.role = '',
    this.dueHours = 0,
  });

  factory ApprovalPolicyStage.fromJson(Map<String, dynamic> json) =>
      ApprovalPolicyStage(
        sequence: (json['sequence'] as num?)?.toInt() ?? 1,
        title: json['stage_title']?.toString() ?? '',
        approverType: json['approver_type']?.toString() ?? 'Role',
        user: json['user']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        dueHours: (json['due_hours'] as num?)?.toInt() ?? 0,
      );

  final int sequence;
  final String title;
  final String approverType;
  final String user;
  final String role;
  final int dueHours;

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'stage_title': title,
        'approver_type': approverType,
        'user': user.isEmpty ? null : user,
        'role': role.isEmpty ? null : role,
        'due_hours': dueHours,
      };

  @override
  List<Object?> get props =>
      [sequence, title, approverType, user, role, dueHours];
}

class ApprovalPolicyWorkspace extends Equatable {
  const ApprovalPolicyWorkspace({
    this.policies = const [],
    this.documentTypes = const [],
    this.branches = const {},
    this.users = const {},
    this.roles = const [],
  });

  factory ApprovalPolicyWorkspace.fromJson(Map<String, dynamic> json) {
    Map<String, String> options(String key, String labelKey) => {
          for (final row
              in (json[key] as List<dynamic>? ?? const []).whereType<Map>())
            row['name']?.toString() ?? '':
                row[labelKey]?.toString() ?? row['name']?.toString() ?? '',
        }..remove('');

    return ApprovalPolicyWorkspace(
      policies: (json['policies'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ApprovalPolicySummary.fromJson)
          .toList(growable: false),
      documentTypes: (json['document_types'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      branches: options('branches', 'branch_name'),
      users: options('users', 'full_name'),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }

  final List<ApprovalPolicySummary> policies;
  final List<String> documentTypes;
  final Map<String, String> branches;
  final Map<String, String> users;
  final List<String> roles;

  @override
  List<Object?> get props => [policies, documentTypes, branches, users, roles];
}

class ApprovalPolicyDraft extends Equatable {
  const ApprovalPolicyDraft({
    this.name = '',
    this.title = '',
    this.documentType = '',
    this.branch = '',
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.minimumAmount = 0,
    this.maximumAmount = 0,
    this.priority = 0,
    this.enabled = true,
    this.allowSelfApproval = false,
    this.parallelMode = 'All',
    this.stages = const [],
  });

  factory ApprovalPolicyDraft.fromPolicy(ApprovalPolicySummary value) =>
      ApprovalPolicyDraft(
        name: value.name,
        title: value.title,
        documentType: value.documentType,
        branch: value.branch ?? '',
        effectiveFrom: value.effectiveFrom,
        effectiveTo: value.effectiveTo,
        minimumAmount: value.minimumAmount,
        maximumAmount: value.maximumAmount,
        priority: value.priority,
        enabled: value.enabled,
        allowSelfApproval: value.allowSelfApproval,
        parallelMode: value.parallelMode,
        stages: value.stages,
      );

  final String name;
  final String title;
  final String documentType;
  final String branch;
  final String effectiveFrom;
  final String effectiveTo;
  final double minimumAmount;
  final double maximumAmount;
  final int priority;
  final bool enabled;
  final bool allowSelfApproval;
  final String parallelMode;
  final List<ApprovalPolicyStage> stages;

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'policy_title': title,
        'document_type': documentType,
        'branch': branch.isEmpty ? null : branch,
        'effective_from': effectiveFrom.isEmpty ? null : effectiveFrom,
        'effective_to': effectiveTo.isEmpty ? null : effectiveTo,
        'minimum_amount': minimumAmount,
        'maximum_amount': maximumAmount,
        'priority': priority,
        'enabled': enabled,
        'allow_self_approval': allowSelfApproval,
        'parallel_mode': parallelMode,
        'stages': stages.map((row) => row.toJson()).toList(growable: false),
      };

  @override
  List<Object?> get props => [
        name,
        title,
        documentType,
        branch,
        effectiveFrom,
        effectiveTo,
        minimumAmount,
        maximumAmount,
        priority,
        enabled,
        allowSelfApproval,
        parallelMode,
        stages,
      ];
}

class AccessOverview extends Equatable {
  const AccessOverview({required this.users});

  factory AccessOverview.fromJson(Map<String, dynamic> json) => AccessOverview(
        users: (json['users'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AccessGrantSummary.fromJson)
            .toList(growable: false),
      );

  final List<AccessGrantSummary> users;

  @override
  List<Object?> get props => [users];
}

class AccessGrantSummary extends Equatable {
  const AccessGrantSummary({
    required this.name,
    required this.user,
    required this.fullName,
    required this.company,
    required this.enabled,
    required this.holdingManager,
    required this.roles,
    this.branch,
  });

  factory AccessGrantSummary.fromJson(Map<String, dynamic> json) =>
      AccessGrantSummary(
        name: json['name']?.toString() ?? '',
        user: json['user']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        company: json['company']?.toString() ?? '',
        branch: json['branch']?.toString(),
        enabled: json['enabled'] == true || json['enabled'] == 1,
        holdingManager:
            json['holding_manager'] == true || json['holding_manager'] == 1,
        roles: (json['roles'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );

  final String name;
  final String user;
  final String fullName;
  final String company;
  final String? branch;
  final bool enabled;
  final bool holdingManager;
  final List<String> roles;

  @override
  List<Object?> get props =>
      [name, user, fullName, company, branch, enabled, holdingManager, roles];
}
