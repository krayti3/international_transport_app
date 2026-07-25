class Client {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final String? city;
  final String? nomContact;
  final String? adresseFacturation;
  final String? defaultBankAccountId;
  final String? defaultBankAccount;
  final DateTime? createdAt;

  // Identification / contact
  final String ice;
  final String email;
  final String currency;
  final bool isActive;
  final bool invoiceWithTva;
  final String? lastInvoiceNumber;

  // Shipping address + GPS
  final String shippingAddressLine1;
  final String shippingAddressLine2;
  final String shippingAddressLine3;
  final String shippingAddressLine4;
  final String shippingCity;
  final String shippingPostalCode;
  final String shippingCountry;
  final double? shippingLatitude;
  final double? shippingLongitude;

  // Billing address
  final String billingAddressLine1;
  final String billingAddressLine2;
  final String billingAddressLine3;
  final String billingAddressLine4;
  final String billingCity;
  final String billingPostalCode;
  final String billingCountry;

  const Client({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.city,
    this.nomContact,
    this.adresseFacturation,
    this.defaultBankAccountId,
    this.defaultBankAccount,
    this.createdAt,
    this.ice = '',
    this.email = '',
    this.currency = 'MAD',
    this.isActive = true,
    this.invoiceWithTva = false,
    this.lastInvoiceNumber,
    this.shippingAddressLine1 = '',
    this.shippingAddressLine2 = '',
    this.shippingAddressLine3 = '',
    this.shippingAddressLine4 = '',
    this.shippingCity = '',
    this.shippingPostalCode = '',
    this.shippingCountry = '',
    this.shippingLatitude,
    this.shippingLongitude,
    this.billingAddressLine1 = '',
    this.billingAddressLine2 = '',
    this.billingAddressLine3 = '',
    this.billingAddressLine4 = '',
    this.billingCity = '',
    this.billingPostalCode = '',
    this.billingCountry = '',
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? map['full_name']?.toString() ?? map['company_name']?.toString() ?? map['client_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      nomContact: map['nom_contact']?.toString(),
      adresseFacturation: map['adresse_facturation']?.toString(),
      defaultBankAccountId: map['default_bank_account_id']?.toString(),
      defaultBankAccount: map['default_bank_account']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      ice: map['ice']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'MAD',
      isActive: (map['is_active'] as bool?) ?? true,
      invoiceWithTva: (map['invoice_with_tva'] as bool?) ?? false,
      lastInvoiceNumber: map['last_invoice_number']?.toString(),
      shippingAddressLine1: map['shipping_address_line1']?.toString() ?? '',
      shippingAddressLine2: map['shipping_address_line2']?.toString() ?? '',
      shippingAddressLine3: map['shipping_address_line3']?.toString() ?? '',
      shippingAddressLine4: map['shipping_address_line4']?.toString() ?? '',
      shippingCity: map['shipping_city']?.toString() ?? '',
      shippingPostalCode: map['shipping_postal_code']?.toString() ?? '',
      shippingCountry: map['shipping_country']?.toString() ?? '',
      shippingLatitude: (map['shipping_latitude'] as num?)?.toDouble(),
      shippingLongitude: (map['shipping_longitude'] as num?)?.toDouble(),
      billingAddressLine1: map['billing_address_line1']?.toString() ?? '',
      billingAddressLine2: map['billing_address_line2']?.toString() ?? '',
      billingAddressLine3: map['billing_address_line3']?.toString() ?? '',
      billingAddressLine4: map['billing_address_line4']?.toString() ?? '',
      billingCity: map['billing_city']?.toString() ?? '',
      billingPostalCode: map['billing_postal_code']?.toString() ?? '',
      billingCountry: map['billing_country']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      if (nomContact != null) 'nom_contact': nomContact,
      if (adresseFacturation != null) 'adresse_facturation': adresseFacturation,
      if (defaultBankAccountId != null) 'default_bank_account_id': defaultBankAccountId,
      if (defaultBankAccount != null) 'default_bank_account': defaultBankAccount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'ice': ice,
      'email': email,
      'currency': currency,
      'is_active': isActive,
      'invoice_with_tva': invoiceWithTva,
      if (lastInvoiceNumber != null) 'last_invoice_number': lastInvoiceNumber,
      'shipping_address_line1': shippingAddressLine1,
      'shipping_address_line2': shippingAddressLine2,
      'shipping_address_line3': shippingAddressLine3,
      'shipping_address_line4': shippingAddressLine4,
      'shipping_city': shippingCity,
      'shipping_postal_code': shippingPostalCode,
      'shipping_country': shippingCountry,
      if (shippingLatitude != null) 'shipping_latitude': shippingLatitude,
      if (shippingLongitude != null) 'shipping_longitude': shippingLongitude,
      'billing_address_line1': billingAddressLine1,
      'billing_address_line2': billingAddressLine2,
      'billing_address_line3': billingAddressLine3,
      'billing_address_line4': billingAddressLine4,
      'billing_city': billingCity,
      'billing_postal_code': billingPostalCode,
      'billing_country': billingCountry,
    };
  }

  Client copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? city,
    String? nomContact,
    String? adresseFacturation,
    String? defaultBankAccountId,
    String? defaultBankAccount,
    DateTime? createdAt,
    String? ice,
    String? email,
    String? currency,
    bool? isActive,
    bool? invoiceWithTva,
    String? lastInvoiceNumber,
    String? shippingAddressLine1,
    String? shippingAddressLine2,
    String? shippingAddressLine3,
    String? shippingAddressLine4,
    String? shippingCity,
    String? shippingPostalCode,
    String? shippingCountry,
    double? shippingLatitude,
    double? shippingLongitude,
    String? billingAddressLine1,
    String? billingAddressLine2,
    String? billingAddressLine3,
    String? billingAddressLine4,
    String? billingCity,
    String? billingPostalCode,
    String? billingCountry,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      nomContact: nomContact ?? this.nomContact,
      adresseFacturation: adresseFacturation ?? this.adresseFacturation,
      defaultBankAccountId: defaultBankAccountId ?? this.defaultBankAccountId,
      defaultBankAccount: defaultBankAccount ?? this.defaultBankAccount,
      createdAt: createdAt ?? this.createdAt,
      ice: ice ?? this.ice,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      invoiceWithTva: invoiceWithTva ?? this.invoiceWithTva,
      lastInvoiceNumber: lastInvoiceNumber ?? this.lastInvoiceNumber,
      shippingAddressLine1: shippingAddressLine1 ?? this.shippingAddressLine1,
      shippingAddressLine2: shippingAddressLine2 ?? this.shippingAddressLine2,
      shippingAddressLine3: shippingAddressLine3 ?? this.shippingAddressLine3,
      shippingAddressLine4: shippingAddressLine4 ?? this.shippingAddressLine4,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingPostalCode: shippingPostalCode ?? this.shippingPostalCode,
      shippingCountry: shippingCountry ?? this.shippingCountry,
      shippingLatitude: shippingLatitude ?? this.shippingLatitude,
      shippingLongitude: shippingLongitude ?? this.shippingLongitude,
      billingAddressLine1: billingAddressLine1 ?? this.billingAddressLine1,
      billingAddressLine2: billingAddressLine2 ?? this.billingAddressLine2,
      billingAddressLine3: billingAddressLine3 ?? this.billingAddressLine3,
      billingAddressLine4: billingAddressLine4 ?? this.billingAddressLine4,
      billingCity: billingCity ?? this.billingCity,
      billingPostalCode: billingPostalCode ?? this.billingPostalCode,
      billingCountry: billingCountry ?? this.billingCountry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Client && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Client(id: $id, name: $name, phone: $phone, city: $city)';
}
