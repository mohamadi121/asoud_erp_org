import 'package:equatable/equatable.dart';

class OperationsSnapshot extends Equatable {
  const OperationsSnapshot({
    required this.sales,
    required this.purchases,
    required this.receipts,
    required this.payments,
    required this.stockQty,
    required this.stockValue,
  });

  factory OperationsSnapshot.fromJson(Map<String, dynamic> json) =>
      OperationsSnapshot(
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
        purchases: (json['purchases'] as num?)?.toDouble() ?? 0,
        receipts: (json['receipts'] as num?)?.toDouble() ?? 0,
        payments: (json['payments'] as num?)?.toDouble() ?? 0,
        stockQty: (json['stock_qty'] as num?)?.toDouble() ?? 0,
        stockValue: (json['stock_value'] as num?)?.toDouble() ?? 0,
      );

  final double sales;
  final double purchases;
  final double receipts;
  final double payments;
  final double stockQty;
  final double stockValue;

  @override
  List<Object?> get props =>
      [sales, purchases, receipts, payments, stockQty, stockValue];
}
