# CSV Data Seeding Script

This script reads CSV files from the `csv/` folder and inserts the data into Supabase.

## Prerequisites

1. Make sure you have Supabase running and configured in `lib/main.dart`
2. Run `flutter pub get` to ensure all dependencies are installed
3. The database tables must already exist (run migrations first)

## Usage

### Dry Run (recommended first)
```bash
dart run scripts/seed_data_from_csv.dart --dry-run --verbose
```
This will show what would be inserted without actually inserting anything.

### Actual Seeding
```bash
dart run scripts/seed_data_from_csv.dart --verbose
```

## CSV Files

The script reads these CSV files in order:

1. `T09  categories.csv` → `document_categories` table
2. `Clientèle.csv` → `clients` table
3. `Employés.csv` → `drivers` table
4. `T00vehicules.csv` → `trucks` table
5. `T00frigo.csv` → `trailers` table
6. `Produits.csv` → `products` table
7. `Commandes.csv` → `trip_orders` table
8. `Détails commande.csv` → `trip_order_items` table

## Column Mapping

### Clientèle.csv → clients
- `NomSociété` → `name`
- `NuméroTél` → `phone`
- `AdresseFacturation` → `address` and `adresse_facturation`
- `Ville` → `city`
- `NomContact` → `nom_contact`

### Employés.csv → drivers
- `Prénom` + `NomFamille` → `name`
- `TéléProfessionnel` → `phone`
- `Poste` → `license`

### T00vehicules.csv → trucks
- `vehicules` → `plate`
- `Marque` → `model`
- `Susp` → `status` (TRUE = inactive, FALSE = active)

### T00frigo.csv → trailers
- `frigo` → `plate_number`
- `TBD` → `type` (Frigo)

### Produits.csv → products
- `NomProduit` → `name`
- `PrixUnitaire` → `price`
- `international` → `is_international`

### Commandes.csv → trip_orders
- `RéfClient` → `client_id`
- `RéfEmployé` → `driver_id`
- `NuméroBonCommande` → `order_number`
- `DateCommande` → `issue_date`
- `DateExpédition` → `due_date`
- `Valider` → `status` (TRUE = confirmed, FALSE = pending)
- `MontantPaiement` → `total_amount`

### Détails commande.csv → trip_order_items
- `RéfCommande` → `trip_order_id`
- `RéfProduit` → `product_id`
- `Quantité` → `quantity`
- `PrixUnitaire` → `unit_price`

## Notes

- French number format is automatically converted (e.g., `6.000,00` → `6000.00`)
- Dates in DD/MM/YYYY format are converted to ISO 8601
- Empty rows and rows with missing required fields are skipped
- The script uses `INSERT` with conflict handling where possible