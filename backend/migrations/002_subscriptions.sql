-- Migration 002: Subscription System
-- Creates subscription_plans, subscription_codes, and teacher_subscriptions tables

CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    price_egp DECIMAL(10, 2) NOT NULL,
    max_students INTEGER NOT NULL DEFAULT 50,
    max_ai_requests INTEGER NOT NULL DEFAULT 100,
    max_grades INTEGER DEFAULT NULL,
    max_invoices INTEGER DEFAULT NULL,
    features_json JSONB NOT NULL DEFAULT '[]',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscription_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(19) NOT NULL UNIQUE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    used_by_teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
    used_at TIMESTAMPTZ DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS teacher_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
    code_id UUID REFERENCES subscription_codes(id) ON DELETE SET NULL,
    activated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(teacher_id)
);

CREATE INDEX IF NOT EXISTS idx_subscription_codes_code ON subscription_codes(code);
CREATE INDEX IF NOT EXISTS idx_subscription_codes_plan_id ON subscription_codes(plan_id);
CREATE INDEX IF NOT EXISTS idx_teacher_subscriptions_teacher_id ON teacher_subscriptions(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_subscriptions_plan_id ON teacher_subscriptions(plan_id);

-- Insert default plans
INSERT INTO subscription_plans (name, price_egp, max_students, max_ai_requests, max_grades, max_invoices, features_json) VALUES
('Basic', 199.00, 50, 100, NULL, NULL, '["student_management", "attendance_tracking", "basic_reports"]'),
('Pro', 499.00, 500, 500, NULL, NULL, '["student_management", "attendance_tracking", "advanced_reports", "ai_analysis", "bulk_operations", "export_pdf"]'),
('Unlimited', 999.00, -1, 2000, NULL, NULL, '["student_management", "attendance_tracking", "advanced_reports", "ai_analysis", "bulk_operations", "export_pdf", "priority_support", "custom_branding", "api_access"]')
ON CONFLICT DO NOTHING;
