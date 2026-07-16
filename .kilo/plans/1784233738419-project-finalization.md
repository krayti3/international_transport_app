# Plan — Finalisation projet Flutter International Transport App

## Contexte
Le projet est fonctionnel en code mais nécessite 4 actions immédiates pour être opérationnel, plus 1 action moyen terme pour la maintenabilité.

## Tâches

### 1. Exécuter les migrations Supabase
- Ouvrir Supabase → SQL Editor → New query
- Coller l'intégralité de supabase/migrations_run_me.sql
- Exécuter (Run)
- Fichier idempotent (IF NOT EXISTS / DROP IF EXISTS), safe à rejouer

### 2. Ajouter l'asset .env dans pubspec.yaml
```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

### 3. Lancer flutter pub get
```powershell
cd D:\trans\international_transport_app
flutter pub get
```

### 4. Initialiser Git + commit initial
```powershell
cd D:\trans\international_transport_app
git init
git config user.name "International Transport App"
git config user.email "dev@transport.app"
git add .
git commit -m "Initial commit: Flutter international transport app with Supabase backend"
```

### 5. Nettoyer les scripts parasites de la racine
```powershell
cd D:\trans\international_transport_app
mkdir scripts -Force
mv check_all_negative.py, check_balance.py, check_before_build.py, check_build_balance.py, check_cols.py, check_end.py, check_full_balance.py, check_hex.py, check_negative.py, check_parens.py, check_strings.py, check_total_balance.py, read_lines.ps1 scripts\
```

### 6. (Moyen terme) Découper supabase_service.dart
- Analyser le fichier (~2500 lignes) et identifier les responsabilités distinctes
- Créer des services séparés : auth_service.dart, client_service.dart, trip_service.dart, invoice_service.dart, treasury_service.dart, fleet_service.dart
- Migrer progressivement les appels depuis supabase_service.dart vers les nouveaux services
- Mettre à jour les providers et écrans concernés
- Garder supabase_service.dart comme façade ou le supprimer une fois tout migré

## Validation
- [ ] flutter run lance l'app sans erreur de base de données
- [ ] Login fonctionne avec les credentials Supabase
- [ ] Les tables sont créées (vérifier dans Supabase Table Editor)
- [ ] Git status propre après commit initial
- [ ] Racine du projet nettoyée (plus de .py/.ps1 parasites)
