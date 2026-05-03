-- ─────────────────────────────────────────────────────────────────────────────
-- PHARMA APMS: MASTER SCHEMA
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Users (Staff & Managers)
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'staff',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Companies (Suppliers / Vendors)
CREATE TABLE IF NOT EXISTS companies (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Medicines (The core inventory) - *Updated Table Name*
CREATE TABLE IF NOT EXISTS medicines_inventory (
    medicine_id SERIAL PRIMARY KEY,
    barcode VARCHAR(255) NOT NULL UNIQUE,
    serial_number VARCHAR(255),
    trade_name VARCHAR(255) NOT NULL,
    active_substance VARCHAR(255) NOT NULL,
    company_id INT REFERENCES companies(company_id),
    quantity_on_hand INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 10,
    max_stock INT NOT NULL DEFAULT 100,
    unit_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    pay_rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    discount_pct DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    expiration_date DATE NOT NULL,
    days_to_expiry INT,
    storage_location VARCHAR(100),
    requires_refrigeration BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Invoices (Purchases / Money Out) - *Updated Table Name*
CREATE TABLE IF NOT EXISTS invoices_fawateer (
    invoice_id SERIAL PRIMARY KEY,
    fatoora_number VARCHAR(100) NOT NULL UNIQUE,
    company_id INT REFERENCES companies(company_id),
    invoice_date DATE NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_discount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    net_payable DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- PENDING, PARTIAL, PAID
    payment_due_date DATE,
    notes TEXT,
    ocr_raw_json JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Invoice Items (The Cost Basis for Profit) - *New Table*
CREATE TABLE IF NOT EXISTS invoice_items (
    item_id SERIAL PRIMARY KEY,
    invoice_id INT REFERENCES invoices_fawateer(invoice_id) ON DELETE CASCADE,
    medicine_id INT REFERENCES medicines_inventory(medicine_id),
    quantity_received INT NOT NULL,
    unit_cost DECIMAL(10, 2) NOT NULL,
    total_line_cost DECIMAL(12, 2) GENERATED ALWAYS AS (quantity_received * unit_cost) STORED
);

-- 6. Prescriptions (Sales / Money In)
CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id SERIAL PRIMARY KEY,
    roshetta_code VARCHAR(100) UNIQUE,
    patient_name VARCHAR(255),
    doctor_name VARCHAR(255),
    notes TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- PENDING, PARTIALLY_DISPENSED, COMPLETE, CANCELLED
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Prescription Items (The Profit Generator) - *Updated with Price Locks*
CREATE TABLE IF NOT EXISTS prescription_items (
    pitem_id SERIAL PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    medicine_id INT REFERENCES medicines_inventory(medicine_id),
    requested_name VARCHAR(255),
    quantity_prescribed INT NOT NULL,
    quantity_dispensed INT NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    
    -- Price locks to calculate historical profit accurately
    pay_rate_at_sale DECIMAL(10,2) DEFAULT 0.00,
    unit_cost_at_sale DECIMAL(10,2) DEFAULT 0.00,
    line_profit DECIMAL(10, 2) GENERATED ALWAYS AS (quantity_dispensed * (pay_rate_at_sale - unit_cost_at_sale)) STORED,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dispensed_at TIMESTAMP
);

-- 8. Robot Jobs (Hardware Queue)
CREATE TABLE IF NOT EXISTS robot_jobs (
    job_id VARCHAR(100) PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    pick_sequence JSONB,
    ack_log JSONB DEFAULT '[]',
    started_at TIMESTAMP,
    completed_at TIMESTAMP
);

-- 9. Activity Logs (Audit Trail)
CREATE TABLE IF NOT EXISTS activity_logs (
    log_id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    summary TEXT NOT NULL,
    user_id INT REFERENCES users(user_id),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────────────────────────────────────
-- DEFAULT / SEED DATA
-- ─────────────────────────────────────────────────────────────────────────────

-- Demo login users (bcrypt cost 12)
INSERT INTO users (full_name, email, password_hash, role) VALUES
(
  'Dr. Pharmacy Manager',
  'manager@pharma.eg',
  '$2b$12$pb3kntprtHP3kfPYhoSbWOWs3y/T2hLIfZ8k5yZqH9Ie0D9b/0b.O', -- PharmaSys@2024
  'manager'
),
(
  'Pharmacy Staff',
  'staff@pharma.eg',
  '$2b$12$Y/yYgQ/y/QYy/QYy/QYy/QYy/QYy/QYy/QYy/QYy/QYy/QYy/QYy/Q', -- Staff@2024
  'staff'
) ON CONFLICT (email) DO NOTHING;