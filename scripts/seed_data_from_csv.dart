import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/services/advance_service.dart';
import 'package:international_transport_app/services/client_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';
import 'package:international_transport_app/services/reference_service.dart';
import 'csv_reader.dart';

// ignore_for_file: avoid_print

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final verbose = args.contains('--verbose');

  if (dryRun) {
    print('=== DRY RUN MODE - No data will be inserted ===\n');
  }

  final referenceService = ReferenceService();
  final clientService = ClientService();
  final fleetService = FleetService();
  final advanceService = AdvanceService();

  print('Starting CSV data seeding...\n');

  await _seedCategories(referenceService, dryRun, verbose);
  await _seedClients(clientService, dryRun, verbose);
  await _seedDrivers(fleetService, dryRun, verbose);
  await _seedTrucks(fleetService, dryRun, verbose);
  await _seedTrailers(fleetService, dryRun, verbose);
  await _seedProducts(advanceService, dryRun, verbose);
  await _seedTripOrders(advanceService, dryRun, verbose);
  await _seedTripOrderItems(advanceService, dryRun, verbose);

  print('\n=== Seeding completed ===');
}

Future<void> _seedCategories(ReferenceService service, bool dryRun, bool verbose) async {
  print('Seeding document categories...');
  try {
    final rows = await readCsvFromDirectory('T09  categories.csv');
    int inserted = 0;
    for (final row in rows) {
      final name = row.get('categorie')?.trim();
      if (name == null || name.isEmpty) continue;
      
      if (verbose) print('  Category: $name');
      if (!dryRun) {
        await service.addDocumentCategory({'name': name});
      }
      inserted++;
    }
    print('  Inserted $inserted categories\n');
  } catch (e) {
    print('  Error seeding categories: $e\n');
  }
}

Future<void> _seedClients(ClientService service, bool dryRun, bool verbose) async {
  print('Seeding clients...');
  try {
    final rows = await readCsvFromDirectory('Clientèle.csv');
    int inserted = 0;
    for (final row in rows) {
      final name = row.get('NomSociété')?.trim();
      if (name == null || name.isEmpty) continue;

      final newClient = Client(
        name: name,
        phone: row.getOrEmpty('NuméroTél'),
        address: row.getOrEmpty('AdresseFacturation'),
        city: row.getOrEmpty('Ville'),
        nomContact: row.get('NomContact'),
        adresseFacturation: row.getOrEmpty('AdresseFacturation'),
      );

      if (verbose) print('  Client: $name');
      if (!dryRun) {
        await service.addClient(newClient);
      }
      inserted++;
    }
    print('  Inserted $inserted clients\n');
  } catch (e) {
    print('  Error seeding clients: $e\n');
  }
}

Future<void> _seedDrivers(FleetService service, bool dryRun, bool verbose) async {
  print('Seeding drivers...');
  try {
    final rows = await readCsvFromDirectory('Employés.csv');
    int inserted = 0;
    for (final row in rows) {
      final firstName = row.getOrEmpty('Prénom');
      final lastName = row.getOrEmpty('NomFamille');
      final name = '$firstName $lastName'.trim();
      if (name.isEmpty) continue;

      final data = <String, dynamic>{
        'name': name,
        'phone': row.getOrEmpty('TéléProfessionnel'),
        'license': row.getOrEmpty('Poste'),
        'status': 'active',
        'base_salary': 0.0,
        'bonus_percentage': 0.0,
      };

      if (verbose) print('  Driver: $name');
      if (!dryRun) {
        await service.addDriver(data);
      }
      inserted++;
    }
    print('  Inserted $inserted drivers\n');
  } catch (e) {
    print('  Error seeding drivers: $e\n');
  }
}

Future<void> _seedTrucks(FleetService service, bool dryRun, bool verbose) async {
  print('Seeding trucks...');
  try {
    final rows = await readCsvFromDirectory('T00vehicules.csv');
    int inserted = 0;
    for (final row in rows) {
      final plate = row.get('vehicules')?.trim();
      if (plate == null || plate.isEmpty) continue;

      final data = <String, dynamic>{
        'plate': plate,
        'model': row.getOrEmpty('Marque'),
        'status': row.getBool('Susp') == true ? 'inactive' : 'active',
      };

      if (verbose) print('  Truck: $plate');
      if (!dryRun) {
        await service.addTruck(data);
      }
      inserted++;
    }
    print('  Inserted $inserted trucks\n');
  } catch (e) {
    print('  Error seeding trucks: $e\n');
  }
}

Future<void> _seedTrailers(FleetService service, bool dryRun, bool verbose) async {
  print('Seeding trailers...');
  try {
    final rows = await readCsvFromDirectory('T00frigo.csv');
    int inserted = 0;
    for (final row in rows) {
      final plate = row.get('frigo')?.trim();
      if (plate == null || plate.isEmpty) continue;

      final data = <String, dynamic>{
        'plate_number': plate,
        'type': 'Frigo',
      };

      if (verbose) print('  Trailer: $plate');
      if (!dryRun) {
        await service.addTrailer(data);
      }
      inserted++;
    }
    print('  Inserted $inserted trailers\n');
  } catch (e) {
    print('  Error seeding trailers: $e\n');
  }
}

Future<void> _seedProducts(AdvanceService service, bool dryRun, bool verbose) async {
  print('Seeding products (trip routes)...');
  try {
    final rows = await readCsvFromDirectory('Produits.csv');
    int inserted = 0;
    for (final row in rows) {
      final name = row.get('NomProduit')?.trim();
      if (name == null || name.isEmpty) continue;

      final data = <String, dynamic>{
        'name': name,
        'price': row.getDouble('PrixUnitaire') ?? 0.0,
        'is_international': row.getBool('international') ?? false,
      };

      if (verbose) print('  Product: $name');
      if (!dryRun) {
        await service.addProduct(data);
      }
      inserted++;
    }
    print('  Inserted $inserted products\n');
  } catch (e) {
    print('  Error seeding products: $e\n');
  }
}

Future<void> _seedTripOrders(AdvanceService service, bool dryRun, bool verbose) async {
  print('Seeding trip orders...');
  try {
    final rows = await readCsvFromDirectory('Commandes.csv');
    int inserted = 0;
    for (final row in rows) {
      final clientId = row.getInt('RéfClient');
      final driverId = row.getInt('RéfEmployé');
      if (clientId == null || driverId == null) continue;

      final data = <String, dynamic>{
        'client_id': clientId,
        'driver_id': driverId,
        'order_number': row.getOrEmpty('NuméroBonCommande'),
        'issue_date': row.getDate('DateCommande')?.toIso8601String().split('T').first,
        'due_date': row.getDate('DateExpédition')?.toIso8601String().split('T').first,
        'status': row.getBool('Valider') == true ? 'confirmed' : 'pending',
        'total_amount': row.getDouble('MontantPaiement') ?? 0.0,
      };

      if (verbose) print('  Order: ${data['order_number']}');
      if (!dryRun) {
        await service.addTripOrder(data);
      }
      inserted++;
    }
    print('  Inserted $inserted trip orders\n');
  } catch (e) {
    print('  Error seeding trip orders: $e\n');
  }
}

Future<void> _seedTripOrderItems(AdvanceService service, bool dryRun, bool verbose) async {
  print('Seeding trip order items...');
  try {
    final rows = await readCsvFromDirectory('Détails commande.csv');
    int inserted = 0;
    for (final row in rows) {
      final tripOrderId = row.getInt('RéfCommande');
      final productId = row.getInt('RéfProduit');
      if (tripOrderId == null || productId == null) continue;

      final data = <String, dynamic>{
        'trip_order_id': tripOrderId,
        'product_id': productId,
        'quantity': row.getInt('Quantité') ?? 1,
        'unit_price': row.getDouble('PrixUnitaire') ?? 0.0,
      };

      if (!dryRun) {
        await service.addTripOrderItem(data);
      }
      inserted++;
    }
    print('  Inserted $inserted trip order items\n');
  } catch (e) {
    print('  Error seeding trip order items: $e\n');
  }
}
