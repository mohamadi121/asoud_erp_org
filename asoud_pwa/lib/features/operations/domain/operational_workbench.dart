import 'package:equatable/equatable.dart';

class OperationFieldSpec extends Equatable {
  const OperationFieldSpec({
    required this.fieldname,
    required this.label,
    required this.fieldtype,
    this.options = '',
    this.required = false,
    this.readOnly = false,
  });

  factory OperationFieldSpec.fromJson(Map<String, dynamic> json) =>
      OperationFieldSpec(
        fieldname: json['fieldname']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        fieldtype: json['fieldtype']?.toString() ?? 'Data',
        options: json['options']?.toString() ?? '',
        required: json['required'] == true || json['required'] == 1,
        readOnly: json['read_only'] == true || json['read_only'] == 1,
      );

  final String fieldname;
  final String label;
  final String fieldtype;
  final String options;
  final bool required;
  final bool readOnly;

  List<String> get selectOptions => options
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  @override
  List<Object?> get props =>
      [fieldname, label, fieldtype, options, required, readOnly];
}

class OperationContract extends Equatable {
  const OperationContract({
    required this.documentType,
    required this.label,
    required this.fields,
    required this.childFields,
    required this.fieldSpecs,
    required this.childFieldSpecs,
    this.childTable,
    this.childRequired = false,
  });

  factory OperationContract.fromJson(Map<String, dynamic> json) =>
      OperationContract(
        documentType: json['document_type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        childTable: json['child_table']?.toString(),
        childFields: (json['child_fields'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        fieldSpecs: _specs(json['field_specs'], json['fields']),
        childFieldSpecs:
            _specs(json['child_field_specs'], json['child_fields']),
        childRequired:
            json['child_required'] == true || json['child_required'] == 1,
      );

  final String documentType;
  final String label;
  final List<String> fields;
  final String? childTable;
  final List<String> childFields;
  final List<OperationFieldSpec> fieldSpecs;
  final List<OperationFieldSpec> childFieldSpecs;
  final bool childRequired;

  @override
  List<Object?> get props => [
        documentType,
        label,
        fields,
        childTable,
        childFields,
        fieldSpecs,
        childFieldSpecs,
        childRequired,
      ];
}

List<OperationFieldSpec> _specs(Object? value, Object? fallback) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) =>
            OperationFieldSpec.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
  return (fallback as List<dynamic>? ?? const [])
      .map((field) => OperationFieldSpec(
            fieldname: field.toString(),
            label: field.toString(),
            fieldtype: 'Data',
          ))
      .toList(growable: false);
}

class OperationalDocument extends Equatable {
  const OperationalDocument({
    required this.documentType,
    required this.name,
    required this.docstatus,
    this.status,
    this.postingDate,
    this.amount,
    this.approvalStatus,
    this.approvalRequest,
  });

  factory OperationalDocument.fromJson(Map<String, dynamic> json) =>
      OperationalDocument(
        documentType: json['document_type']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        docstatus: (json['docstatus'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString(),
        postingDate:
            (json['posting_date'] ?? json['transaction_date'])?.toString(),
        amount: ((json['grand_total'] ?? json['amount']) as num?)?.toDouble(),
        approvalStatus: json['asoud_approval_status']?.toString(),
        approvalRequest: json['asoud_approval_request']?.toString(),
      );

  final String documentType;
  final String name;
  final int docstatus;
  final String? status;
  final String? postingDate;
  final double? amount;
  final String? approvalStatus;
  final String? approvalRequest;

  @override
  List<Object?> get props => [
        documentType,
        name,
        docstatus,
        status,
        postingDate,
        amount,
        approvalStatus,
        approvalRequest,
      ];
}

class OperationalWorkbench extends Equatable {
  const OperationalWorkbench({
    required this.contracts,
    required this.documents,
  });

  factory OperationalWorkbench.fromJson(Map<String, dynamic> json) =>
      OperationalWorkbench(
        contracts: (json['contracts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OperationContract.fromJson)
            .toList(growable: false),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OperationalDocument.fromJson)
            .toList(growable: false),
      );

  final List<OperationContract> contracts;
  final List<OperationalDocument> documents;

  @override
  List<Object?> get props => [contracts, documents];
}
