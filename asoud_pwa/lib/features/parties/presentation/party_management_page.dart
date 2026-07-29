import 'dart:async';

import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_models.dart';
import 'package:asoud_pwa/features/parties/presentation/bloc/party_management_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PartyManagementPage extends StatelessWidget {
  const PartyManagementPage({
    required this.context,
    required this.gateway,
    this.initialRole,
    super.key,
  });

  final WorkContext context;
  final PartyGateway gateway;
  final String? initialRole;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PartyManagementCubit(gateway, this.context)..load(),
        child: _PartyManagementView(initialRole: initialRole),
      );
}

class _PartyManagementView extends StatefulWidget {
  const _PartyManagementView({this.initialRole});

  final String? initialRole;

  @override
  State<_PartyManagementView> createState() => _PartyManagementViewState();
}

class _PartyManagementViewState extends State<_PartyManagementView> {
  late String? roleFilter = widget.initialRole;
  Timer? searchDebounce;

  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PartyManagementCubit, PartyManagementState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        ),
        builder: (context, state) {
          if (state.phase == PartyPhase.loading &&
              state.snapshot.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.draft != null) return _form(context, state);
          if (state.profile != null) return _profile(context, state.profile!);
          return _directory(context, state);
        },
      );

  Widget _directory(BuildContext context, PartyManagementState state) {
    final items = state.snapshot.items
        .where(
          (item) =>
              roleFilter == null ||
              item.roles.any((role) => role.role == roleFilter),
        )
        .toList(growable: false);
    return ColoredBox(
      color: AsoudColors.canvas,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(
              title: 'مدیریت اشخاص',
              subtitle:
                  'هویت مشترک اشخاص حقیقی و حقوقی و نقش‌های وابسته به شرکت فعال',
              action: FilledButton.icon(
                onPressed: () => context.read<PartyManagementCubit>().create(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('ایجاد شخص'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        onChanged: (value) {
                          searchDebounce?.cancel();
                          searchDebounce = Timer(
                            const Duration(milliseconds: 350),
                            () => context
                                .read<PartyManagementCubit>()
                                .load(search: value),
                          );
                        },
                        decoration: const InputDecoration(
                          hintText: 'جست‌وجو در نام، شناسه ملی یا تلفن همراه',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    _FilterChip(
                      label: 'همه',
                      selected: roleFilter == null,
                      onSelected: () => setState(() => roleFilter = null),
                    ),
                    for (final role in const [
                      'Customer',
                      'Supplier',
                      'Employee',
                      'Salesperson',
                      'Marketer',
                      'Cash Custodian',
                    ])
                      _FilterChip(
                        label: partyRoles[role]!,
                        selected: roleFilter == role,
                        onSelected: () => setState(() => roleFilter = role),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Card(
                child: items.isEmpty
                    ? const _EmptyDirectory()
                    : SingleChildScrollView(
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xfff7f9fc),
                          ),
                          columns: const [
                            DataColumn(label: Text('شخص')),
                            DataColumn(label: Text('نوع')),
                            DataColumn(label: Text('نقش‌ها و کدها')),
                            DataColumn(label: Text('اطلاعات تماس')),
                            DataColumn(label: Text('وضعیت')),
                          ],
                          rows: [
                            for (final item in items)
                              DataRow(
                                onSelectChanged: (_) => context
                                    .read<PartyManagementCubit>()
                                    .openProfile(item.name),
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              const Color(0xffedf3ff),
                                          child: Icon(
                                            item.personType == 'Natural'
                                                ? Icons.person_outline
                                                : Icons.apartment_outlined,
                                            color: AsoudColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (item.nationalId.isNotEmpty)
                                              Text(
                                                item.nationalId,
                                                style: const TextStyle(
                                                  color: AsoudColors.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.personType == 'Natural'
                                          ? 'شخص حقیقی'
                                          : 'شخص حقوقی',
                                    ),
                                  ),
                                  DataCell(
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final role in item.roles)
                                          _RoleBadge(
                                            label:
                                                '${partyRoles[role.role] ?? role.role}  ${role.code}',
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.mobile.isEmpty
                                            ? '—'
                                            : item.mobile),
                                        if (item.email.isNotEmpty)
                                          Text(
                                            item.email,
                                            style: const TextStyle(
                                              color: AsoudColors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    _StatusPill(enabled: item.enabled),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, PartyManagementState state) {
    final cubit = context.read<PartyManagementCubit>();
    final draft = state.draft!;
    return ColoredBox(
      color: AsoudColors.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _PageHeader(
              title: draft.name == null ? 'ایجاد شخص' : 'ویرایش شخص',
              subtitle:
                  'کدهای نقش پس از ثبت قطعی می‌شوند و در سطح شرکت یکتا هستند.',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed:
                        state.phase == PartyPhase.saving ? null : cubit.cancel,
                    child: const Text('انصراف'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        state.phase == PartyPhase.saving ? null : cubit.save,
                    icon: state.phase == PartyPhase.saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('ثبت شخص'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 980;
                      final right = Column(
                        children: [
                          _SectionCard(
                            title: 'نوع و نقش‌های شخص',
                            icon: Icons.badge_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'Natural',
                                      label: Text('شخص حقیقی'),
                                      icon: Icon(Icons.person_outline),
                                    ),
                                    ButtonSegment(
                                      value: 'Legal',
                                      label: Text('شخص حقوقی'),
                                      icon: Icon(Icons.apartment_outlined),
                                    ),
                                  ],
                                  selected: {draft.personType},
                                  onSelectionChanged: (value) => cubit.update(
                                    draft.copyWith(personType: value.first),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'نقش در شرکت فعال',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in partyRoles.entries)
                                      FilterChip(
                                        selected:
                                            draft.roles.contains(entry.key),
                                        onSelected: (_) =>
                                            cubit.toggleRole(entry.key),
                                        avatar: Icon(
                                          _roleIcon(entry.key),
                                          size: 17,
                                        ),
                                        label: Text(entry.value),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final role in draft.roles)
                                      _CodePreview(
                                        role: role,
                                        code: state.codePreview[role] ?? '...',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'اطلاعات پایه',
                            icon: Icons.article_outlined,
                            child: draft.personType == 'Natural'
                                ? _NaturalFields(
                                    draft: draft, update: cubit.update)
                                : _LegalFields(
                                    draft: draft, update: cubit.update),
                          ),
                          if (draft.roles.contains('Employee')) ...[
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'اطلاعات پرسنلی الزامی',
                              icon: Icons.work_outline,
                              child: _EmployeeFields(
                                draft: draft,
                                update: cubit.update,
                              ),
                            ),
                          ],
                        ],
                      );
                      final left = Column(
                        children: [
                          _SectionCard(
                            title: 'راه‌های ارتباطی',
                            icon: Icons.contact_phone_outlined,
                            child: _ContactFields(
                              draft: draft,
                              update: cubit.update,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'نشانی و موقعیت',
                            icon: Icons.location_on_outlined,
                            child: _AddressFields(
                              draft: draft,
                              update: cubit.update,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'مانده‌های افتتاحیه',
                            icon: Icons.account_balance_wallet_outlined,
                            child: _OpeningBalances(
                              draft: draft,
                              update: cubit.updateOpening,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'توضیحات و وضعیت',
                            icon: Icons.notes_outlined,
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: draft.description,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'توضیحات',
                                  ),
                                  onChanged: (value) => cubit.update(
                                    draft.copyWith(description: value),
                                  ),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('فعال'),
                                  subtitle: const Text(
                                    'غیرفعال‌سازی فقط در شرکت فعال اعمال می‌شود.',
                                  ),
                                  value: draft.enabled,
                                  onChanged: (value) => cubit.update(
                                    draft.copyWith(enabled: value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      if (!twoColumns) {
                        return Column(children: [
                          right,
                          const SizedBox(height: 12),
                          left
                        ]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: right),
                          const SizedBox(width: 12),
                          Expanded(child: left),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profile(BuildContext context, PartyProfile profile) {
    final draft = profile.draft;
    final cubit = context.read<PartyManagementCubit>();
    return ColoredBox(
      color: AsoudColors.canvas,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(
              title: draft.displayName,
              subtitle: draft.personType == 'Natural'
                  ? 'پروفایل شخص حقیقی'
                  : 'پروفایل شخص حقوقی',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: cubit.closeProfile,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('بازگشت'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: cubit.editProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('ویرایش'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'نقش‌ها و کدهای قطعی',
                                icon: Icons.badge_outlined,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in profile.codes.entries)
                                      _CodePreview(
                                        role: entry.key,
                                        code: entry.value,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'اطلاعات هویتی',
                                icon: Icons.article_outlined,
                                child: _ProfileRows(
                                  rows: [
                                    (
                                      'نوع شخص',
                                      draft.personType == 'Natural'
                                          ? 'حقیقی'
                                          : 'حقوقی'
                                    ),
                                    ('نام', draft.displayName),
                                    if (draft.nationalId.isNotEmpty)
                                      ('شناسه/کد ملی', draft.nationalId),
                                    if (draft.fatherName.isNotEmpty)
                                      ('نام پدر', draft.fatherName),
                                    if (draft.birthCertificateNumber.isNotEmpty)
                                      (
                                        'شماره شناسنامه',
                                        draft.birthCertificateNumber,
                                      ),
                                    if (draft.birthDate.isNotEmpty)
                                      ('تاریخ تولد', draft.birthDate),
                                    if (draft.registrationNumber.isNotEmpty)
                                      ('شماره ثبت', draft.registrationNumber),
                                    if (draft.economicCode.isNotEmpty)
                                      ('کد اقتصادی', draft.economicCode),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'راه‌های ارتباطی',
                                icon: Icons.contact_phone_outlined,
                                child: _ProfileRows(
                                  rows: [
                                    ('تلفن', draft.phone),
                                    ('تلفن همراه', draft.mobile),
                                    ('ایمیل', draft.email),
                                    ('وب‌سایت', draft.website),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'نشانی و وضعیت',
                                icon: Icons.location_on_outlined,
                                child: _ProfileRows(
                                  rows: [
                                    ('استان', draft.province),
                                    ('شهر', draft.city),
                                    ('نشانی', draft.addressLine),
                                    ('کد پستی', draft.postalCode),
                                    (
                                      'وضعیت',
                                      draft.enabled ? 'فعال' : 'غیرفعال',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AsoudColors.muted),
                ),
              ],
            ),
          ),
          action,
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AsoudColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Divider(height: 24),
              child,
            ],
          ),
        ),
      );
}

class _NaturalFields extends StatelessWidget {
  const _NaturalFields({required this.draft, required this.update});

  final PartyDraft draft;
  final ValueChanged<PartyDraft> update;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'نام *',
                  value: draft.firstName,
                  changed: (value) => update(draft.copyWith(firstName: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'نام خانوادگی *',
                  value: draft.lastName,
                  changed: (value) => update(draft.copyWith(lastName: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'کد ملی',
            value: draft.nationalId,
            changed: (value) => update(draft.copyWith(nationalId: value)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'نام پدر',
                  value: draft.fatherName,
                  changed: (value) => update(draft.copyWith(fatherName: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'شماره شناسنامه',
                  value: draft.birthCertificateNumber,
                  changed: (value) => update(
                    draft.copyWith(birthCertificateNumber: value),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'محل صدور شناسنامه',
            value: draft.birthPlace,
            changed: (value) => update(draft.copyWith(birthPlace: value)),
          ),
        ],
      );
}

class _LegalFields extends StatelessWidget {
  const _LegalFields({required this.draft, required this.update});

  final PartyDraft draft;
  final ValueChanged<PartyDraft> update;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _Field(
            label: 'نام شخص حقوقی *',
            value: draft.companyName,
            changed: (value) => update(draft.copyWith(companyName: value)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'شناسه ملی',
                  value: draft.nationalId,
                  changed: (value) => update(draft.copyWith(nationalId: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'شماره ثبت',
                  value: draft.registrationNumber,
                  changed: (value) =>
                      update(draft.copyWith(registrationNumber: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'کد اقتصادی',
            value: draft.economicCode,
            changed: (value) => update(draft.copyWith(economicCode: value)),
          ),
        ],
      );
}

class _EmployeeFields extends StatelessWidget {
  const _EmployeeFields({required this.draft, required this.update});

  final PartyDraft draft;
  final ValueChanged<PartyDraft> update;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: draft.gender.isEmpty ? null : draft.gender,
              decoration: const InputDecoration(labelText: 'جنسیت *'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('مرد')),
                DropdownMenuItem(value: 'Female', child: Text('زن')),
              ],
              onChanged: (value) => update(draft.copyWith(gender: value ?? '')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Field(
              label: 'تاریخ تولد *',
              hint: 'YYYY-MM-DD',
              value: draft.birthDate,
              changed: (value) => update(draft.copyWith(birthDate: value)),
            ),
          ),
        ],
      );
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({required this.draft, required this.update});

  final PartyDraft draft;
  final ValueChanged<PartyDraft> update;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'تلفن',
                  value: draft.phone,
                  changed: (value) => update(draft.copyWith(phone: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'تلفن همراه',
                  value: draft.mobile,
                  changed: (value) => update(draft.copyWith(mobile: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'ایمیل',
            value: draft.email,
            changed: (value) => update(draft.copyWith(email: value)),
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'وب‌سایت',
            value: draft.website,
            changed: (value) => update(draft.copyWith(website: value)),
          ),
        ],
      );
}

class _AddressFields extends StatelessWidget {
  const _AddressFields({required this.draft, required this.update});

  final PartyDraft draft;
  final ValueChanged<PartyDraft> update;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'استان',
                  value: draft.province,
                  changed: (value) => update(draft.copyWith(province: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'شهر',
                  value: draft.city,
                  changed: (value) => update(draft.copyWith(city: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'نشانی کامل',
            value: draft.addressLine,
            changed: (value) => update(draft.copyWith(addressLine: value)),
          ),
          const SizedBox(height: 10),
          _Field(
            label: 'کد پستی',
            value: draft.postalCode,
            changed: (value) => update(draft.copyWith(postalCode: value)),
          ),
          const SizedBox(height: 10),
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xffedf3ff),
              border: Border.all(color: AsoudColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_location_alt_outlined,
                      color: AsoudColors.primary),
                  SizedBox(width: 8),
                  Text('ثبت موقعیت روی نقشه'),
                ],
              ),
            ),
          ),
        ],
      );
}

class _OpeningBalances extends StatelessWidget {
  const _OpeningBalances({required this.draft, required this.update});

  final PartyDraft draft;
  final void Function(String, {String? stateValue, double? amount}) update;

  @override
  Widget build(BuildContext context) {
    final roles = draft.roles
        .where((role) => role == 'Customer' || role == 'Supplier')
        .toList(growable: false);
    if (roles.isEmpty) {
      return const Text(
        'مانده افتتاحیه برای نقش مشتری یا تأمین‌کننده قابل تعریف است.',
        style: TextStyle(color: AsoudColors.muted),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xfffff8e8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AsoudColors.warning, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مانده‌ها به‌صورت پیش‌نویس ذخیره و در فرایند افتتاحیه کنترل و ثبت می‌شوند.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final role in roles) ...[
          _OpeningBalanceRow(
            role: role,
            value:
                draft.openingBalances[role] ?? OpeningBalanceDraft(role: role),
            update: update,
          ),
          if (role != roles.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OpeningBalanceRow extends StatelessWidget {
  const _OpeningBalanceRow({
    required this.role,
    required this.value,
    required this.update,
  });

  final String role;
  final OpeningBalanceDraft value;
  final void Function(String, {String? stateValue, double? amount}) update;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مانده ${partyRoles[role]}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'None', label: Text('بدون مانده')),
                ButtonSegment(value: 'Debit', label: Text('بدهکار')),
                ButtonSegment(value: 'Credit', label: Text('بستانکار')),
              ],
              selected: {value.balanceState},
              onSelectionChanged: (selected) =>
                  update(role, stateValue: selected.first),
            ),
            if (value.balanceState != 'None') ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: value.amount == 0 ? '' : '${value.amount}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مبلغ',
                  suffixText: 'ریال',
                ),
                onChanged: (amount) =>
                    update(role, amount: double.tryParse(amount) ?? 0),
              ),
            ],
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.changed,
    this.hint,
  });

  final String label;
  final String value;
  final ValueChanged<String> changed;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value,
        onChanged: changed,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.role, required this.code});

  final String role;
  final String code;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xffedf3ff),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffcbdcff)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              partyRoles[role] ?? role,
              style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
            ),
            const SizedBox(width: 8),
            Text(
              code,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AsoudColors.primary,
              ),
            ),
          ],
        ),
      );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xffedf3ff),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AsoudColors.primary),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xffe8f8f0) : const Color(0xffffeeee),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          enabled ? 'فعال' : 'غیرفعال',
          style: TextStyle(
            color: enabled ? AsoudColors.success : AsoudColors.danger,
            fontSize: 11,
          ),
        ),
      );
}

class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 52, color: AsoudColors.muted),
            SizedBox(height: 10),
            Text(
              'شخصی با این فیلتر یافت نشد.',
              style: TextStyle(color: AsoudColors.muted),
            ),
          ],
        ),
      );
}

class _ProfileRows extends StatelessWidget {
  const _ProfileRows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      rows[index].$1,
                      style: const TextStyle(color: AsoudColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[index].$2.isEmpty ? '—' : rows[index].$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (index != rows.length - 1) const Divider(height: 1),
          ],
        ],
      );
}

IconData _roleIcon(String role) => switch (role) {
      'Customer' => Icons.person_outline,
      'Supplier' => Icons.inventory_2_outlined,
      'Employee' => Icons.badge_outlined,
      'Salesperson' => Icons.point_of_sale_outlined,
      'Marketer' => Icons.campaign_outlined,
      'Cash Custodian' => Icons.account_balance_wallet_outlined,
      _ => Icons.label_outline,
    };
