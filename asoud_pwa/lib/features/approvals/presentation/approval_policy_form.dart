import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:flutter/material.dart';

Future<ApprovalPolicyDraft?> showApprovalPolicyForm(
  BuildContext context, {
  required ApprovalPolicyWorkspace workspace,
  ApprovalPolicySummary? policy,
}) =>
    showDialog<ApprovalPolicyDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _ApprovalPolicyDialog(
          workspace: workspace,
          policy: policy,
        ),
      ),
    );

class _ApprovalPolicyDialog extends StatefulWidget {
  const _ApprovalPolicyDialog({required this.workspace, this.policy});

  final ApprovalPolicyWorkspace workspace;
  final ApprovalPolicySummary? policy;

  @override
  State<_ApprovalPolicyDialog> createState() => _ApprovalPolicyDialogState();
}

class _ApprovalPolicyDialogState extends State<_ApprovalPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _priority;
  late String _documentType;
  late String _branch;
  late String _effectiveFrom;
  late String _effectiveTo;
  late String _parallelMode;
  late bool _enabled;
  late bool _allowSelfApproval;
  late List<_StageValue> _stages;
  String? _stageError;

  @override
  void initState() {
    super.initState();
    final source = widget.policy == null
        ? ApprovalPolicyDraft(
            documentType: widget.workspace.documentTypes.isEmpty
                ? ''
                : widget.workspace.documentTypes.first,
            stages: const [
              ApprovalPolicyStage(
                sequence: 1,
                title: 'تأیید مدیر',
                approverType: 'Manager',
              ),
            ],
          )
        : ApprovalPolicyDraft.fromPolicy(widget.policy!);
    _title = TextEditingController(text: source.title);
    _minimum = TextEditingController(text: _numberText(source.minimumAmount));
    _maximum = TextEditingController(text: _numberText(source.maximumAmount));
    _priority = TextEditingController(text: source.priority.toString());
    _documentType = source.documentType;
    _branch = source.branch;
    _effectiveFrom = source.effectiveFrom;
    _effectiveTo = source.effectiveTo;
    _parallelMode = source.parallelMode;
    _enabled = source.enabled;
    _allowSelfApproval = source.allowSelfApproval;
    _stages = source.stages.map(_StageValue.fromModel).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _priority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            color: Color(0xfff4f7fc),
            border: Border(bottom: BorderSide(color: Color(0xffdce4f0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xff246bfd)),
              const SizedBox(width: 10),
              Text(widget.policy == null
                  ? 'ایجاد مسیر تأیید'
                  : 'ویرایش مسیر تأیید'),
              const Spacer(),
              if (widget.policy != null)
                Chip(label: Text('نسخه ${widget.policy!.version}')),
            ],
          ),
        ),
        content: SizedBox(
          width: 1020,
          height: MediaQuery.sizeOf(context).height * .72,
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _sectionTitle('مشخصات و دامنه اجرا', Icons.tune),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    _field(
                      child: TextFormField(
                        controller: _title,
                        decoration: _decoration('عنوان مسیر *'),
                        validator: _required,
                      ),
                    ),
                    _field(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _optionValue(
                          _documentType,
                          widget.workspace.documentTypes,
                        ),
                        decoration: _decoration('نوع سند *'),
                        items: widget.workspace.documentTypes
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_doctypeLabel(value)),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _documentType = value ?? ''),
                        validator: (value) => _required(value),
                      ),
                    ),
                    _field(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _branchOption(),
                        decoration: _decoration('شعبه (اختیاری)'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('همه شعب شرکت'),
                          ),
                          ...widget.workspace.branches.entries.map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _branch = value ?? ''),
                      ),
                    ),
                    _field(child: _dateField('شروع اعتبار', true)),
                    _field(child: _dateField('پایان اعتبار', false)),
                    _field(
                      child: TextFormField(
                        controller: _priority,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('اولویت'),
                        validator: _integer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionTitle('شرایط مالی و رفتار تأیید', Icons.rule_outlined),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    _field(
                      child: TextFormField(
                        controller: _minimum,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('حداقل مبلغ'),
                        validator: _decimal,
                      ),
                    ),
                    _field(
                      child: TextFormField(
                        controller: _maximum,
                        keyboardType: TextInputType.number,
                        decoration:
                            _decoration('حداکثر مبلغ (صفر یعنی بدون سقف)'),
                        validator: _decimal,
                      ),
                    ),
                    _field(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _parallelMode,
                        decoration: _decoration('قاعده مراحل هم‌ردیف'),
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('تأیید همه افراد'),
                          ),
                          DropdownMenuItem(
                            value: 'Any',
                            child: Text('تأیید یک نفر کافی است'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _parallelMode = value ?? 'All'),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('مسیر فعال باشد'),
                  onChanged: (value) =>
                      setState(() => _enabled = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowSelfApproval,
                  title: const Text('در صورت داشتن مجوز، خودتأییدی مجاز باشد'),
                  subtitle: const Text(
                    'پیش‌فرض امن، غیرفعال است؛ کنترل نهایی در Backend انجام می‌شود.',
                  ),
                  onChanged: (value) =>
                      setState(() => _allowSelfApproval = value ?? false),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _sectionTitle(
                        'مراحل و تأییدکنندگان',
                        Icons.schema_outlined,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addStage,
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن مرحله'),
                    ),
                  ],
                ),
                const Text(
                  'برای تأیید موازی، شماره ترتیب چند ردیف را یکسان قرار دهید.',
                  style: TextStyle(color: Color(0xff68758a)),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < _stages.length; index++)
                  _stageCard(index),
                if (_stageError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _stageError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('ذخیره مسیر تأیید'),
          ),
        ],
      );

  Widget _stageCard(int index) {
    final stage = _stages[index];
    return Card(
      key: ValueKey(stage.id),
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xfffbfcff),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: stage.sequence.toString(),
                keyboardType: TextInputType.number,
                decoration: _decoration('ترتیب *'),
                validator: _positiveInteger,
                onChanged: (value) => stage.sequence = int.tryParse(value) ?? 0,
              ),
            ),
            SizedBox(
              width: 220,
              child: TextFormField(
                initialValue: stage.title,
                decoration: _decoration('عنوان مرحله *'),
                validator: _required,
                onChanged: (value) => stage.title = value,
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: stage.approverType,
                decoration: _decoration('نوع تأییدکننده'),
                items: const [
                  DropdownMenuItem(value: 'Manager', child: Text('مدیر')),
                  DropdownMenuItem(value: 'Role', child: Text('نقش')),
                  DropdownMenuItem(value: 'User', child: Text('کاربر مشخص')),
                ],
                onChanged: (value) => setState(() {
                  stage.approverType = value ?? 'Manager';
                  stage.user = '';
                  stage.role = '';
                }),
              ),
            ),
            if (stage.approverType == 'Role')
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _optionValue(stage.role, widget.workspace.roles),
                  decoration: _decoration('نقش تأییدکننده *'),
                  items: widget.workspace.roles
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  validator: _required,
                  onChanged: (value) => stage.role = value ?? '',
                ),
              ),
            if (stage.approverType == 'User')
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _optionValue(
                    stage.user,
                    widget.workspace.users.keys.toList(),
                  ),
                  decoration: _decoration('کاربر تأییدکننده *'),
                  items: widget.workspace.users.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text('${entry.value} — ${entry.key}'),
                          ))
                      .toList(),
                  validator: _required,
                  onChanged: (value) => stage.user = value ?? '',
                ),
              ),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: stage.dueHours.toString(),
                keyboardType: TextInputType.number,
                decoration: _decoration('مهلت (ساعت)'),
                validator: _integer,
                onChanged: (value) => stage.dueHours = int.tryParse(value) ?? 0,
              ),
            ),
            IconButton(
              tooltip: 'حذف مرحله',
              onPressed: _stages.length == 1
                  ? null
                  : () => setState(() => _stages.removeAt(index)),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, bool from) {
    final value = from ? _effectiveFrom : _effectiveTo;
    return TextFormField(
      key: ValueKey('$label-$value'),
      readOnly: true,
      initialValue: value,
      decoration: _decoration(label).copyWith(
        suffixIcon: value.isEmpty
            ? const Icon(Icons.calendar_month_outlined)
            : IconButton(
                tooltip: 'پاک‌کردن',
                onPressed: () => setState(() {
                  if (from) {
                    _effectiveFrom = '';
                  } else {
                    _effectiveTo = '';
                  }
                }),
                icon: const Icon(Icons.close),
              ),
      ),
      onTap: () => _pickDate(from),
    );
  }

  Future<void> _pickDate(bool from) async {
    final text = from ? _effectiveFrom : _effectiveTo;
    final initial = DateTime.tryParse(text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    final formatted = value.toIso8601String().substring(0, 10);
    setState(() {
      if (from) {
        _effectiveFrom = formatted;
      } else {
        _effectiveTo = formatted;
      }
    });
  }

  void _addStage() => setState(() {
        final next = _stages.fold<int>(0,
                (value, row) => row.sequence > value ? row.sequence : value) +
            1;
        _stages.add(_StageValue(
          id: DateTime.now().microsecondsSinceEpoch,
          sequence: next,
          title: 'مرحله $next',
          approverType: 'Manager',
        ));
      });

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    final sequences = _stages.map((row) => row.sequence).toSet().toList()
      ..sort();
    final contiguous = sequences.isNotEmpty &&
        List.generate(sequences.last, (index) => index + 1)
            .every(sequences.contains);
    final minimum = double.tryParse(_minimum.text.trim()) ?? 0;
    final maximum = double.tryParse(_maximum.text.trim()) ?? 0;
    final datesValid = _effectiveFrom.isEmpty ||
        _effectiveTo.isEmpty ||
        _effectiveFrom.compareTo(_effectiveTo) <= 0;
    setState(() {
      _stageError = !contiguous
          ? 'ترتیب مراحل باید از ۱ شروع و بدون فاصله باشد.'
          : maximum > 0 && maximum < minimum
              ? 'حداکثر مبلغ نمی‌تواند کمتر از حداقل مبلغ باشد.'
              : !datesValid
                  ? 'پایان اعتبار نمی‌تواند قبل از شروع اعتبار باشد.'
                  : null;
    });
    if (!valid || _stageError != null) return;
    Navigator.pop(
      context,
      ApprovalPolicyDraft(
        name: widget.policy?.name ?? '',
        title: _title.text.trim(),
        documentType: _documentType,
        branch: _branch,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
        minimumAmount: minimum,
        maximumAmount: maximum,
        priority: int.tryParse(_priority.text.trim()) ?? 0,
        enabled: _enabled,
        allowSelfApproval: _allowSelfApproval,
        parallelMode: _parallelMode,
        stages: _stages.map((row) => row.toModel()).toList(growable: false),
      ),
    );
  }

  Widget _field({required Widget child}) => SizedBox(width: 310, child: child);

  Widget _sectionTitle(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xff246bfd)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  String? _required(Object? value) =>
      value == null || value.toString().trim().isEmpty
          ? 'این فیلد الزامی است.'
          : null;

  String? _integer(String? value) =>
      int.tryParse(value?.trim() ?? '') == null ? 'عدد صحیح وارد کنید.' : null;

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1 ? 'حداقل ۱' : null;
  }

  String? _decimal(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number < 0 ? 'عدد نامنفی وارد کنید.' : null;
  }

  String? _optionValue(String value, List<String> options) =>
      value.isNotEmpty && options.contains(value) ? value : null;

  String _branchOption() =>
      _branch.isEmpty || widget.workspace.branches.containsKey(_branch)
          ? _branch
          : '';

  String _numberText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String _doctypeLabel(String value) => switch (value) {
        'Journal Entry' => 'سند حسابداری',
        'Payment Entry' => 'سند پرداخت',
        'Sales Invoice' => 'فاکتور فروش',
        'Purchase Invoice' => 'فاکتور خرید',
        'Stock Entry' => 'سند انبار',
        _ => value,
      };
}

class _StageValue {
  _StageValue({
    required this.id,
    required this.sequence,
    required this.title,
    required this.approverType,
    this.user = '',
    this.role = '',
    this.dueHours = 0,
  });

  factory _StageValue.fromModel(ApprovalPolicyStage value) => _StageValue(
        id: DateTime.now().microsecondsSinceEpoch + value.hashCode,
        sequence: value.sequence,
        title: value.title,
        approverType: value.approverType,
        user: value.user,
        role: value.role,
        dueHours: value.dueHours,
      );

  final int id;
  int sequence;
  String title;
  String approverType;
  String user;
  String role;
  int dueHours;

  ApprovalPolicyStage toModel() => ApprovalPolicyStage(
        sequence: sequence,
        title: title.trim(),
        approverType: approverType,
        user: user,
        role: role,
        dueHours: dueHours,
      );
}
