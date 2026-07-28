import 'package:equatable/equatable.dart';

class ReportColumn extends Equatable {
  const ReportColumn({
    required this.key,
    required this.label,
    required this.type,
  });

  factory ReportColumn.fromJson(Map<String, dynamic> json) => ReportColumn(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        type: json['type']?.toString() ?? 'text',
      );

  final String key;
  final String label;
  final String type;

  @override
  List<Object?> get props => [key, label, type];
}

class StandardReport extends Equatable {
  const StandardReport({
    required this.type,
    required this.title,
    required this.fromDateJalali,
    required this.toDateJalali,
    required this.currency,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.checksum,
  });

  factory StandardReport.fromJson(Map<String, dynamic> json) {
    final columns =
        json['columns'] is List ? json['columns'] as List : const <dynamic>[];
    final rows =
        json['rows'] is List ? json['rows'] as List : const <dynamic>[];
    return StandardReport(
      type: json['report_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      fromDateJalali: json['from_date_jalali']?.toString() ?? '',
      toDateJalali: json['to_date_jalali']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'IRR',
      columns: columns
          .whereType<Map>()
          .map((row) => ReportColumn.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      rows: rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      totals: json['totals'] is Map
          ? Map<String, dynamic>.from(json['totals'] as Map)
          : const {},
      checksum: json['checksum']?.toString() ?? '',
    );
  }

  final String type;
  final String title;
  final String fromDateJalali;
  final String toDateJalali;
  final String currency;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;
  final String checksum;

  @override
  List<Object?> get props => [
        type,
        title,
        fromDateJalali,
        toDateJalali,
        currency,
        columns,
        rows,
        totals,
        checksum,
      ];
}
