# Spec: api-gateway

## Objective
Implement the "Robust Pipe" middleware using Node.js Express. This module acts as the exclusive interface between the public internet and the COBOL business logic. Its sole responsibility is to secure, transport, and translate data without implementing any business rules.

## Tech Stack
- **Framework:** Node.js Express
- **Authentication:** JSON Web Tokens (JWT)
- **Execution:** `child_process.exec` (CLI Call)
- **Validation:** Strict Regular Expressions (Regex)
- **Environment:** `dotenv` for configuration

## Commands
- **Install:** `npm install`
- **Dev:** `npm run dev`
- **Build:** `npm run build`
- **Test:** `npm test`

## Project Structure
- `middleware/src/app.js` $\rightarrow$ Express server setup
- `middleware/src/routes/api.js` $\rightarrow$ Route definitions and JWT middleware
- `middleware/src/controllers/cobolController.js` $\rightarrow$ CLI execution, Regex validation, and Exit Code translation
- `middleware/.env` $\rightarrow$ Binary paths, JWT secrets, and Port settings

## Code Style
- **Pass-through Logic:** No business logic allowed in JS. Only transport and translation.
- **Response Format:** Always return JSON: `{ "data": ... }` or `{ "error": "..." }`.
- **Security:** Use a whitelist-based Regex for all CLI arguments to prevent Command Injection.
- **Example Flow:** `HTTP Request` $\rightarrow$ `JWT Check` $\rightarrow$ `Regex Validate` $\rightarrow$ `COBOL Exec` $\rightarrow$ `Exit Code Mapping` $\rightarrow$ `HTTP Response`.

## Testing Strategy
- **Injection Test:** Attempting to send `; rm -rf /` as a parameter to ensure Regex blocks it.
- **Token Test:** Requesting protected routes without a JWT or with an expired token.
- **Timeout Test:** Mocking a slow COBOL process to verify the 504 Gateway Timeout.
- **Contract Test:** Verifying that COBOL Exit Code 1 results in HTTP 404.

## Boundaries
- **Always:** Validate JWT for any route except `/auth/signup` and `/auth/login`.
- **Ask first:** Adding new middleware or changing the JWT secret rotation policy.
- **Never:** Write SQL queries directly in Node.js. Never implement business logic in JavaScript.

## Success Criteria
- [ ] Every request to a protected route requires a valid JWT.
- [ ] All input parameters are validated against a strict Regex whitelist.
- [ ] COBOL Exit Codes are correctly mapped to HTTP status codes.
- [ ] Pipe-delimited output from COBOL is correctly converted to JSON.
- [ ] Slow COBOL processes are terminated by a timeout to prevent server hang.

## Open Questions
- What is the desired JWT expiration time (e.g., 24 hours or 30 days)?
