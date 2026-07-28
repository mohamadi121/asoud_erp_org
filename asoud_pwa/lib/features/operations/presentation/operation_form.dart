import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showOperationForm(
  BuildContext context, {
  required OperationContract contract,
  required OperationsGateway gateway,
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OperationForm(contract: contract, gateway: gateway),
    );

class _OperationForm extends StatefulWidget {
  const _OperationForm({required this.contract, required this.gateway});

  final OperationContract contract;
  final OperationsGateway gateway;

  @override
  State<_OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<_OperationForm> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers = {
    for (final spec in widget.contract.fieldSpecs)
      if (spec.fieldname != 'idempotency_key')
        spec.fieldname: TextEditingController(
          text: spec.fieldtype == 'Date'
              ? DateTime.now().toIso8601String().substring(0, 10)
              : '',
        ),
  };
  late final List<Map<String, TextEditingController>> rows = [
    if (widget.contract.childTable != null) _newRow(),
  ];
  String? rowError;

  Map<String, TextEditingController> _newRow() => {
        for (final spec in widget.contract.childFieldSpecs)
          spec.fieldname: TextEditingController(),
      };

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final row in rows) {
      for (final controller in row.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _save() {
    setState(() => rowError = null);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final payload = <String, dynamic>{
      for (final spec in widget.contract.fieldSpecs)
        if (controllers[spec.fieldname]?.text.trim().isNotEmpty ?? false)
          spec.fieldname: _typed(spec, controllers[spec.fieldname]!.text),
    };
    if (widget.contract.childTable != null) {
      final childRows = rows
          .map((row) => {
                for (final spec in widget.contract.childFieldSpecs)
                  if (row[spec.fieldname]?.text.trim().isNotEmpty ?? false)
                    spec.fieldname: _typed(spec, row[spec.fieldname]!.text),
              })
          .where((row) => row.isNotEmpty)
          .toList(growable: false);
      if (widget.contract.childRequired && childRows.isEmpty) {
        setState(() => rowError = 'حداقل یک ردیف کامل برای این سند لازم است.');
        return;
      }
      if (childRows.isNotEmpty) {
        payload[widget.contract.childTable!] = childRows;
      }
    }
    Navigator.pop(context, payload);
  }

  Object _typed(OperationFieldSpec spec, String raw) {
    final value = raw.trim().replaceAll(',', '');
    if (spec.fieldtype == 'Check') {
      return value == '1' || value.toLowerCase() == 'true';
    }
    if (const {'Int', 'Float', 'Currency', 'Percent'}
        .contains(spec.fieldtype)) {
      return num.tryParse(value) ?? value;
    }
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.note_add_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text('پیش‌نویس ${widget.contract.label}')),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final spec in widget.contract.fieldSpecs)
                    if (spec.fieldname != 'idempotency_key')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Field(
                          spec: spec,
                          controller: controllers[spec.fieldname]!,
                          contract: widget.contract,
                          gateway: widget.gateway,
                        ),
                      ),
                  if (widget.contract.childTable != null) ...[
                    const Divider(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ردیف‌های سند${widget.contract.childRequired ? ' *' : ''}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => rows.add(_newRow())),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('افزودن ردیف'),
                        ),
                      ],
                    ),
                    if (rowError != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          rowError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    for (var index = 0; index < rows.length; index++)
                      Card.outlined(
                        margin: const EdgeInsets.only(top: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('ردیف ${index + 1}')),
                                  IconButton(
                                    tooltip: 'حذف ردیف',
                                    onPressed: rows.length == 1
                                        ? null
                                        : () => setState(() {
                                              for (final controller in rows
                                                  .removeAt(index)
                                                  .values) {
                                                controller.dispose();
                                              }
                                            }),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              for (final spec
                                  in widget.contract.childFieldSpecs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _Field(
                                    spec: spec,
                                    controller: rows[index][spec.fieldname]!,
                                    contract: widget.contract,
                                    gateway: widget.gateway,
                                    child: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('ثبت پیش‌نویس'),
          ),
        ],
      );
}

class _Field extends StatefulWidget {
  const _Field({
    required this.spec,
    required this.controller,
    required this.contract,
    required this.gateway,
    this.child = false,
  });

  final OperationFieldSpec spec;
  final TextEditingController controller;
  final OperationContract contract;
  final OperationsGateway gateway;
  final bool child;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  String? _validate(String? value) {
    if (widget.spec.required && (value == null || value.trim().isEmpty)) {
      return '${_label(widget.spec)} الزامی است.';
    }
    if (value != null &&
        value.trim().isNotEmpty &&
        const {'Int', 'Float', 'Currency', 'Percent'}
            .contains(widget.spec.fieldtype) &&
        num.tryParse(value.replaceAll(',', '')) == null) {
      return 'مقدار عددی معتبر وارد کنید.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(widget.controller.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(1300),
      lastDate: DateTime(2200),
    );
    if (selected != null) {
      widget.controller.text = selected.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _pickLink() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _LinkPicker(
        title: _label(widget.spec),
        loader: (search) => widget.gateway.linkOptions(
          documentType: widget.contract.documentType,
          fieldname: widget.spec.fieldname,
          search: search,
          child: widget.child,
        ),
      ),
    );
    if (value != null) widget.controller.text = value;
  }

  @override
  Widget build(BuildContext context) {
    final label = '${_label(widget.spec)}${widget.spec.required ? ' *' : ''}';
    if (widget.spec.fieldtype == 'Check') {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => CheckboxListTile(
          value: value.text == '1' || value.text == 'true',
          onChanged: widget.spec.readOnly
              ? null
              : (checked) =>
                  widget.controller.text = checked == true ? '1' : '0',
          title: Text(label),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }
    final options = widget.spec.selectOptions;
    if (widget.spec.fieldtype == 'Select' && options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: options.contains(widget.controller.text)
            ? widget.controller.text
            : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: widget.spec.readOnly
            ? null
            : (value) => widget.controller.text = value ?? '',
        validator: _validate,
      );
    }
    return TextFormField(
      controller: widget.controller,
      readOnly: widget.spec.readOnly ||
          widget.spec.fieldtype == 'Date' ||
          widget.spec.fieldtype == 'Link',
      keyboardType: const {'Int', 'Float', 'Currency', 'Percent'}
              .contains(widget.spec.fieldtype)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLines:
          {'Small Text', 'Text', 'Long Text'}.contains(widget.spec.fieldtype)
              ? 3
              : 1,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: widget.spec.fieldtype == 'Date'
            ? IconButton(
                tooltip: 'انتخاب تاریخ',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              )
            : widget.spec.fieldtype == 'Link'
                ? IconButton(
                    tooltip: 'انتخاب از فهرست',
                    onPressed: _pickLink,
                    icon: const Icon(Icons.manage_search),
                  )
                : null,
      ),
      validator: _validate,
    );
  }
}

class _LinkPicker extends StatefulWidget {
  const _LinkPicker({required this.title, required this.loader});

  final String title;
  final Future<List<String>> Function(String search) loader;

  @override
  State<_LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends State<_LinkPicker> {
  final search = TextEditingController();
  late Future<List<String>> options = widget.loader('');

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('انتخاب ${widget.title}'),
        content: SizedBox(
          width: 440,
          height: 420,
          child: Column(
            children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'جست‌وجو',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'جست‌وجو',
                    onPressed: () =>
                        setState(() => options = widget.loader(search.text)),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onSubmitted: (value) =>
                    setState(() => options = widget.loader(value)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: options,
                  builder: (context, state) {
                    if (!state.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.hasError) {
                      return Center(child: Text(state.error.toString()));
                    }
                    if (state.data!.isEmpty) {
                      return const Center(child: Text('گزینه‌ای یافت نشد.'));
                    }
                    return ListView(
                      children: [
                        for (final option in state.data!)
                          ListTile(
                            leading: const Icon(Icons.link),
                            title: Text(option),
                            onTap: () => Navigator.pop(context, option),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
        ],
      );
}

String _label(OperationFieldSpec spec) {
  if (spec.label.isNotEmpty && spec.label != spec.fieldname) return spec.label;
  return const {
        'customer': 'مشتری',
        'supplier': 'تأمین‌کننده',
        'posting_date': 'تاریخ ثبت',
        'due_date': 'تاریخ سررسید',
        'currency': 'ارز',
        'update_stock': 'اثر هم‌زمان انبار',
        'remarks': 'شرح',
        'payment_type': 'نوع دریافت/پرداخت',
        'party_type': 'نوع طرف حساب',
        'party': 'طرف حساب',
        'paid_from': 'حساب مبدأ',
        'paid_to': 'حساب مقصد',
        'paid_amount': 'مبلغ پرداخت',
        'received_amount': 'مبلغ دریافت',
        'reference_no': 'شماره مرجع',
        'reference_date': 'تاریخ مرجع',
        'stock_entry_type': 'نوع عملیات انبار',
        'item_code': 'کالا یا خدمت',
        'qty': 'تعداد',
        'rate': 'نرخ',
        'warehouse': 'انبار',
        'account': 'حساب',
        'amount': 'مبلغ',
      }[spec.fieldname] ??
      spec.fieldname;
}
