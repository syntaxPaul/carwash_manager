const List<String> migrations = [
  // v1 - initial tables
  '''
  CREATE TABLE services (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    price REAL NOT NULL
  );
  ''',
  '''
  CREATE TABLE employees (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT
  );
  ''',
  '''
  CREATE TABLE washes (
    id TEXT PRIMARY KEY,
    ts INTEGER NOT NULL, -- millisecondsSinceEpoch
    service_id TEXT,
    service_name TEXT NOT NULL,
    price REAL NOT NULL,
    payment_method TEXT NOT NULL, -- cash/card/eft/mobile
    employee_id TEXT,
    employee_name TEXT,
    notes TEXT,
    FOREIGN KEY(service_id) REFERENCES services(id),
    FOREIGN KEY(employee_id) REFERENCES employees(id)
  );
  ''',
  '''
  CREATE TABLE expenses (
    id TEXT PRIMARY KEY,
    ts INTEGER NOT NULL,
    category TEXT NOT NULL,
    amount REAL NOT NULL,
    notes TEXT
  );
  ''',
  // v5 - app settings key-value store
  '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );
  ''',
  // v6 - index for washes(ts)
  '''
  CREATE INDEX IF NOT EXISTS idx_washes_ts ON washes(ts);
  ''',
  // v7 - index for expenses(ts)
  '''
  CREATE INDEX IF NOT EXISTS idx_expenses_ts ON expenses(ts);
  ''',
  // v8 - customer side: carwashes registry
  '''
  CREATE TABLE carwashes (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    lat REAL NOT NULL,
    lng REAL NOT NULL,
    address TEXT,
    phone TEXT,
    open_hours TEXT,
    services_json TEXT
  );
  ''',
  // v9 - customer side: bookings
  '''
  CREATE TABLE bookings (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    carwash_id TEXT NOT NULL,
    ts_created INTEGER NOT NULL,
    appt_ts INTEGER NOT NULL,
    customer_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    vehicle TEXT,
    service TEXT,
    price REAL,
    status TEXT NOT NULL, -- pending/confirmed/in_progress/completed/cancelled
    notes TEXT,
    FOREIGN KEY(carwash_id) REFERENCES carwashes(id)
  );
  ''',
  // v10 - indexes for bookings
  '''
  CREATE INDEX IF NOT EXISTS idx_bookings_carwash ON bookings(carwash_id);
  CREATE INDEX IF NOT EXISTS idx_bookings_code ON bookings(code);
  ''',
  // v11 - daily cash-up records
  '''
  CREATE TABLE cashups (
    id TEXT PRIMARY KEY,
    ymd TEXT NOT NULL, -- yyyy-MM-dd
    ts_created INTEGER NOT NULL,
    income_cash REAL NOT NULL DEFAULT 0,
    income_card REAL NOT NULL DEFAULT 0,
    income_eft REAL NOT NULL DEFAULT 0,
    income_mobile REAL NOT NULL DEFAULT 0,
    expenses REAL NOT NULL DEFAULT 0,
    counted_cash REAL,
    counted_card REAL,
    counted_eft REAL,
    counted_mobile REAL,
    notes TEXT,
    signed_by TEXT
  );
  ''',
  // v12 - track booking source (app vs walk-in)
  '''
  ALTER TABLE bookings ADD COLUMN source TEXT NOT NULL DEFAULT 'app';
  ''',
  // v13 - customer accounts for login/profile management
  '''
  CREATE TABLE customers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    email TEXT,
    pin_hash TEXT NOT NULL,
    created_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
  ''',
  // v14 - link bookings to customers
  '''
  ALTER TABLE bookings ADD COLUMN customer_id TEXT;
  CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
  ''',
  // v15 - loyalty punches recorded per completed wash
  '''
  CREATE TABLE loyalty_punches (
    id TEXT PRIMARY KEY,
    booking_id TEXT NOT NULL UNIQUE,
    customer_id TEXT NOT NULL,
    carwash_id TEXT NOT NULL,
    ts INTEGER NOT NULL,
    FOREIGN KEY(customer_id) REFERENCES customers(id),
    FOREIGN KEY(carwash_id) REFERENCES carwashes(id),
    FOREIGN KEY(booking_id) REFERENCES bookings(id)
  );
  CREATE INDEX IF NOT EXISTS idx_loyalty_customer ON loyalty_punches(customer_id);
  ''',
  // v16 - record loyalty redemptions (free washes)
  '''
  CREATE TABLE loyalty_redemptions (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    carwash_id TEXT NOT NULL,
    ts INTEGER NOT NULL,
    notes TEXT,
    FOREIGN KEY(customer_id) REFERENCES customers(id),
    FOREIGN KEY(carwash_id) REFERENCES carwashes(id)
  );
  CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_customer ON loyalty_redemptions(customer_id);
  ''',
  // v17 - customer reviews/ratings per carwash
  '''
  CREATE TABLE reviews (
    id TEXT PRIMARY KEY,
    carwash_id TEXT NOT NULL,
    customer_id TEXT,
    customer_name TEXT,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    ts INTEGER NOT NULL,
    FOREIGN KEY(carwash_id) REFERENCES carwashes(id),
    FOREIGN KEY(customer_id) REFERENCES customers(id)
  );
  CREATE INDEX IF NOT EXISTS idx_reviews_carwash_ts ON reviews(carwash_id, ts DESC);
  ''',
  // v18 - vehicle profiles per customer
  '''
  CREATE TABLE vehicles (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    make TEXT,
    model TEXT,
    year INTEGER,
    license_plate TEXT,
    color TEXT,
    preferred_service TEXT,
    created_ts INTEGER NOT NULL,
    FOREIGN KEY(customer_id) REFERENCES customers(id)
  );
  CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON vehicles(customer_id);
  ''',
  // v19 - queue metrics per carwash
  '''
  ALTER TABLE carwashes ADD COLUMN queue_length INTEGER;
  ALTER TABLE carwashes ADD COLUMN avg_wash_mins INTEGER;
  ''',
  // v20 - sync status for bookings (offline queue)
  '''
  ALTER TABLE bookings ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';
  ''',
  // v21 - link vehicles to a preferred carwash
  '''
  ALTER TABLE vehicles ADD COLUMN carwash_id TEXT;
  CREATE INDEX IF NOT EXISTS idx_vehicles_carwash ON vehicles(carwash_id);
  ''',
  // v22 - chart of accounts
  '''
  CREATE TABLE ledger_accounts (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- asset/liability/equity/income/expense
    subtype TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    is_system INTEGER NOT NULL DEFAULT 0,
    created_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_ledger_accounts_type ON ledger_accounts(type);
  ''',
  // v23 - journal headers and lines (double-entry)
  '''
  CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY,
    txn_ts INTEGER NOT NULL,
    txn_date TEXT NOT NULL, -- yyyy-MM-dd
    description TEXT NOT NULL,
    source_type TEXT,
    source_id TEXT,
    created_ts INTEGER NOT NULL
  );
  CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_source
    ON journal_entries(source_type, source_id)
    WHERE source_type IS NOT NULL AND source_id IS NOT NULL;

  CREATE TABLE journal_lines (
    id TEXT PRIMARY KEY,
    entry_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    memo TEXT,
    debit REAL NOT NULL DEFAULT 0,
    credit REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(entry_id) REFERENCES journal_entries(id),
    FOREIGN KEY(account_id) REFERENCES ledger_accounts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_lines(entry_id);
  CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_id);
  ''',
  // v24 - extend operational tables with accounting linkage and payable metadata
  '''
  ALTER TABLE washes ADD COLUMN ledger_entry_id TEXT;

  ALTER TABLE expenses ADD COLUMN ledger_entry_id TEXT;
  ALTER TABLE expenses ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash';
  ALTER TABLE expenses ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'paid'; -- paid/due
  ALTER TABLE expenses ADD COLUMN due_ts INTEGER;
  ALTER TABLE expenses ADD COLUMN vendor_name TEXT;
  ALTER TABLE expenses ADD COLUMN linked_bill_id TEXT;
  ''',
  // v25 - bookkeeping contacts
  '''
  CREATE TABLE accounting_contacts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- customer/vendor/both
    phone TEXT,
    email TEXT,
    tax_no TEXT,
    created_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_accounting_contacts_name ON accounting_contacts(name);
  CREATE INDEX IF NOT EXISTS idx_accounting_contacts_type ON accounting_contacts(type);
  ''',
  // v26 - accounts receivable invoices
  '''
  CREATE TABLE sales_invoices (
    id TEXT PRIMARY KEY,
    invoice_no TEXT NOT NULL UNIQUE,
    contact_id TEXT NOT NULL,
    issue_ts INTEGER NOT NULL,
    due_ts INTEGER,
    status TEXT NOT NULL, -- sent/partially_paid/paid/void
    subtotal REAL NOT NULL,
    tax REAL NOT NULL DEFAULT 0,
    total REAL NOT NULL,
    balance REAL NOT NULL,
    notes TEXT,
    ledger_entry_id TEXT,
    FOREIGN KEY(contact_id) REFERENCES accounting_contacts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_sales_invoices_status ON sales_invoices(status);
  CREATE INDEX IF NOT EXISTS idx_sales_invoices_due ON sales_invoices(due_ts);

  CREATE TABLE sales_invoice_lines (
    id TEXT PRIMARY KEY,
    invoice_id TEXT NOT NULL,
    description TEXT NOT NULL,
    qty REAL NOT NULL DEFAULT 1,
    unit_price REAL NOT NULL,
    tax_rate REAL NOT NULL DEFAULT 0,
    line_total REAL NOT NULL,
    FOREIGN KEY(invoice_id) REFERENCES sales_invoices(id)
  );
  CREATE INDEX IF NOT EXISTS idx_sales_invoice_lines_invoice ON sales_invoice_lines(invoice_id);
  ''',
  // v27 - accounts payable vendor bills
  '''
  CREATE TABLE vendor_bills (
    id TEXT PRIMARY KEY,
    bill_no TEXT NOT NULL UNIQUE,
    contact_id TEXT NOT NULL,
    issue_ts INTEGER NOT NULL,
    due_ts INTEGER,
    status TEXT NOT NULL, -- open/partially_paid/paid/void
    subtotal REAL NOT NULL,
    tax REAL NOT NULL DEFAULT 0,
    total REAL NOT NULL,
    balance REAL NOT NULL,
    notes TEXT,
    ledger_entry_id TEXT,
    FOREIGN KEY(contact_id) REFERENCES accounting_contacts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_vendor_bills_status ON vendor_bills(status);
  CREATE INDEX IF NOT EXISTS idx_vendor_bills_due ON vendor_bills(due_ts);

  CREATE TABLE vendor_bill_lines (
    id TEXT PRIMARY KEY,
    bill_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    description TEXT NOT NULL,
    qty REAL NOT NULL DEFAULT 1,
    unit_cost REAL NOT NULL,
    tax_rate REAL NOT NULL DEFAULT 0,
    line_total REAL NOT NULL,
    FOREIGN KEY(bill_id) REFERENCES vendor_bills(id),
    FOREIGN KEY(account_id) REFERENCES ledger_accounts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_vendor_bill_lines_bill ON vendor_bill_lines(bill_id);
  ''',
  // v28 - payment register
  '''
  CREATE TABLE payments (
    id TEXT PRIMARY KEY,
    payment_no TEXT NOT NULL UNIQUE,
    ts INTEGER NOT NULL,
    contact_id TEXT,
    direction TEXT NOT NULL, -- in/out
    method TEXT NOT NULL, -- cash/card/eft/mobile/bank
    amount REAL NOT NULL,
    reference TEXT,
    notes TEXT,
    invoice_id TEXT,
    bill_id TEXT,
    ledger_entry_id TEXT,
    FOREIGN KEY(contact_id) REFERENCES accounting_contacts(id),
    FOREIGN KEY(invoice_id) REFERENCES sales_invoices(id),
    FOREIGN KEY(bill_id) REFERENCES vendor_bills(id)
  );
  CREATE INDEX IF NOT EXISTS idx_payments_ts ON payments(ts DESC);
  CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
  CREATE INDEX IF NOT EXISTS idx_payments_bill ON payments(bill_id);
  ''',
  // v29 - cash/bank transaction register
  '''
  CREATE TABLE bank_accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    account_no TEXT,
    is_default INTEGER NOT NULL DEFAULT 0,
    opening_balance REAL NOT NULL DEFAULT 0,
    created_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_bank_accounts_default ON bank_accounts(is_default);

  CREATE TABLE bank_transactions (
    id TEXT PRIMARY KEY,
    bank_account_id TEXT,
    ts INTEGER NOT NULL,
    direction TEXT NOT NULL, -- in/out
    amount REAL NOT NULL,
    method TEXT NOT NULL, -- cash/card/eft/mobile/bank
    description TEXT NOT NULL,
    source_type TEXT,
    source_id TEXT,
    reconciled INTEGER NOT NULL DEFAULT 0,
    created_ts INTEGER NOT NULL,
    FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_bank_tx_ts ON bank_transactions(ts DESC);
  CREATE INDEX IF NOT EXISTS idx_bank_tx_source ON bank_transactions(source_type, source_id);
  ''',
  // v30 - bookkeeping automation metadata and monthly close snapshots
  '''
  CREATE TABLE automation_runs (
    id TEXT PRIMARY KEY,
    ts INTEGER NOT NULL,
    summary_json TEXT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_automation_runs_ts ON automation_runs(ts DESC);

  CREATE TABLE expense_rules (
    id TEXT PRIMARY KEY,
    keyword TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    payment_method TEXT,
    priority INTEGER NOT NULL DEFAULT 100,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_expense_rules_priority ON expense_rules(priority ASC);

  CREATE TABLE monthly_closes (
    id TEXT PRIMARY KEY,
    yyyymm TEXT NOT NULL UNIQUE,
    period_start_ts INTEGER NOT NULL,
    period_end_ts INTEGER NOT NULL,
    income REAL NOT NULL DEFAULT 0,
    expenses REAL NOT NULL DEFAULT 0,
    profit REAL NOT NULL DEFAULT 0,
    vat_output REAL NOT NULL DEFAULT 0,
    vat_input REAL NOT NULL DEFAULT 0,
    vat_due REAL NOT NULL DEFAULT 0,
    open_ar REAL NOT NULL DEFAULT 0,
    open_ap REAL NOT NULL DEFAULT 0,
    generated_ts INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_monthly_closes_period ON monthly_closes(yyyymm DESC);
  ''',
  // v31 - link completed bookings to recorded washes
  '''
  ALTER TABLE washes ADD COLUMN booking_id TEXT;
  CREATE UNIQUE INDEX IF NOT EXISTS idx_washes_booking ON washes(booking_id);
  ''',
  // v32 - track booking payment method for walk-ins/completions
  '''
  ALTER TABLE bookings ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash';
  ''',
  // v33 - capture vehicle details on wash records
  '''
  ALTER TABLE washes ADD COLUMN vehicle TEXT;
  ALTER TABLE washes ADD COLUMN license_plate TEXT;
  ''',
  // v34 - assign employees to bookings before completion
  '''
  ALTER TABLE bookings ADD COLUMN employee_id TEXT;
  ALTER TABLE bookings ADD COLUMN employee_name TEXT;
  ''',
  // v35 - capture booking plate separately from vehicle description
  '''
  ALTER TABLE bookings ADD COLUMN license_plate TEXT;
  ''',
  // v36 - manager accounts, sessions and trial access
  '''
  CREATE TABLE manager_accounts (
    id TEXT PRIMARY KEY,
    business_name TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    trial_start_ts INTEGER NOT NULL,
    trial_end_ts INTEGER NOT NULL,
    subscription_status TEXT NOT NULL DEFAULT 'trialing',
    subscription_source TEXT NOT NULL DEFAULT 'local_trial',
    created_ts INTEGER NOT NULL,
    last_login_ts INTEGER
  );
  CREATE INDEX IF NOT EXISTS idx_manager_accounts_email
    ON manager_accounts(email);
  CREATE INDEX IF NOT EXISTS idx_manager_accounts_status
    ON manager_accounts(subscription_status);
  ''',
  // v37 - store purchase metadata for subscription activation
  '''
  ALTER TABLE manager_accounts ADD COLUMN subscription_product_id TEXT;
  ALTER TABLE manager_accounts ADD COLUMN subscription_purchase_id TEXT;
  ALTER TABLE manager_accounts ADD COLUMN subscription_verification_data TEXT;
  ALTER TABLE manager_accounts ADD COLUMN subscription_updated_ts INTEGER;

  CREATE TABLE subscription_events (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    purchase_id TEXT,
    verification_source TEXT NOT NULL,
    verification_data TEXT NOT NULL,
    status TEXT NOT NULL,
    event_ts INTEGER NOT NULL,
    FOREIGN KEY(account_id) REFERENCES manager_accounts(id)
  );
  CREATE INDEX IF NOT EXISTS idx_subscription_events_account
    ON subscription_events(account_id, event_ts DESC);
  ''',
  // v38 - track loyalty by vehicle number plate
  '''
  ALTER TABLE loyalty_punches ADD COLUMN plate_key TEXT;
  ALTER TABLE loyalty_punches ADD COLUMN display_plate TEXT;
  CREATE INDEX IF NOT EXISTS idx_loyalty_plate
    ON loyalty_punches(plate_key, carwash_id);

  ALTER TABLE loyalty_redemptions ADD COLUMN plate_key TEXT;
  ALTER TABLE loyalty_redemptions ADD COLUMN display_plate TEXT;
  CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_plate
    ON loyalty_redemptions(plate_key, carwash_id);
  ''',
];
