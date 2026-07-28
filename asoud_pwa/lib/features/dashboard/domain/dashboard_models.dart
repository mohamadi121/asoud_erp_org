import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:equatable/equatable.dart';

class DashboardMetric extends Equatable {
  const DashboardMetric({
    required this.key,
    required this.value,
    this.trend,
  });

  factory DashboardMetric.fromJson(Map<String, dynamic> json) =>
      DashboardMetric(
        key: json['key']?.toString() ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        trend: (json['trend'] as num?)?.toDouble(),
      );

  final String key;
  final double value;
  final double? trend;

  @override
  List<Object?> get props => [key, value, trend];
}

class CashFlowPoint extends Equatable {
  const CashFlowPoint({
    required this.period,
    required this.receipts,
    required this.payments,
  });

  factory CashFlowPoint.fromJson(Map<String, dynamic> json) => CashFlowPoint(
        period: json['period']?.toString() ?? '',
        receipts: (json['receipts'] as num?)?.toDouble() ?? 0,
        payments: (json['payments'] as num?)?.toDouble() ?? 0,
      );

  final String period;
  final double receipts;
  final double payments;

  @override
  List<Object?> get props => [period, receipts, payments];
}

class IncomeSlice extends Equatable {
  const IncomeSlice({required this.category, required this.amount});

  factory IncomeSlice.fromJson(Map<String, dynamic> json) => IncomeSlice(
        category: json['category']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );

  final String category;
  final double amount;

  @override
  List<Object?> get props => [category, amount];
}

class DashboardApproval extends Equatable {
  const DashboardApproval({
    required this.name,
    required this.sourceType,
    required this.sourceName,
    required this.requestedBy,
    required this.requestedOn,
    this.amount,
  });

  factory DashboardApproval.fromJson(Map<String, dynamic> json) =>
      DashboardApproval(
        name: json['name']?.toString() ?? '',
        sourceType: json['source_doctype']?.toString() ?? '',
        sourceName: json['source_name']?.toString() ?? '',
        requestedBy: json['requested_by']?.toString() ?? '',
        requestedOn: json['requested_on']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
      );

  final String name;
  final String sourceType;
  final String sourceName;
  final String requestedBy;
  final String requestedOn;
  final double? amount;

  @override
  List<Object?> get props =>
      [name, sourceType, sourceName, requestedBy, requestedOn, amount];
}

class DashboardNotification extends Equatable {
  const DashboardNotification({
    required this.name,
    required this.subject,
    required this.creation,
    required this.read,
    this.documentType,
    this.documentName,
  });

  factory DashboardNotification.fromJson(Map<String, dynamic> json) =>
      DashboardNotification(
        name: json['name']?.toString() ?? '',
        subject: json['subject']?.toString() ?? '',
        creation: json['creation']?.toString() ?? '',
        read: json['read'] == 1 || json['read'] == true,
        documentType: json['document_type']?.toString(),
        documentName: json['document_name']?.toString(),
      );

  final String name;
  final String subject;
  final String creation;
  final bool read;
  final String? documentType;
  final String? documentName;

  @override
  List<Object?> get props =>
      [name, subject, creation, read, documentType, documentName];
}

class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.asOfDate,
    required this.generatedAt,
    required this.currency,
    required this.cards,
    required this.cashFlow,
    required this.incomeMix,
    required this.recentOperations,
    required this.approvals,
    required this.incomingApprovalCount,
    required this.outgoingApprovalCount,
    required this.notifications,
    required this.quickCreateContracts,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final inbox = json['approval_inbox'] is Map
        ? Map<String, dynamic>.from(json['approval_inbox'] as Map)
        : const <String, dynamic>{};
    final counts = inbox['counts'] is Map
        ? Map<String, dynamic>.from(inbox['counts'] as Map)
        : const <String, dynamic>{};
    return DashboardSnapshot(
      asOfDate: json['as_of_date']?.toString() ?? '',
      generatedAt: json['generated_at']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      cards: _rows(json['cards']).map(DashboardMetric.fromJson).toList(),
      cashFlow: _rows(json['cash_flow']).map(CashFlowPoint.fromJson).toList(),
      incomeMix: _rows(json['income_mix']).map(IncomeSlice.fromJson).toList(),
      recentOperations: _rows(json['recent_operations'])
          .map(OperationalDocument.fromJson)
          .toList(),
      approvals: _rows(inbox['items']).map(DashboardApproval.fromJson).toList(),
      incomingApprovalCount: (counts['incoming'] as num?)?.toInt() ?? 0,
      outgoingApprovalCount: (counts['outgoing'] as num?)?.toInt() ?? 0,
      notifications: _rows(json['notifications'])
          .map(DashboardNotification.fromJson)
          .toList(),
      quickCreateContracts: _rows(json['quick_create_contracts'])
          .map(OperationContract.fromJson)
          .toList(),
    );
  }

  final String asOfDate;
  final String generatedAt;
  final String currency;
  final List<DashboardMetric> cards;
  final List<CashFlowPoint> cashFlow;
  final List<IncomeSlice> incomeMix;
  final List<OperationalDocument> recentOperations;
  final List<DashboardApproval> approvals;
  final int incomingApprovalCount;
  final int outgoingApprovalCount;
  final List<DashboardNotification> notifications;
  final List<OperationContract> quickCreateContracts;

  DashboardMetric metric(String key) => cards.firstWhere(
        (item) => item.key == key,
        orElse: () => DashboardMetric(key: key, value: 0),
      );

  @override
  List<Object?> get props => [
        asOfDate,
        generatedAt,
        currency,
        cards,
        cashFlow,
        incomeMix,
        recentOperations,
        approvals,
        incomingApprovalCount,
        outgoingApprovalCount,
        notifications,
        quickCreateContracts,
      ];
}

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false)
    : const [];
