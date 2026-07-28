import 'package:equatable/equatable.dart';

class WorkContext extends Equatable {
  const WorkContext(
      {required this.company, this.branch, this.branchName, this.holding});

  factory WorkContext.fromJson(Map<String, dynamic> json) => WorkContext(
        company: json['company'] as String,
        branch: json['branch'] as String?,
        branchName: json['branch_name'] as String?,
        holding: json['holding'] as String?,
      );

  final String company;
  final String? branch;
  final String? branchName;
  final String? holding;

  String get label => branchName == null ? company : '$company - $branchName';

  @override
  List<Object?> get props => [company, branch, branchName, holding];
}
