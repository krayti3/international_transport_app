<#
.SYNOPSIS
Seeds demo data into the Supabase database for the international transport app.
Period: 2026-06-13 to 2026-07-13 (31 days).
#>

param(
    [string]$SupabaseUrl = "https://jgehdsmrmcpnvcnfrjai.supabase.co",
    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

if (-not $ServiceRoleKey) {
    Write-Error "ServiceRoleKey must be provided as a parameter or via the SUPABASE_SERVICE_ROLE_KEY environment variable."
    exit 1
}

$headers = @{
    "apikey"        = $ServiceRoleKey
    "Authorization" = "Bearer $ServiceRoleKey"
    "Content-Type"  = "application/json"
    "Prefer"        = "resolution=merge-duplicates"
}

$createdIds = @{}
$stats = @{}
$startDate = Get-Date "2026-06-13"
$endDate   = Get-Date "2026-07-13"
$allDates  = while ($d -le $endDate) { $d = $startDate; $startDate = $startDate.AddDays(1); $d.ToString("yyyy-MM-dd") }

# ============================================================
# Section 1: Configuration and helpers
# ============================================================

function Invoke-SupabasePost {
    param(
        [string]$Table,
        [object]$Body,
        [hashtable]$ExtraHeaders = @{}
    )
    $url = "$SupabaseUrl/rest/v1/$Table"
    $combinedHeaders = $headers.Clone()
    $combinedHeaders += $ExtraHeaders
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $combinedHeaders -Body ($Body | ConvertTo-Json -Depth 10) -ErrorAction Stop
        return $response
    }
    catch {
        Write-Warning "Failed to insert into '$Table': $($_.Exception.Message)"
        if ($_.Exception.Response) {
            try {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                Write-Warning "Response body: $errorBody"
            }
            catch { }
        }
        return $null
    }
}

function Invoke-SupabaseUpsert {
    param(
        [string]$Table,
        [object]$Body,
        [hashtable]$ExtraHeaders = @{}
    )
    $url = "$SupabaseUrl/rest/v1/$Table"
    $combinedHeaders = $headers.Clone()
    $combinedHeaders["Prefer"] = "resolution=merge-duplicates,return=minimal"
    $combinedHeaders += $ExtraHeaders
    try {
        Invoke-RestMethod -Uri $url -Method Post -Headers $combinedHeaders -Body ($Body | ConvertTo-Json -Depth 10) -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Warning "Failed to upsert into '$Table': $($_.Exception.Message)"
        return $false
    }
}

# ============================================================
# Section 2: Create auth user (iman@admin.com)
# ============================================================

Write-Host "`n=== Section 2: Auth User ===" -ForegroundColor Cyan

$authHeaders = @{
    "apikey"        = $ServiceRoleKey
    "Authorization" = "Bearer $ServiceRoleKey"
    "Content-Type"  = "application/json"
}

try {
    $existingUsers = Invoke-RestMethod -Uri "$SupabaseUrl/auth/v1/admin/users" -Method Get -Headers $authHeaders -ErrorAction Stop
    $existingAdmin = $existingUsers.users | Where-Object { $_.email -eq "iman@admin.com" }
    if ($existingAdmin) {
        Write-Host "User iman@admin.com already exists (id: $($existingAdmin.id)). Skipping creation."
        $createdIds["admin_user_id"] = $existingAdmin.id
    }
    else {
        $adminUserBody = @{
            email    = "iman@admin.com"
            password = "Afra@2023"
            email_confirm = $true
            user_metadata = @{
                role  = "admin"
                name  = "Iman Admin"
            }
        } | ConvertTo-Json -Depth 5

        $createdAdmin = Invoke-RestMethod -Uri "$SupabaseUrl/auth/v1/admin/users" -Method Post -Headers $authHeaders -Body $adminUserBody -ErrorAction Stop
        $createdIds["admin_user_id"] = $createdAdmin.id
        Write-Host "Created admin user iman@admin.com with id: $($createdAdmin.id)"
    }
}
catch {
    Write-Warning "Could not create/find admin user in Auth: $($_.Exception.Message)"
}

# ============================================================
# Section 3: Reference data
# ============================================================

Write-Host "`n=== Section 3: Reference Data ===" -ForegroundColor Cyan

# --- Clients (8) ---
Write-Host "Seeding clients..." -ForegroundColor Yellow
$clientData = @(
    @{ company_name = "Al-Madina Trading Co."; phone = "+964 770 111 0001"; address = "Baghdad, Al-Karada"; city = "Baghdad" }
    @{ company_name = "Basra Oil Services Ltd."; phone = "+964 770 111 0002"; address = "Basra, Al-Ashrafiya"; city = "Basra" }
    @{ company_name = "Erbil Logistics Corp."; phone = "+964 770 111 0003"; address = "Erbil, Ankawa"; city = "Erbil" }
    @{ company_name = "Najaf Commerce Group"; phone = "+964 770 111 0004"; address = "Najaf, Al-Maidan"; city = "Najaf" }
    @{ company_name = "Mosul Import-Export"; phone = "+964 770 111 0005"; address = "Mosul, Al-Mosul Jadaida"; city = "Mosul" }
    @{ company_name = "Kurdistan Freight Co."; phone = "+964 770 111 0006"; address = "Sulaymaniyah, Salim"; city = "Sulaymaniyah" }
    @{ company_name = "Wasit Shipping Ltd."; phone = "+964 770 111 0007"; address = "Kut, Al-Kut"; city = "Kut" }
    @{ company_name = "Diyala Transport Inc."; phone = "+964 770 111 0008"; address = "Baquba, Al-Baquba"; city = "Baquba" }
)

$stats["clients"] = 0
foreach ($client in $clientData) {
    $result = Invoke-SupabasePost -Table "clients" -Body $client
    if ($result -and $result.Count -gt 0) {
        $createdIds["client_$($stats['clients'] + 1)"] = $result[0].id
        $stats["clients"]++
    }
    elseif ($null -eq $result) {
        Write-Warning "  Skipping client insert due to error."
    }
}
Write-Host "  Clients inserted: $($stats['clients'])"

# --- Trucks (4) ---
Write-Host "Seeding trucks..." -ForegroundColor Yellow
$truckData = @(
    @{ plate = "BGH-001"; model = "Volvo FH16"; status = "active" }
    @{ plate = "BGH-002"; model = "Scania R450"; status = "active" }
    @{ plate = "BGH-003"; model = "Mercedes Actros"; status = "maintenance" }
    @{ plate = "BGH-004"; model = "MAN TGX"; status = "active" }
)

$stats["trucks"] = 0
foreach ($truck in $truckData) {
    $result = Invoke-SupabasePost -Table "trucks" -Body $truck
    if ($result -and $result.Count -gt 0) {
        $createdIds["truck_$($stats['trucks'] + 1)"] = $result[0].id
        $stats["trucks"]++
    }
    elseif ($null -eq $result) {
        Write-Warning "  Skipping truck insert due to error."
    }
}
Write-Host "  Trucks inserted: $($stats['trucks'])"

# --- Trailers (4) ---
Write-Host "Seeding trailers..." -ForegroundColor Yellow
$trailerData = @(
    @{ plate_number = "TRL-001"; type = "flatbed" }
    @{ plate_number = "TRL-002"; type = "container" }
    @{ plate_number = "TRL-003"; type = "refrigerated" }
    @{ plate_number = "TRL-004"; type = "tanker" }
)

$stats["trailers"] = 0
foreach ($trailer in $trailerData) {
    $result = Invoke-SupabasePost -Table "trailers" -Body $trailer
    if ($result -and $result.Count -gt 0) {
        $createdIds["trailer_$($stats['trailers'] + 1)"] = $result[0].id
        $stats["trailers"]++
    }
    elseif ($null -eq $result) {
        Write-Warning "  Skipping trailer insert due to error."
    }
}
Write-Host "  Trailers inserted: $($stats['trailers'])"

# --- Drivers (5) ---
Write-Host "Seeding drivers..." -ForegroundColor Yellow
$driverData = @(
    @{ name = "Ahmed Hassan"; phone = "+964 770 222 0001"; license = "DL-1001"; status = "available"; base_salary = 850000; bonus_percentage = 5; default_truck_id = $createdIds["truck_1"] }
    @{ name = "Omar Khalid"; phone = "+964 770 222 0002"; license = "DL-1002"; status = "on_trip"; base_salary = 800000; bonus_percentage = 4; default_truck_id = $createdIds["truck_2"] }
    @{ name = "Sami Najib"; phone = "+964 770 222 0003"; license = "DL-1003"; status = "available"; base_salary = 900000; bonus_percentage = 6; default_truck_id = $createdIds["truck_3"] }
    @{ name = "Ali Fadel"; phone = "+964 770 222 0004"; license = "DL-1004"; status = "off_duty"; base_salary = 750000; bonus_percentage = 3; default_truck_id = $createdIds["truck_4"] }
    @{ name = "Mustafa Abbas"; phone = "+964 770 222 0005"; license = "DL-1005"; status = "available"; base_salary = 820000; bonus_percentage = 5; default_truck_id = $createdIds["truck_1"] }
)

$stats["drivers"] = 0
foreach ($driver in $driverData) {
    $result = Invoke-SupabasePost -Table "drivers" -Body $driver
    if ($result -and $result.Count -gt 0) {
        $createdIds["driver_$($stats['drivers'] + 1)"] = $result[0].id
        $stats["drivers"]++
    }
    elseif ($null -eq $result) {
        Write-Warning "  Skipping driver insert due to error."
    }
}
Write-Host "  Drivers inserted: $($stats['drivers'])"

# ============================================================
# Section 4: Daily data loop
# ============================================================

Write-Host "`n=== Section 4: Daily Data (31 days) ===" -ForegroundColor Cyan

$stats["trip_orders"]   = 0
$stats["advances"]      = 0
$stats["invoices"]      = 0
$stats["payments"]      = 0
$stats["allocations"]   = 0
$stats["treasury"]      = 0
$stats["maintenance"]   = 0
$stats["notifications"] = 0

$dayIndex = 0
foreach ($dateStr in $allDates) {
    $dayIndex++
    $clientKey = "client_$(((($dayIndex - 1) % 8) + 1))"
    $driverKey = "driver_$(((($dayIndex - 1) % 5) + 1))"
    $truckKey  = "truck_$(((($dayIndex - 1) % 4) + 1))"

    if (-not $createdIds.ContainsKey($clientKey) -or -not $createdIds.ContainsKey($driverKey) -or -not $createdIds.ContainsKey($truckKey)) {
        Write-Warning "Day $dayIndex ($dateStr): Missing reference IDs, skipping daily data."
        continue
    }

    $clientId = $createdIds[$clientKey]
    $driverId = $createdIds[$driverKey]
    $truckId  = $createdIds[$truckKey]

    $directions = @("outbound", "return")
    $direction  = $directions[$dayIndex % 2]

    # --- trip_orders ---
    $agreedPrice = [math]::Round((Get-Random -Minimum 5000000 -Maximum 25000000), -3)
    $tripOrder   = @{
        client_id     = $clientId
        route         = "Baghdad - $($directions[$dayIndex % 2])"
        agreed_price  = $agreedPrice
        departure_date = $dateStr
        status        = "completed"
        driver_id     = $driverId
        truck_id      = $truckId
        direction     = $direction
        specific_expenses = @{ fuel = 1500000; tolls = 200000 }
    }

    $tripResult = Invoke-SupabasePost -Table "trip_orders" -Body $tripOrder
    if ($tripResult -and $tripResult.Count -gt 0) {
        $tripOrderId = $tripResult[0].id
        $createdIds["trip_order_day$dayIndex"] = $tripOrderId
        $stats["trip_orders"]++
    }

    # --- advances ---
    $amountGiven    = [math]::Round((Get-Random -Minimum 500000 -Maximum 3000000), -2)
    $amountSpent    = [math]::Round((Get-Random -Minimum 300000 -Maximum 2000000), -2)
    $amountReturned = [amountGiven - $amountSpent]
    if ($amountReturned -lt 0) { $amountReturned = 0 }

    $advanceStatuses = @("pending", "en_route", "settled")
    $advanceStatus   = $advanceStatuses[$dayIndex % 3]
    $dateReturnVal   = if ($advanceStatus -eq "settled") { $dateStr } else { $null }

    $advance = @{
        driver_id       = $driverId
        amount_given    = $amountGiven
        date_out        = $dateStr
        status          = $advanceStatus
        amount_spent    = $amountSpent
        amount_returned = $amountReturned
        date_return     = $dateReturnVal
        notes           = "Advance for trip on $dateStr"
        is_deleted      = $false
    }

    $advanceResult = Invoke-SupabasePost -Table "advances" -Body $advance
    if ($advanceResult -and $advanceResult.Count -gt 0) {
        $stats["advances"]++
    }

    # --- invoices ---
    $invoiceTotal  = [math]::Round((Get-Random -Minimum 3000000 -Maximum 20000000), -3)
    $paidAmount    = if ($dayIndex % 3 -eq 0) { $invoiceTotal } elseif ($dayIndex % 3 -eq 1) { [math]::Round($invoiceTotal * 0.5, -3) } else { 0 }
    $invoiceStatus = if ($paidAmount -ge $invoiceTotal) { "paid" } elseif ($paidAmount -gt 0) { "partially_paid" } elseif ($dayIndex % 5 -eq 0) { "overdue" } else { "sent" }
    $issueDate     = $dateStr
    $dueDate       = (Get-Date $dateStr).AddDays(30).ToString("yyyy-MM-dd")

    $invoice = @{
        client_id      = $clientId
        invoice_number = "INV-2026-$($dayIndex.ToString("D3"))"
        total_amount   = $invoiceTotal
        paid_amount    = $paidAmount
        status         = $invoiceStatus
        issue_date     = $issueDate
        due_date       = $dueDate
    }

    $invoiceResult = Invoke-SupabasePost -Table "invoices" -Body $invoice
    if ($invoiceResult -and $invoiceResult.Count -gt 0) {
        $invoiceId = $invoiceResult[0].id
        $createdIds["invoice_day$dayIndex"] = $invoiceId
        $stats["invoices"]++
    }

    # --- payments ---
    if ($paidAmount -gt 0 -and $null -ne $createdIds["invoice_day$dayIndex"]) {
        $methods = @("cash", "bank_transfer", "check")
        $method  = $methods[$dayIndex % 3]

        $payment = @{
            client_id   = $clientId
            total_amount = $paidAmount
            method      = $method
            ref         = "PAY-2026-$($dayIndex.ToString("D3"))"
        }

        $paymentResult = Invoke-SupabasePost -Table "payments" -Body $payment
        if ($paymentResult -and $paymentResult.Count -gt 0) {
            $paymentId = $paymentResult[0].id
            $createdIds["payment_day$dayIndex"] = $paymentId
            $stats["payments"]++
        }
    }

    # --- payment_invoice_allocations ---
    if ($paidAmount -gt 0 -and $createdIds.ContainsKey("payment_day$dayIndex") -and $createdIds.ContainsKey("invoice_day$dayIndex")) {
        $allocation = @{
            payment_id        = $createdIds["payment_day$dayIndex"]
            invoice_id        = $createdIds["invoice_day$dayIndex"]
            allocated_amount  = $paidAmount
        }

        $allocResult = Invoke-SupabasePost -Table "payment_invoice_allocations" -Body $allocation
        if ($allocResult -and $allocResult.Count -gt 0) {
            $stats["allocations"]++
        }
    }

    # --- treasury_transactions (2 per day) ---
    $treasuryTypes = @("trip_revenue", "owner_withdrawal", "office_expense", "salary")
    $t1Type = $treasuryTypes[($dayIndex - 1) % 4]
    $t2Type = $treasuryTypes[$dayIndex % 4]

    $t1Amount = if ($t1Type -eq "trip_revenue") { $agreedPrice } elseif ($t1Type -eq "salary") { [math]::Round((Get-Random -Minimum 800000 -Maximum 1200000), -3) } else { [math]::Round((Get-Random -Minimum 200000 -Maximum 1500000), -3) }
    $t2Amount = if ($t2Type -eq "trip_revenue") { [math]::Round((Get-Random -Minimum 3000000 -Maximum 18000000), -3) } elseif ($t2Type -eq "salary") { [math]::Round((Get-Random -Minimum 800000 -Maximum 1200000), -3) } else { [math]::Round((Get-Random -Minimum 200000 -Maximum 1500000), -3) }

    $treasury1 = @{
        type        = $t1Type
        amount      = $t1Amount
        description = "$t1Type for $dateStr (day $dayIndex)"
    }
    $treasury2 = @{
        type        = $t2Type
        amount      = $t2Amount
        description = "$t2Type for $dateStr (day $dayIndex)"
    }

    $t1Result = Invoke-SupabasePost -Table "treasury_transactions" -Body $treasury1
    if ($t1Result -and $t1Result.Count -gt 0) { $stats["treasury"]++ }

    $t2Result = Invoke-SupabasePost -Table "treasury_transactions" -Body $treasury2
    if ($t2Result -and $t2Result.Count -gt 0) { $stats["treasury"]++ }

    # --- truck_maintenance (every 5 days) ---
    if ($dayIndex % 5 -eq 0) {
        $expenseTypes = @("oil_change", "tires", "insurance", "technical_inspection", "depreciation", "other")
        $expenseType  = $expenseTypes[([math]::Floor($dayIndex / 5) - 1) % $expenseTypes.Length]
        $maintAmount  = [math]::Round((Get-Random -Minimum 500000 -Maximum 5000000), -3)
        $dueDate      = (Get-Date $dateStr).AddMonths(1).ToString("yyyy-MM-dd")

        $maintenance = @{
            truck_id      = $truckId
            expense_type  = $expenseType
            description   = "$expenseType for truck $($truckData[($stats['trucks'] - 1) % 4].plate) due $dueDate"
            amount        = $maintAmount
            due_date      = $dueDate
        }

        $maintResult = Invoke-SupabasePost -Table "truck_maintenance" -Body $maintenance
        if ($maintResult -and $maintResult.Count -gt 0) {
            $stats["maintenance"]++
        }
    }

    # --- notifications (every 3 days) ---
    if ($dayIndex % 3 -eq 0) {
        $notificationTitles = @("Trip reminder", "Payment due", "Maintenance alert", "Driver shift change")
        $title    = $notificationTitles[([math]::Floor($dayIndex / 3) - 1) % $notificationTitles.Length]
        $message  = "Notification for $dateStr: $title for client $($clientData[($stats['clients'] - 1) % 8].company_name)."

        $notification = @{
            user_id = $createdIds["admin_user_id"]
            title   = $title
            message = $message
        }

        $notifResult = Invoke-SupabasePost -Table "notifications" -Body $notification
        if ($notifResult -and $notifResult.Count -gt 0) {
            $stats["notifications"]++
        }
    }
}

Write-Host "`nDaily data seeding completed."

# ============================================================
# Section 5: Related tables
# ============================================================

Write-Host "`n=== Section 5: Related Tables ===" -ForegroundColor Cyan

# --- truck_documents (4 per truck) ---
Write-Host "Seeding truck_documents..." -ForegroundColor Yellow
$stats["truck_documents"] = 0
$truckDocTypes = @("registration", "insurance", "technical_inspection", "tax")

for ($t = 1; $t -le $stats["trucks"]; $t++) {
    $truckId = $createdIds["truck_$t"]
    if (-not $truckId) { continue }

    for ($d = 0; $d -lt 4; $d++) {
        $docType     = $truckDocTypes[$d]
        $expiryDate  = (Get-Date).AddMonths($d + 1).ToString("yyyy-MM-dd")
        $attachment  = "https://example.com/documents/truck_$t`_$docType.pdf"

        $truckDoc = @{
            truck_id        = $truckId
            document_type   = $docType
            document_number = "DOC-TRUCK-$t-$($d + 1)"
            expiry_date     = $expiryDate
            attachment_url  = $attachment
        }

        $tdResult = Invoke-SupabasePost -Table "truck_documents" -Body $truckDoc
        if ($tdResult -and $tdResult.Count -gt 0) {
            $stats["truck_documents"]++
        }
    }
}
Write-Host "  Truck documents inserted: $($stats['truck_documents'])"

# --- documents (8) ---
Write-Host "Seeding documents..." -ForegroundColor Yellow
$stats["documents"] = 0
$documentNames = @(
    "Company Registration Certificate",
    "Tax ID Certificate",
    "Commercial License",
    "Insurance Policy 2026",
    "Import/Export License",
    "Customs Brokerage License",
    "ISO 9001 Certification",
    "Environmental Compliance Certificate"
)

for ($d = 0; $d -lt 8; $d++) {
    $vehicleType = if ($d -lt 4) { "truck" } else { "trailer" }
    $vehicleIdx  = if ($d -lt 4) { ($d % 4) + 1 } else { ($d % 4) + 1 }
    $vehicleId   = if ($vehicleType -eq "truck") { $createdIds["truck_$vehicleIdx"] } else { $createdIds["trailer_$vehicleIdx"] }
    $expiryDate  = (Get-Date).AddMonths($d + 3).ToString("yyyy-MM-dd")

    if (-not $vehicleId) { continue }

    $document = @{
        vehicle_type   = $vehicleType
        vehicle_id     = $vehicleId
        document_name  = $documentNames[$d]
        expiry_date    = $expiryDate
        alert_days_before = 30
    }

    $docResult = Invoke-SupabasePost -Table "documents" -Body $document
    if ($docResult -and $docResult.Count -gt 0) {
        $stats["documents"]++
    }
}
Write-Host "  Documents inserted: $($stats['documents'])"

# --- app_settings ---
Write-Host "Seeding app_settings..." -ForegroundColor Yellow
$stats["app_settings"] = 0
$settingsHeaders = $headers.Clone()
$settingsHeaders["Prefer"] = "resolution=merge-duplicates,return=representation"

$appSettingsResult = Invoke-SupabaseUpsert -Table "app_settings" -Body @{
    id          = 1
    percentage  = 10
    is_enabled  = $true
} -ExtraHeaders @{ "Prefer" = "resolution=merge-duplicates,return=representation" }

if ($appSettingsResult) {
    $stats["app_settings"] = 1
    Write-Host "  App settings upserted successfully."
}
else {
    Write-Warning "  Failed to upsert app_settings."
}

# ============================================================
# Section 6: Summary
# ============================================================

Write-Host "`n=== Section 6: Summary ===" -ForegroundColor Cyan
Write-Host "----------------------------------------"
Write-Host ("clients                   : {0,5}" -f $stats["clients"])
Write-Host ("trucks                    : {0,5}" -f $stats["trucks"])
Write-Host ("trailers                  : {0,5}" -f $stats["trailers"])
Write-Host ("drivers                   : {0,5}" -f $stats["drivers"])
Write-Host ("trip_orders               : {0,5}" -f $stats["trip_orders"])
Write-Host ("advances                  : {0,5}" -f $stats["advances"])
Write-Host ("invoices                  : {0,5}" -f $stats["invoices"])
Write-Host ("payments                  : {0,5}" -f $stats["payments"])
Write-Host ("payment_invoice_allocations: {0,4}" -f $stats["allocations"])
Write-Host ("treasury_transactions     : {0,5}" -f $stats["treasury"])
Write-Host ("truck_maintenance         : {0,5}" -f $stats["maintenance"])
Write-Host ("notifications             : {0,5}" -f $stats["notifications"])
Write-Host ("truck_documents           : {0,5}" -f $stats["truck_documents"])
Write-Host ("documents                 : {0,5}" -f $stats["documents"])
Write-Host ("app_settings              : {0,5}" -f $stats["app_settings"])
Write-Host "----------------------------------------"

$totalRows = 0
$stats.Values | ForEach-Object { $totalRows += $_ }
Write-Host "Total rows inserted: $totalRows"
Write-Host "`nSeeding completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')."
