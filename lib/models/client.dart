class Client {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String? nomContact;
  final String? adresseFacturation;
  final String? defaultBankAccountId;
  final DateTime? createdAt;

  const Client({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    this.nomContact,
    this.adresseFacturation,
    this.defaultBankAccountId,
    this.createdAt,
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
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
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
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
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
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
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
