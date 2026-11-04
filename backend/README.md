# AbroadMates API - Step 2

1. Start MySQL in XAMPP and import the Step 1 SQL script into phpMyAdmin (only if not already imported).
2. In phpMyAdmin select abroadmates_db and run database/06_auth_read_procedures.sql.
3. Open this folder in VS Code and run `npm install`.
4. Copy `.env.example` to `.env`; set your MySQL credentials and a random JWT_SECRET of 32+ characters.
5. Run `npm run dev`.

Endpoints:
- GET http://localhost:5000/
- GET http://localhost:5000/api/health
- POST http://localhost:5000/api/auth/register
- POST http://localhost:5000/api/auth/login

Register JSON:
{"fullName":"Sample Student","email":"student@example.com","password":"ChangeMe123!","role":"Student"}

Login JSON:
{"email":"student@example.com","password":"ChangeMe123!"}

All SELECTs in auth use stored procedures; user registration INSERT uses a parameterized query.
Never commit .env. Add rate limiting, stronger validation, email verification and production token protections before deployment.
