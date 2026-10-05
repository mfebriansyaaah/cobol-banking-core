# Capability Map: Enterprise Banking Core Engine

| Module id | Responsibility | Depends on |
|---|---|---|
| iam-identity | Registration, 6-digit Verification, RBAC, Secure Login, C-Lib Hashing | — |
| core-ledger | Multi-currency, Atomic Transactions, Balance Mgmt, Row-Locking | iam-identity |
| fraud-compliance | Anti-Fraud Rules, Daily Limits, Audit Trail, Account Locking | iam-identity, core-ledger |
| reward-engine | Interest Accrual, Loyalty Points, Reward Logic | core-ledger |
| customer-engagement | Profile Mgmt, Internal Ticketing, Notification Queue | iam-identity |
| analytics-reporting | Financial Statements, User Stats, Data Export | core-ledger |
| api-gateway | Node.js Robust Pipe, JWT, Rate Limiting, Exit Code Mapping | All Modules |

Build order: iam-identity $\rightarrow$ core-ledger $\rightarrow$ fraud-compliance $\rightarrow$ reward-engine $\rightarrow$ customer-engagement $\rightarrow$ analytics-reporting $\rightarrow$ api-gateway
