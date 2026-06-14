ADMIN_MIGRATIONS_SQL = [
    """CREATE TABLE IF NOT EXISTS admin_templates (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        type VARCHAR(50) NOT NULL,
        name VARCHAR(255) NOT NULL,
        pattern TEXT,
        template TEXT,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );""",
    """CREATE TABLE IF NOT EXISTS payment_transactions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        student_id UUID REFERENCES students(id) ON DELETE SET NULL,
        phone_number VARCHAR(20),
        amount DECIMAL(10,2),
        method VARCHAR(20),
        reference TEXT,
        status VARCHAR(20) DEFAULT 'pending',
        matched_by VARCHAR(50),
        approved_at TIMESTAMPTZ,
        rejected_at TIMESTAMPTZ,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );""",
    """INSERT INTO admin_templates (type, name, pattern, template) VALUES 
    ('sms_regex', 'vodafone_cash', 'Vodafone Cash.*?(\\d{11}).*?(\\d+)\\.?\\d*\\s?(EGP|LE|ج\\.م)', '{"phone_group":1,"amount_group":2}'),
    ('sms_regex', 'instapay', 'InstaPay.*?(\\d{11}).*?(\\d+)\\.?\\d*\\s?(EGP|LE|ج\\.م)', '{"phone_group":1,"amount_group":2}'),
    ('notification', 'payment_approved', 'تم تأكيد الدفع', '✅ تم تأكيد الدفع بقيمة {amount} ج.م للطالب {student_name}'),
    ('notification', 'payment_rejected', 'تم رفض الدفع', '❌ تم رفض الدفع بقيمة {amount} ج.م للطالب {student_name}')
    ON CONFLICT DO NOTHING;""",
]
