-- Seed sample data for the international transport app
-- Safe to re-run: all inserts use ON CONFLICT DO NOTHING
-- Note: Users must be created through the app or Supabase Auth API,
-- since public.users references auth.users(id).

-- ============================================================
-- 1. APP_SETTINGS (TVA settings)
-- ============================================================
insert into public.app_settings (id, percentage, is_enabled) values
  (1, 20, true)
on conflict (id) do nothing;

-- ============================================================
-- 2. BANK_ACCOUNTS
-- ============================================================
insert into public.bank_accounts (bank_name, account_number, account_holder, currency, iban, swift_code, is_active) values
  ('Banque Populaire', '001 123 456789012', 'Company SARL', 'MAD', 'MA6401234567890123456789012', 'BCDMAMMC', true),
  ('BNP Paribas', 'FR76 3000 6000 0123 4567 8900', 'Company SARL', 'EUR', 'FR1420041010050500013M02606', 'BNPAFRPP', true),
  ('Caisse quotidienne', 'CASH-001', 'Company SARL', 'MAD', null, null, true)
on conflict do nothing;

-- ============================================================
-- 3. CLIENTS
-- ============================================================
insert into public.clients (id, company_name, phone, name, address, city) values
  (1, 'SAS RIPO', '+33123456789', 'SAS RIPO', '3 Rue Paul Verlaine, Noisy-le-Sec', 'PARIS'),
  (2, 'Maro Pasta', '+212612345678', 'Maro Pasta', 'Av. Al Massira N370', 'Nador'),
  (3, 'TOKA IMPORT-EXPORT', '+212623456789', 'TOKA IMPORT-EXPORT', 'Zone Industrielle', 'Nador'),
  (4, 'FADLY DISTRIBUTION', '+212634567890', 'FADLY DISTRIBUTION', 'Lot 25, Lot N 99, Nador Aljadid', 'Nador'),
  (5, 'SOFRUCE', '+33412345678', 'SOFRUCE', '135 Avenue Georges Caustier, Grand Saint Charles', 'Perpignan'),
  (6, 'BERKANE TRADING', '+212645678901', 'BERKANE TRADING', '7 Residence Rami, Rue Sebta, 2eme Etage', 'Casablanca'),
  (7, 'Assoufi Clever Pasta', '+212656789012', 'Assoufi Clever Pasta', '5eme Etage Qt. Al Matar', 'Nador'),
  (8, 'ALMA TRANSITAIRES', '+33423456789', 'ALMA TRANSITAIRES', 'SAS 56 Rue de Lisbonne, Grand St Charles', 'Perpignan'),
  (9, 'GADIRIA PRIMEURS', '+33434567890', 'GADIRIA PRIMEURS', 'Zone Commerciale', 'Perpignan'),
  (10, 'TRANSPORTES NIEVES', '+34956123456', 'TRANSPORTES NIEVES', 'Virgen del Carmen 15, 1Derecha', 'Algeciras')
on conflict do nothing;

-- ============================================================
-- 4. DRIVERS
-- ============================================================
insert into public.drivers (id, name, phone, license, status, base_salary, bonus_percentage) values
  (1, 'DAFOUNE MUSTAPHA', '+212661234567', 'Permis B+C+E', 'active', 5000, 10),
  (2, 'Benali Ahmed', '+212672345678', 'Permis B+C+E', 'active', 4500, 8),
  (3, 'Oukili Omar', '+212683456789', 'Permis B+C', 'active', 4000, 5),
  (4, 'El Amrani Said', '+212694567890', 'Permis B+C+E', 'active', 5500, 12),
  (5, 'Tazi Rachid', '+212605678901', 'Permis B+C', 'inactive', 0, 0)
on conflict do nothing;

-- ============================================================
-- 5. TRUCKS
-- Note: no "model" column - only plate_number, brand, current_km, oil_change_km
-- ============================================================
insert into public.trucks (id, plate_number, brand, current_km, oil_change_km) values
  (1, '12795-B-50', 'DAF', 450000, 50000),
  (2, '7099-B-50', 'VOLVO', 380000, 45000),
  (3, '14305-B-50', 'SCANIA', 320000, 40000),
  (4, '16258-B-50', 'DAF', 280000, 35000),
  (5, '17785-B-50', 'VOLVO', 150000, 30000),
  (6, '18573-B-50', 'VOLVO', 120000, 30000),
  (7, '19927-B-50', 'IVECO', 95000, 25000),
  (8, '20640-B-50', 'DAF', 75000, 25000),
  (9, '20716-B-50', 'VOLVO', 50000, 20000),
  (10, '24134-A-5', 'SCANIA', 30000, 20000)
on conflict (id) do nothing;

-- ============================================================
-- 6. TRAILERS
-- ============================================================
insert into public.trailers (id, plate_number, type) values
  (1, '8339-08', 'Frigo'),
  (2, 'FRIGO 2', 'Frigo'),
  (3, 'FRIGO 3', 'Frigo'),
  (4, '8161-08', 'Frigo'),
  (5, '8414-04', 'Frigo'),
  (6, '8189-08', 'Frigo'),
  (7, '8226-08', 'Frigo'),
  (8, 'R0537BBC', 'Frigo'),
  (9, 'R6598BBY', 'Frigo'),
  (10, '8252-08', 'Frigo')
on conflict (id) do nothing;

-- ============================================================
-- 7. DOCUMENT_CATEGORIES
-- ============================================================
insert into public.document_categories (id, name) values
  (1, 'تأمين'),
  (2, 'فحص تقني'),
  (3, 'البطاقة الرمادية'),
  (4, 'رخصة النقل'),
  (5, 'شهايد مطابقة'),
  (6, 'تأمين المسؤولية المدنية'),
  (7, 'أخرى'),
  (8, 'Assurance'),
  (9, 'Visite Technique'),
  (10, 'Carnet de Circulation')
on conflict (id) do nothing;

-- ============================================================
-- 8. TRIP_ORDERS
-- Note: agreed_price is NOT NULL - always provided
-- ============================================================
insert into public.trip_orders (id, client_id, driver_id, route, departure_date, status, price, agreed_price, truck_id) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 1, 'MAROC - BERKANE - France - PERPIGNAN', '2024-10-15', 'confirmed', 15000, 15000, 1),
  (2, 1, 2, 'MURCIA - NADOR', '2024-10-20', 'confirmed', 12500, 12500, 2),
  (3, 2, 1, 'VALENCIA - NADOR', '2024-10-25', 'pending', 18000, 18000, 3),
  (4, 3, 3, 'CASTELLON - BERKANE', '2024-11-01', 'confirmed', 22000, 22000, 4),
  (5, 4, 2, 'NADOR - BARCELONA', '2024-11-05', 'pending', 16500, 16500, 5),
  (6, 5, 4, 'TARRAGONE - NADOR', '2024-11-10', 'confirmed', 19500, 19500, 6),
  (7, 6, 1, 'MAROC NADOR - Espagne EL EJIDO', '2024-11-15', 'confirmed', 14000, 14000, 7),
  (8, 7, 3, 'NADOR - GENOVA', '2024-11-20', 'pending', 17000, 17000, 8),
  (9, 8, 2, 'ITALIA - Skhirat, Maroc', '2024-11-25', 'confirmed', 21000, 21000, 9),
  (10, 9, 4, 'BELGIQUE - NADOR', '2024-12-01', 'confirmed', 23000, 23000, 10)
on conflict (id) do nothing;

-- ============================================================
-- 9. INVOICES
-- ============================================================
insert into public.invoices (id, client_id, invoice_number, total_amount, paid_amount, status, issue_date, due_date, currency) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 'INV-2024-001', 15000, 15000, 'paid', '2024-10-15', '2024-11-15', 'MAD'),
  (2, 1, 'INV-2024-002', 12500, 6250, 'partially_paid', '2024-10-20', '2024-11-20', 'MAD'),
  (3, 2, 'INV-2024-003', 18000, 0, 'unpaid', '2024-10-25', '2024-11-25', 'MAD'),
  (4, 3, 'INV-2024-004', 22000, 22000, 'paid', '2024-11-01', '2024-12-01', 'EUR'),
  (5, 4, 'INV-2024-005', 16500, 0, 'unpaid', '2024-11-05', '2024-12-05', 'MAD'),
  (6, 5, 'INV-2024-006', 19500, 9800, 'partially_paid', '2024-11-10', '2024-12-10', 'EUR'),
  (7, 6, 'INV-2024-007', 14000, 14000, 'paid', '2024-11-15', '2024-12-15', 'MAD'),
  (8, 7, 'INV-2024-008', 17000, 0, 'unpaid', '2024-11-20', '2024-12-20', 'MAD'),
  (9, 8, 'INV-2024-009', 21000, 21000, 'paid', '2024-11-25', '2024-12-25', 'EUR'),
  (10, 9, 'INV-2024-010', 23000, 0, 'unpaid', '2024-12-01', '2025-01-01', 'MAD')
on conflict (id) do nothing;

-- ============================================================
-- 10. TREASURY_TRANSACTIONS (initial balance + operations)
-- Note: receipt_url is a UUID column - left NULL (no real UUID)
-- ============================================================
insert into public.treasury_transactions (id, type, amount, description, receipt_url) 
  OVERRIDING SYSTEM VALUE
values
  (1, 'capital_injection', 100000, 'تزويد رأس مال أولي', null),
  (2, 'trip_revenue', 15000, 'تحصيل فاتورة INV-2024-001', null),
  (3, 'trip_revenue', 22000, 'تحصيل فاتورة INV-2024-004', null),
  (4, 'trip_revenue', 14000, 'تحصيل فاتورة INV-2024-007', null),
  (5, 'trip_revenue', 21000, 'تحصيل فاتورة INV-2024-009', null),
  (6, 'trip_expense', 15000, 'عهدة السائق DAFOUNE MUSTAPHA — تسليم عهدة #1', null),
  (7, 'trip_expense', 12500, 'عهدة السائق Benali Ahmed — تسليم عهدة #2', null),
  (8, 'trip_expense', 18000, 'عهدة السائق Oukili Omar — تسليم عهدة #3', null),
  (9, 'trip_expense', 22000, 'عهدة السائق El Amrani Said — تسليم عهدة #4', null),
  (10, 'office_expense', 3500, 'مصاريف مكتبية - أكتوبر 2024', null),
  (11, 'salary', 25000, 'رواتب السائقين - أكتوبر 2024', null),
  (12, 'trip_expense', 16500, 'عهدة السائق Benali Ahmed — تسليم عهدة #5', null),
  (13, 'trip_expense', 19500, 'عهدة السائق El Amrani Said — تسليم عهدة #6', null),
  (14, 'trip_revenue', 6250, 'تحصيل جزئي فاتورة INV-2024-002', null),
  (15, 'trip_revenue', 9800, 'تحصيل جزئي فاتورة INV-2024-006', null),
  (16, 'office_expense', 2800, 'مصاريف مكتبية - نوفمبر 2024', null),
  (17, 'salary', 25000, 'رواتب السائقين - نوفمبر 2024', null)
on conflict (id) do nothing;

-- ============================================================
-- 11. ADVANCES
-- ============================================================
insert into public.advances (id, driver_id, amount_given, date_out, status, amount_spent, amount_returned, date_return, notes) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 15000, '2024-10-15', 'settled', 14500, 500, '2024-10-18', 'رحلة بيربينيان - عاد السائق بباقي 500 درهم'),
  (2, 2, 12500, '2024-10-20', 'settled', 12000, 500, '2024-10-23', 'رحلة مرسية - عاد السائق بباقي 500 درهم'),
  (3, 3, 18000, '2024-10-25', 'pending', null, null, null, 'في الطريق إلى فالنسيا'),
  (4, 4, 22000, '2024-11-01', 'settled', 21800, 200, '2024-11-05', 'رحلة برشلونة - عاد السائق بباقي 200 درهم'),
  (5, 2, 16500, '2024-11-05', 'pending', null, null, null, 'في الطريق إلى أليكانتي'),
  (6, 4, 19500, '2024-11-10', 'settled', 19000, 500, '2024-11-14', 'رحلة مورسيا - عاد السائق بباقي 500 درهم'),
  (7, 1, 14000, '2024-11-15', 'settled', 13800, 200, '2024-11-18', 'رحلة كاستيون - عاد السائق بباقي 200 درهم'),
  (8, 3, 17000, '2024-11-20', 'pending', null, null, null, 'في الطريق إلى غرناطة'),
  (9, 2, 21000, '2024-11-25', 'settled', 20500, 500, '2024-11-28', 'رحلة إشبيلية - عاد السائق بباقي 500 درهم'),
  (10, 4, 23000, '2024-12-01', 'pending', null, null, null, 'رحلة إيطاليا - في الطريق')
on conflict (id) do nothing;

-- ============================================================
-- 12. FLEET_DOCUMENTS (sample documents for trucks and trailers)
-- ============================================================
insert into public.fleet_documents (id, entity_type, entity_id, category_id, document_number, expiry_date) 
  OVERRIDING SYSTEM VALUE
values
  (1, 'truck', 1, 1, 'ASS-2024-001', '2025-03-15'),
  (2, 'truck', 1, 2, 'VT-2024-001', '2025-06-20'),
  (3, 'truck', 2, 1, 'ASS-2024-002', '2025-01-10'),
  (4, 'truck', 2, 2, 'VT-2024-002', '2025-04-15'),
  (5, 'truck', 3, 1, 'ASS-2024-003', '2025-07-22'),
  (6, 'truck', 3, 3, 'CG-2024-001', '2026-01-15'),
  (7, 'trailer', 1, 1, 'ASS-T-2024-001', '2025-02-28'),
  (8, 'trailer', 1, 2, 'VT-T-2024-001', '2025-05-10'),
  (9, 'trailer', 2, 1, 'ASS-T-2024-002', '2025-03-20'),
  (10, 'trailer', 3, 3, 'CG-T-2024-001', '2025-12-31')
on conflict (id) do nothing;

-- ============================================================
-- 13. NOTIFICATIONS
-- Note: user_id is a UUID column - left NULL (no real UUID)
-- ============================================================
insert into public.notifications (user_id, title, message) values
  (null, 'عهدة جديدة', 'أضافت السكرتيرة عهدة للسائق DAFOUNE MUSTAPHA'),
  (null, 'تسوية عهدة', 'تم تسوية عهدة السائق Benali Ahmed'),
  (null, 'تنبيه انتهاء فيزا', 'تنتهي فيزا السائق Oukili Omar خلال 15 يوماً')
on conflict do nothing;

-- ============================================================
-- 14. TRUCK_MAINTENANCE
-- ============================================================
insert into public.truck_maintenance (id, truck_id, expense_type, description, amount, km_at_time, due_date) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 'oil_change', 'تغيير زيت وفلتر', 2500, 450000, '2025-03-15'),
  (2, 2, 'repair', 'إصلاح فرامل', 4500, 380000, '2025-04-01'),
  (3, 3, 'technical_inspection', 'فحص دوري', 800, 320000, '2025-04-10'),
  (4, 4, 'tires', 'تبديل إطارات', 6000, 280000, '2025-04-20'),
  (5, 5, 'oil_change', 'تغيير زيت', 2200, 150000, '2025-05-01')
on conflict (id) do nothing;

-- ============================================================
-- 15. INVOICE_PAYMENTS
-- ============================================================
insert into public.invoice_payments (id, invoice_id, amount_paid, payment_method, receipt_reference, payment_date) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 15000, 'bank_transfer', 'TRF-2024-001', '2024-10-15'),
  (2, 3, 22000, 'bank_transfer', 'TRF-2024-002', '2024-11-01'),
  (3, 5, 6250, 'cash', 'REC-2024-001', '2024-10-25'),
  (4, 6, 14000, 'bank_transfer', 'TRF-2024-003', '2024-11-15'),
  (5, 7, 9800, 'check', 'CHQ-2024-001', '2024-11-12'),
  (6, 8, 21000, 'bank_transfer', 'TRF-2024-004', '2024-11-25')
on conflict (id) do nothing;

-- ============================================================
-- 16. TRIP_ORDER_DOCUMENTS
-- ============================================================
insert into public.trip_order_documents (id, trip_order_id, file_name, file_url, file_type, document_type) 
  OVERRIDING SYSTEM VALUE
values
  (1, 1, 'CMR-2024-001.pdf', 'https://storage.example.com/cmr/001.pdf', 'pdf', 'customs'),
  (2, 3, 'CMR-2024-002.pdf', 'https://storage.example.com/cmr/002.pdf', 'pdf', 'customs'),
  (3, 4, 'CMR-2024-003.pdf', 'https://storage.example.com/cmr/003.pdf', 'pdf', 'customs'),
  (4, 6, 'CMR-2024-004.pdf', 'https://storage.example.com/cmr/004.pdf', 'pdf', 'customs')
on conflict (id) do nothing;
