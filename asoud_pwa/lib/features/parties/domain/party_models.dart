import 'package:equatable/equatable.dart';

const partyRoles = <String, String>{
  'Customer': 'مشتری',
  'Supplier': 'تأمین‌کننده',
  'Employee': 'پرسنل',
  'Salesperson': 'فروشنده',
  'Marketer': 'بازاریاب',
  'Cash Custodian': 'صندوقدار',
};

class PartyRoleInfo extends Equatable {
  const PartyRoleInfo({
    required this.role,
    required this.code,
    this.referenceType,
    this.referenceName,
    this.enabled = true,
  });

  factory PartyRoleInfo.fromJson(Map<String, dynamic> json) => PartyRoleInfo(
        role: json['role']?.toString() ?? '',
        code: json['role_code']?.toString() ?? '',
        referenceType: json['reference_doctype']?.toString(),
        referenceName: json['reference_name']?.toString(),
        enabled: json['enabled'] != 0 && json['enabled'] != false,
      );

  final String role;
  final String code;
  final String? referenceType;
  final String? referenceName;
  final bool enabled;

  @override
  List<Object?> get props =>
      [role, code, referenceType, referenceName, enabled];
}

class PartySummary extends Equatable {
  const PartySummary({
    required this.name,
    required this.displayName,
    required this.personType,
    required this.roles,
    this.nationalId = '',
    this.mobile = '',
    this.email = '',
    this.enabled = true,
  });

  factory PartySummary.fromJson(Map<String, dynamic> json) => PartySummary(
        name: json['name']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
        personType: json['person_type']?.toString() ?? 'Natural',
        nationalId: json['national_id']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        enabled: json['enabled'] != 0 && json['enabled'] != false,
        roles: ((json['roles'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PartyRoleInfo.fromJson)
            .toList(growable: false),
      );

  final String name;
  final String displayName;
  final String personType;
  final String nationalId;
  final String mobile;
  final String email;
  final bool enabled;
  final List<PartyRoleInfo> roles;

  @override
  List<Object?> get props => [
        name,
        displayName,
        personType,
        nationalId,
        mobile,
        email,
        enabled,
        roles,
      ];
}

class PartySnapshot extends Equatable {
  const PartySnapshot({
    this.items = const [],
    this.nextCodes = const {},
    this.policyOptions = const PartyPolicyOptions(),
  });

  factory PartySnapshot.fromJson(Map<String, dynamic> json) => PartySnapshot(
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PartySummary.fromJson)
            .toList(growable: false),
        nextCodes: ((json['series'] as Map<String, dynamic>?) ?? const {})
            .map((key, value) => MapEntry(key, value.toString())),
        policyOptions: PartyPolicyOptions.fromJson(
          (json['policy_options'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  final List<PartySummary> items;
  final Map<String, String> nextCodes;
  final PartyPolicyOptions policyOptions;

  @override
  List<Object?> get props => [items, nextCodes, policyOptions];
}

class PartyPolicyOptions extends Equatable {
  const PartyPolicyOptions({
    this.branches = const [],
    this.paymentTerms = const [],
    this.sellingPriceLists = const [],
    this.buyingPriceLists = const [],
    this.receivableAccounts = const [],
    this.payableAccounts = const [],
  });

  factory PartyPolicyOptions.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) => ((json[key] as List<dynamic>?) ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    return PartyPolicyOptions(
      branches: list('branches'),
      paymentTerms: list('payment_terms'),
      sellingPriceLists: list('selling_price_lists'),
      buyingPriceLists: list('buying_price_lists'),
      receivableAccounts: list('receivable_accounts'),
      payableAccounts: list('payable_accounts'),
    );
  }

  final List<String> branches;
  final List<String> paymentTerms;
  final List<String> sellingPriceLists;
  final List<String> buyingPriceLists;
  final List<String> receivableAccounts;
  final List<String> payableAccounts;

  @override
  List<Object?> get props => [
        branches,
        paymentTerms,
        sellingPriceLists,
        buyingPriceLists,
        receivableAccounts,
        payableAccounts,
      ];
}

class PartyProfile extends Equatable {
  const PartyProfile({
    required this.draft,
    this.codes = const {},
    this.references = const {},
  });

  factory PartyProfile.fromJson(Map<String, dynamic> json) {
    final party = Map<String, dynamic>.from(
      (json['party'] as Map<String, dynamic>?) ?? const {},
    );
    party['company_policies'] = json['company_policies'] ?? const [];
    return PartyProfile(
      draft: PartyDraft.fromJson(party),
      codes: ((json['codes'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      references:
          ((json['references'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic> ? value : const <String, dynamic>{},
        ),
      ),
    );
  }

  final PartyDraft draft;
  final Map<String, String> codes;
  final Map<String, Map<String, dynamic>> references;

  @override
  List<Object?> get props => [draft, codes, references];
}

class OpeningBalanceDraft extends Equatable {
  const OpeningBalanceDraft({
    required this.role,
    this.balanceState = 'None',
    this.amount = 0,
    this.currency = 'IRR',
    this.account = '',
    this.offsetAccount = '',
  });

  final String role;
  final String balanceState;
  final double amount;
  final String currency;
  final String account;
  final String offsetAccount;

  OpeningBalanceDraft copyWith({
    String? balanceState,
    double? amount,
    String? currency,
    String? account,
    String? offsetAccount,
  }) =>
      OpeningBalanceDraft(
        role: role,
        balanceState: balanceState ?? this.balanceState,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        account: account ?? this.account,
        offsetAccount: offsetAccount ?? this.offsetAccount,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'balance_state': balanceState,
        'amount': amount,
        'currency': currency,
        if (account.isNotEmpty) 'account': account,
        if (offsetAccount.isNotEmpty) 'offset_account': offsetAccount,
      };

  @override
  List<Object?> get props =>
      [role, balanceState, amount, currency, account, offsetAccount];
}

class CompanyPartyPolicy extends Equatable {
  const CompanyPartyPolicy({
    required this.role,
    this.enabled = true,
    this.defaultBranch = '',
    this.creditLimit = 0,
    this.paymentTermsTemplate = '',
    this.priceList = '',
    this.defaultAccount = '',
  });

  factory CompanyPartyPolicy.fromJson(Map<String, dynamic> json) =>
      CompanyPartyPolicy(
        role: json['role']?.toString() ?? '',
        enabled: json['enabled'] != 0 && json['enabled'] != false,
        defaultBranch: json['default_branch']?.toString() ?? '',
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
        paymentTermsTemplate: json['payment_terms_template']?.toString() ?? '',
        priceList: json['price_list']?.toString() ?? '',
        defaultAccount: json['default_account']?.toString() ?? '',
      );

  final String role;
  final bool enabled;
  final String defaultBranch;
  final double creditLimit;
  final String paymentTermsTemplate;
  final String priceList;
  final String defaultAccount;

  CompanyPartyPolicy copyWith({
    bool? enabled,
    String? defaultBranch,
    double? creditLimit,
    String? paymentTermsTemplate,
    String? priceList,
    String? defaultAccount,
  }) =>
      CompanyPartyPolicy(
        role: role,
        enabled: enabled ?? this.enabled,
        defaultBranch: defaultBranch ?? this.defaultBranch,
        creditLimit: creditLimit ?? this.creditLimit,
        paymentTermsTemplate: paymentTermsTemplate ?? this.paymentTermsTemplate,
        priceList: priceList ?? this.priceList,
        defaultAccount: defaultAccount ?? this.defaultAccount,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'enabled': enabled,
        if (defaultBranch.isNotEmpty) 'default_branch': defaultBranch,
        if (role == 'Customer') 'credit_limit': creditLimit,
        if (paymentTermsTemplate.isNotEmpty)
          'payment_terms_template': paymentTermsTemplate,
        if (priceList.isNotEmpty) 'price_list': priceList,
        if (defaultAccount.isNotEmpty) 'default_account': defaultAccount,
      };

  @override
  List<Object?> get props => [
        role,
        enabled,
        defaultBranch,
        creditLimit,
        paymentTermsTemplate,
        priceList,
        defaultAccount,
      ];
}

class PartyDraft extends Equatable {
  const PartyDraft({
    this.name,
    this.personType = 'Natural',
    this.firstName = '',
    this.lastName = '',
    this.fatherName = '',
    this.birthCertificateNumber = '',
    this.birthPlace = '',
    this.companyName = '',
    this.gender = '',
    this.birthDate = '',
    this.nationalId = '',
    this.registrationNumber = '',
    this.economicCode = '',
    this.phone = '',
    this.mobile = '',
    this.email = '',
    this.website = '',
    this.province = '',
    this.city = '',
    this.addressLine = '',
    this.postalCode = '',
    this.description = '',
    this.roles = const {'Customer'},
    this.openingBalances = const {},
    this.companyPolicies = const {
      'Customer': CompanyPartyPolicy(role: 'Customer'),
    },
    this.enabled = true,
  });

  final String? name;
  final String personType;
  final String firstName;
  final String lastName;
  final String fatherName;
  final String birthCertificateNumber;
  final String birthPlace;
  final String companyName;
  final String gender;
  final String birthDate;
  final String nationalId;
  final String registrationNumber;
  final String economicCode;
  final String phone;
  final String mobile;
  final String email;
  final String website;
  final String province;
  final String city;
  final String addressLine;
  final String postalCode;
  final String description;
  final Set<String> roles;
  final Map<String, OpeningBalanceDraft> openingBalances;
  final Map<String, CompanyPartyPolicy> companyPolicies;
  final bool enabled;

  String get displayName => personType == 'Natural'
      ? '$firstName $lastName'.trim()
      : companyName.trim();

  factory PartyDraft.fromJson(Map<String, dynamic> json) {
    final roleRows = ((json['roles'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final balanceRows =
        ((json['opening_balances'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>();
    final policyRows =
        ((json['company_policies'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>();
    return PartyDraft(
      name: json['name']?.toString(),
      personType: json['person_type']?.toString() ?? 'Natural',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fatherName: json['father_name']?.toString() ?? '',
      birthCertificateNumber:
          json['birth_certificate_number']?.toString() ?? '',
      birthPlace: json['birth_place']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      birthDate: json['birth_date']?.toString() ?? '',
      nationalId: json['national_id']?.toString() ?? '',
      registrationNumber: json['registration_number']?.toString() ?? '',
      economicCode: json['economic_code']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['address_line']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      roles: roleRows.map((row) => row['role'].toString()).toSet(),
      openingBalances: {
        for (final row in balanceRows)
          row['role'].toString(): OpeningBalanceDraft(
            role: row['role'].toString(),
            balanceState: row['balance_state']?.toString() ?? 'None',
            amount: (row['amount'] as num?)?.toDouble() ?? 0,
            currency: row['currency']?.toString() ?? 'IRR',
            account: row['account']?.toString() ?? '',
            offsetAccount: row['offset_account']?.toString() ?? '',
          ),
      },
      companyPolicies: {
        for (final row in policyRows)
          row['role'].toString(): CompanyPartyPolicy.fromJson(row),
      },
      enabled: json['enabled'] != 0 && json['enabled'] != false,
    );
  }

  PartyDraft copyWith({
    String? personType,
    String? firstName,
    String? lastName,
    String? fatherName,
    String? birthCertificateNumber,
    String? birthPlace,
    String? companyName,
    String? gender,
    String? birthDate,
    String? nationalId,
    String? registrationNumber,
    String? economicCode,
    String? phone,
    String? mobile,
    String? email,
    String? website,
    String? province,
    String? city,
    String? addressLine,
    String? postalCode,
    String? description,
    Set<String>? roles,
    Map<String, OpeningBalanceDraft>? openingBalances,
    Map<String, CompanyPartyPolicy>? companyPolicies,
    bool? enabled,
  }) =>
      PartyDraft(
        name: name,
        personType: personType ?? this.personType,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        fatherName: fatherName ?? this.fatherName,
        birthCertificateNumber:
            birthCertificateNumber ?? this.birthCertificateNumber,
        birthPlace: birthPlace ?? this.birthPlace,
        companyName: companyName ?? this.companyName,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        nationalId: nationalId ?? this.nationalId,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        economicCode: economicCode ?? this.economicCode,
        phone: phone ?? this.phone,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        website: website ?? this.website,
        province: province ?? this.province,
        city: city ?? this.city,
        addressLine: addressLine ?? this.addressLine,
        postalCode: postalCode ?? this.postalCode,
        description: description ?? this.description,
        roles: roles ?? this.roles,
        openingBalances: openingBalances ?? this.openingBalances,
        companyPolicies: companyPolicies ?? this.companyPolicies,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        'person_type': personType,
        'first_name': firstName,
        'last_name': lastName,
        'father_name': fatherName,
        'birth_certificate_number': birthCertificateNumber,
        'birth_place': birthPlace,
        'company_name': companyName,
        'gender': gender,
        'birth_date': birthDate,
        'national_id': nationalId,
        'registration_number': registrationNumber,
        'economic_code': economicCode,
        'phone': phone,
        'mobile': mobile,
        'email': email,
        'website': website,
        'province': province,
        'city': city,
        'address_line': addressLine,
        'postal_code': postalCode,
        'description': description,
        'roles': roles.toList(growable: false),
        'opening_balances':
            openingBalances.values.map((row) => row.toJson()).toList(),
        'company_policies':
            companyPolicies.values.map((row) => row.toJson()).toList(),
        'enabled': enabled,
      };

  @override
  List<Object?> get props => [
        name,
        personType,
        firstName,
        lastName,
        fatherName,
        birthCertificateNumber,
        birthPlace,
        companyName,
        gender,
        birthDate,
        nationalId,
        registrationNumber,
        economicCode,
        phone,
        mobile,
        email,
        website,
        province,
        city,
        addressLine,
        postalCode,
        description,
        roles,
        openingBalances,
        companyPolicies,
        enabled,
      ];
}
