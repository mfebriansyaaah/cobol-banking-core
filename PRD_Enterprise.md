# PRD: Enterprise Banking Core Engine (Secure COBOL Ecosystem)

## 1. Product Vision
Membangun sistem inti perbankan (Core Banking Engine) skala enterprise yang mengutamakan integritas data finansial absolut dan keamanan tingkat tinggi. Sistem ini menerapkan paradigma "Logic Sovereignty", di mana seluruh kompleksitas bisnis, aturan kepatuhan (compliance), dan perhitungan finansial dipusatkan di dalam COBOL, dengan Node.js sebagai interface transport yang aman.

## 2. Enterprise Capability Map

| Module ID | Responsibility | Priority | Complexity |
| :--- | :--- | :---: | :---: |
| `iam-identity` | Registrasi, Verifikasi Email, RBAC, Secure Login, Password Hashing | High | Medium |
| `core-ledger` | Multi-currency, Atomic Transactions, Balance Mgmt, Row-Locking | High | High |
| `fraud-compliance`| Anti-Fraud Rules, Daily Limits, Audit Trail, Account Locking | High | High |
| `reward-engine` | Interest Calculation, Loyalty Points, Rewards Logic | Medium | Medium |
| `customer-engagement`| Profile Mgmt, Internal Ticketing, Notification Queue | Medium | Medium |
| `analytics-reporting`| Financial Statements, User Stats, Data Export | Low | Medium |
| `api-gateway` | Node.js Robust Pipe, JWT, Rate Limiting, Exit Code Mapping | High | Medium |

**Build Order:** `iam-identity` $\rightarrow$ `core-ledger` $\rightarrow$ `fraud-compliance` $\rightarrow$ `reward-engine` $\rightarrow$ `customer-engagement` $\rightarrow$ `analytics-reporting` $\rightarrow$ `api-gateway`.

## 3. Functional Requirements (Detailed)

### A. IAM Identity (Identity & Access Management)
- **Strict Sign-Up**: Verifikasi email 6-digit, Hashing password via C-Lib.
- **RBAC (Role Based Access Control)**: Pembedaan hak akses antara `USER`, `MANAGER`, dan `SUPER_ADMIN`.
- **Secure Session**: Validasi status `VERIFIED` sebelum login.

### B. Core Ledger (The Heart of Finance)
- **Multi-Currency**: Dukungan berbagai mata uang dengan tabel kurs (Exchange Rate) dinamis.
- **Atomic Transaction**: Implementasi `BEGIN`, `COMMIT`, `ROLLBACK` untuk menjamin saldo.
- **Immutable Ledger**: Setiap perubahan saldo wajib memiliki entry ledger yang tidak bisa diubah.
- **Concurrency Control**: Row-level locking untuk mencegah double-spending.

### C. Fraud & Compliance (Security Layer)
- **Fraud Detection**: Deteksi pola transaksi mencurigakan (misal: volume tinggi dalam waktu singkat).
- **Hard Limits**: Batasan transaksi harian/bulanan per level user.
- **Full Audit Trail**: Logging setiap aksi sensitif (Siapa, Kapan, Apa, Hasilnya).

### D. Reward & Interest Engine
- **Interest Accrual**: Perhitungan bunga tabungan harian secara otomatis.
- **Loyalty System**: Pemberian poin reward berdasarkan volume transaksi.

### E. Customer Engagement
- **Strict Profile Mgmt**: Update email dengan verifikasi 2-tahap.
- **Internal Ticketing**: Sistem pengaduan user yang diproses oleh admin.

### F. Analytics & Reporting
- **Financial Statements**: Pembuatan laporan laba/rugi dan neraca saldo.
- **User Analytics**: Statistik penggunaan aplikasi dan perilaku transaksi.

### G. API Gateway (The Robust Pipe)
- **Security**: Strict Regex Validation, JWT Management.
- **Reliability**: Timeout mechanism, Error translation (Exit Code $\rightarrow$ HTTP).

## 4. Non-Functional Requirements (Target: 100k+ LOC)
- **Security**: Password hashing (Bcrypt/Argon2), SQL Injection prevention.
- **Reliability**: Zero data loss during system crash.
- **Auditability**: Every cent must be traceable in the ledger.
- **Verifiability**: Every module must have a comprehensive test suite.

## 5. Success Criteria (The "Absolute" Bar)
- [ ] Zero balance inconsistency between `users` table and `ledger` table.
- [ ] No unverified user can perform any transaction.
- [ ] Fraud rules successfully block suspicious transactions.
- [ ] API returns standard HTTP status based on COBOL's business logic exit codes.
- [ ] Full project history exceeds 1,000 commits and 50+ merged PRs.
