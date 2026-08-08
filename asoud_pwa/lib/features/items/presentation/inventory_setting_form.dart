import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:flutter/material.dart';

Future<InventorySettingDraft?> showInventorySettingForm(
  BuildContext context, {
  required InventoryWorkspace workspace,
  required String settingType,
  InventoryRow? row,
}) =>
    showDialog<InventorySettingDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _InventorySettingDialog(
          workspace: workspace,
          initial: _fromRow(settingType, row),
        ),
      ),
    );

InventorySettingDraft _fromRow(String type, InventoryRow? row) {
  if (row == null) return InventorySettingDraft(settingType: type);
  return switch (type) {
    'Warehouse' => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        label: row.text('warehouse_name'),
        parent: row.text('parent_warehouse'),
        warehouseType: row.text('warehouse_type'),
        branch: row.text('branch'),
        account: row.text('account'),
        isGroup: row.flag('is_group'),
        disabled: row.flag('disabled'),
      ),
    'Warehouse Type' => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        label: row.text('name'),
        description: row.text('description'),
      ),
    'Item Group' => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        label: row.text('item_group_name'),
        parent: row.text('parent_item_group'),
        isGroup: row.flag('is_group'),
      ),
    'UOM' => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        label: row.text('uom_name'),
        enabled: row.flag('enabled'),
        wholeNumber: row.flag('must_be_whole_number'),
      ),
    'UOM Category' => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        label: row.text('category_name'),
      ),
    _ => InventorySettingDraft(
        settingType: type,
        name: row.text('name'),
        category: row.text('category'),
        fromUom: row.text('from_uom'),
        toUom: row.text('to_uom'),
        value: row.number('value'),
      ),
  };
}

class _InventorySettingDialog extends StatefulWidget {
  const _InventorySettingDialog(
      {required this.workspace, required this.initial});

  final InventoryWorkspace workspace;
  final InventorySettingDraft initial;

  @override
  State<_InventorySettingDialog> createState() =>
      _InventorySettingDialogState();
}

class _InventorySettingDialogState extends State<_InventorySettingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _description;
  late final TextEditingController _value;
  late String _parent;
  late String _warehouseType;
  late String _branch;
  late String _account;
  late String _category;
  late String _fromUom;
  late String _toUom;
  late bool _isGroup;
  late bool _disabled;
  late bool _enabled;
  late bool _wholeNumber;

  InventorySettingDraft get initial => widget.initial;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: initial.label);
    _description = TextEditingController(text: initial.description);
    _value = TextEditingController(
      text: initial.value == 0 ? '' : initial.value.toString(),
    );
    _parent = initial.parent;
    _warehouseType = initial.warehouseType;
    _branch = initial.branch;
    _account = initial.account;
    _category = initial.category;
    _fromUom = initial.fromUom;
    _toUom = initial.toUom;
    _isGroup = initial.isGroup;
    _disabled = initial.disabled;
    _enabled = initial.enabled;
    _wholeNumber = initial.wholeNumber;
  }

  @override
  void dispose() {
    _label.dispose();
    _description.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: const BoxDecoration(
            color: Color(0xfff4f7fc),
            border: Border(bottom: BorderSide(color: Color(0xffdce4f0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xff246bfd)),
              const SizedBox(width: 10),
              Text(
                  '${initial.name.isEmpty ? 'ایجاد' : 'ویرایش'} ${_title(initial.settingType)}'),
            ],
          ),
        ),
        content: SizedBox(
          width: 720,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _fields(),
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
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('ذخیره'),
          ),
        ],
      );

  List<Widget> _fields() => switch (initial.settingType) {
        'Warehouse' => [
            _text('نام انبار *', _label, readOnly: initial.name.isNotEmpty),
            _dropdown(
              'انبار والد${initial.name.isEmpty ? ' *' : ''}',
              _parent,
              {
                for (final row in widget.workspace.warehouses
                    .where((row) => row.text('name') != initial.name))
                  row.text('name'): row.text('warehouse_name'),
              },
              (value) => _parent = value,
              isRequired: initial.name.isEmpty,
            ),
            _dropdown(
              'نوع انبار',
              _warehouseType,
              {
                for (final row in widget.workspace.warehouseTypes)
                  row.text('name'): row.text('name')
              },
              (value) => _warehouseType = value,
            ),
            _dropdown(
              'شعبه',
              _branch,
              widget.workspace.branches,
              (value) => _branch = value,
            ),
            _dropdown(
              'حساب موجودی',
              _account,
              {for (final value in widget.workspace.accounts) value: value},
              (value) => _account = value,
            ),
            _check('انبار گروهی است', _isGroup, (value) => _isGroup = value),
            _check('غیرفعال', _disabled, (value) => _disabled = value),
          ],
        'Warehouse Type' => [
            _text('عنوان نوع انبار *', _label,
                readOnly: initial.name.isNotEmpty),
            _text('توضیحات', _description, maxLines: 3, wide: true),
          ],
        'Item Group' => [
            _text('عنوان گروه کالا *', _label,
                readOnly: initial.name.isNotEmpty),
            _dropdown(
              'گروه والد',
              _parent,
              {
                for (final row in widget.workspace.itemGroups
                    .where((row) => row.text('name') != initial.name))
                  row.text('name'): row.text('item_group_name'),
              },
              (value) => _parent = value,
            ),
            _check('دارای زیرگروه است', _isGroup, (value) => _isGroup = value),
          ],
        'UOM' => [
            _text('نام واحد اندازه‌گیری *', _label,
                readOnly: initial.name.isNotEmpty),
            _check('فعال', _enabled, (value) => _enabled = value),
            _check('فقط عدد صحیح مجاز است', _wholeNumber,
                (value) => _wholeNumber = value),
          ],
        'UOM Category' => [
            _text('عنوان دسته واحد *', _label,
                readOnly: initial.name.isNotEmpty),
          ],
        _ => [
            _dropdown(
              'دسته واحد *',
              _category,
              {
                for (final row in widget.workspace.uomCategories)
                  row.text('name'): row.text('category_name')
              },
              (value) => _category = value,
              isRequired: true,
            ),
            _dropdown(
              'واحد مبدأ *',
              _fromUom,
              {
                for (final row in widget.workspace.uoms)
                  row.text('name'): row.text('uom_name')
              },
              (value) => _fromUom = value,
              isRequired: true,
            ),
            _dropdown(
              'واحد مقصد *',
              _toUom,
              {
                for (final row in widget.workspace.uoms)
                  row.text('name'): row.text('uom_name')
              },
              (value) => _toUom = value,
              isRequired: true,
            ),
            _text(
              'ضریب تبدیل *',
              _value,
              validator: (value) {
                final number = double.tryParse(value ?? '');
                return number == null || number <= 0
                    ? 'عدد مثبت وارد کنید.'
                    : null;
              },
            ),
          ],
      };

  Widget _text(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    bool wide = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      SizedBox(
        width: wide ? 694 : 340,
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: _decoration(label),
          validator: validator ??
              (label.contains('*')
                  ? (value) => value == null || value.trim().isEmpty
                      ? 'این فیلد الزامی است.'
                      : null
                  : null),
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> changed, {
    bool isRequired = false,
  }) =>
      SizedBox(
        width: 340,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          value: value.isNotEmpty && options.containsKey(value) ? value : '',
          decoration: _decoration(label),
          items: [
            const DropdownMenuItem(value: '', child: Text('انتخاب نشده')),
            ...options.entries.map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                )),
          ],
          validator: isRequired
              ? (value) =>
                  value == null || value.isEmpty ? 'این فیلد الزامی است.' : null
              : null,
          onChanged: (value) => changed(value ?? ''),
        ),
      );

  Widget _check(String label, bool value, ValueChanged<bool> changed) =>
      SizedBox(
        width: 340,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          title: Text(label),
          onChanged: (next) => setState(() => changed(next ?? false)),
        ),
      );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (initial.settingType == 'UOM Conversion Factor' && _fromUom == _toUom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('واحد مبدأ و مقصد باید متفاوت باشند.')),
      );
      return;
    }
    Navigator.pop(
      context,
      InventorySettingDraft(
        settingType: initial.settingType,
        name: initial.name,
        label: _label.text.trim(),
        description: _description.text.trim(),
        parent: _parent,
        warehouseType: _warehouseType,
        branch: _branch,
        account: _account,
        category: _category,
        fromUom: _fromUom,
        toUom: _toUom,
        value: double.tryParse(_value.text.trim()) ?? 0,
        isGroup: _isGroup,
        disabled: _disabled,
        enabled: _enabled,
        wholeNumber: _wholeNumber,
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  String _title(String type) => switch (type) {
        'Warehouse' => 'انبار',
        'Warehouse Type' => 'نوع انبار',
        'Item Group' => 'گروه یا نوع کالا',
        'UOM' => 'واحد اندازه‌گیری',
        'UOM Category' => 'دسته واحد اندازه‌گیری',
        _ => 'ضریب تبدیل واحد',
      };
}
