-- جداول الدفعات وتوزيعها على الفواتير (متوافقة مع أسماء أعمدة الكود في Dart)
-- مطابقة لـ models/payment.dart و models/payment_invoice_allocation.dart
-- العلاقة بين الدفعة والفواتير هي Many-to-Many عبر الجدول الوسيط.

-- 1) جدول الدفعات الإجمالية (payments)
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT REFERENCES clients(id),
    amount NUMERIC NOT NULL,                       -- المبلغ الإجمالي الذي دفعه الزبون (مثلاً 50000)
    method TEXT,                                   -- طريقة الدفع (تحويل بنكي، شيك، نقداً، كمبيالة)
    ref TEXT,                                      -- رقم الشيك أو المرجع/الوصل
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2) الجدول الوسيط لتقسيم الدفعة على الفواتير (payment_invoice_allocations)
CREATE TABLE IF NOT EXISTS payment_invoice_allocations (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT REFERENCES payments(id) ON DELETE CASCADE,
    invoice_id BIGINT REFERENCES invoices(id) ON DELETE CASCADE,
    allocated_amount NUMERIC NOT NULL              -- كم خُصص من هذه الدفعة لهذه الفاتورة بالتحديد
);

CREATE INDEX IF NOT EXISTS idx_payments_client_id ON payments(client_id);
CREATE INDEX IF NOT EXISTS idx_allocations_payment_id ON payment_invoice_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_allocations_invoice_id ON payment_invoice_allocations(invoice_id);
