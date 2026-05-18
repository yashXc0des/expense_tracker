# Receipt Tracker — Backend Documentation

This document describes the backend service for the Camera-First Expense Tracker (receipt-tracker backend).
It covers prerequisites, environment variables, installation, running, API endpoints, authentication (JWT), image storage (Cloudflare R2), OCR microservice, testing, deployment notes, and troubleshooting.

---

## Table of Contents

- Overview
- Prerequisites
- Environment Variables
- Install & Run
- API Endpoints
  - Auth
  - Expenses
  - Journeys
  - Health
- Authentication Flow (JWT)
- Image Storage (Cloudflare R2)
- OCR Microservice
- Testing & Quick Commands
- Postman / Curl Examples
- Security & Best Practices
- Troubleshooting
- Useful Files

---

## Overview

The backend is an Express-based Node.js API that provides endpoints for user authentication, expense creation (with optional receipt images), and journey bundling.
Data is stored in MongoDB. Images are stored in Cloudflare R2 (S3-compatible). OCR is provided via a separate Python microservice (FastAPI) called by the backend.

---

## Prerequisites

- Node.js (v20+ recommended)
- npm
- MongoDB (Atlas or self-hosted)
- (Optional) Cloudflare account with R2 for image storage
- (Optional) Python + Tesseract + FastAPI for OCR microservice

---

## Environment Variables

Create a file `backend/.env` (do not commit to source control). The backend expects these variables:

- `PORT` — port for the API (default 3000)
- `NODE_ENV` — `development` or `production`

MongoDB
- `MONGO_URI` — MongoDB connection string (Atlas). Example:
  `mongodb+srv://<USERNAME>:<URL_ENCODED_PASSWORD>@<CLUSTER>.mongodb.net/receipt_tracker?retryWrites=true&w=majority&appName=receipt-tracker`
  Notes: include the DB name (`receipt_tracker`) and URL-encode passwords with special characters.

JWT
- `JWT_SECRET` — secret used to sign access tokens (keep secret)
- `JWT_EXPIRES_IN` — access token lifetime, e.g. `15m`
- `JWT_REFRESH_SECRET` — secret for refresh tokens (keep secret)
- `JWT_REFRESH_EXPIRES_IN` — refresh token lifetime, e.g. `30d`

Cloudflare R2 (optional)
- `R2_ACCOUNT_ID` — Cloudflare account id
- `R2_ACCESS_KEY_ID` — R2 access key id
- `R2_SECRET_ACCESS_KEY` — R2 secret
- `R2_BUCKET_NAME` — bucket name
- `R2_PUBLIC_DOMAIN` — optional CDN domain for public image URLs

OCR
- `OCR_SERVICE_URL` — URL for the OCR microservice (default: `http://localhost:8000`)

CORS
- `ALLOWED_ORIGINS` — comma-separated list of allowed origins for CORS

Example `.env` is included at `backend/.env.example` in repository.

---

## Install & Run

1. Install dependencies:

```bash
cd backend
npm install
```

2. Create `backend/.env` with the required variables.

3. Run the app (development with nodemon):

```bash
npm run dev
```

4. Production:

```bash
npm start
```

When successful, app logs:
```
MongoDB connected
Server running on port <PORT>
```

---

## API Endpoints

Base: `http://localhost:<PORT>/api` (default port 3000)

Auth
- `POST /api/auth/signup` — create user
  - Body: `{ email, password, name }`
  - Returns: `{ accessToken, refreshToken, user }

- `POST /api/auth/login` — sign-in
  - Body: `{ email, password }`
  - Returns: `{ accessToken, refreshToken, user }

- `POST /api/auth/refresh` — get new access token
  - Body: `{ refreshToken }`
  - Returns: `{ accessToken }

- `POST /api/auth/logout` — revoke refresh token (requires Authorization header with access token)
  - Body: `{ refreshToken }`

Expenses (`/api/expenses`) — all routes require `Authorization: Bearer <accessToken>`
- `POST /api/expenses` — create expense
  - Form fields: `amount`, `category`, `note`, `date`, `journeyId`, `latitude`, `longitude` and file field `receipt` for image
- `GET /api/expenses` — list expenses (supports `page`, `limit`, `category`, `journeyId`, `search`, `startDate`, `endDate` query params)
- `GET /api/expenses/summary` — daily/weekly/monthly totals
- `DELETE /api/expenses/:id` — soft-delete expense

Journeys (`/api/journeys`) — all routes require Authorization
- `POST /api/journeys` — create journey (`name`, `description`, `startDate`, `endDate`, `tags`)
- `GET /api/journeys` — list journeys (paged)
- `GET /api/journeys/:id` — journey details with associated expenses
- `PATCH /api/journeys/:id` — update journey
- `DELETE /api/journeys/:id` — soft-delete journey

Health
- `GET /health` — simple health check

---

## Authentication Flow (JWT)

- On signup/login the API returns `accessToken` and `refreshToken`.
- `accessToken` is short-lived and used in `Authorization: Bearer <token>` header for protected endpoints.
- `refreshToken` is long-lived. The backend stores a hashed version of the refresh token (in `User.refreshTokens`) for revocation.
- To obtain a new access token, call `POST /api/auth/refresh` with `{ refreshToken }`.
- To logout, call `POST /api/auth/logout` with `{ refreshToken }` and the Authorization header.

Security best practices: keep secrets in a secret manager, not in `.env` for production. Use HTTPS in production, use secure cookie storage for web apps, and secure key storage for mobile apps.

---

## Image Storage (Cloudflare R2)

- Images uploaded via `/api/expenses` are processed using `sharp` (resized/compressed) and uploaded to R2 using the AWS SDK client configured in `src/config/r2.js`.
- Public URL returned uses `R2_PUBLIC_DOMAIN` + key. If you don't configure R2, image upload calls will fail — you can make image upload optional in client testing.

R2 setup summary:
1. Create R2 bucket in Cloudflare
2. Create an API key (Access Key ID and Secret)
3. Set `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_DOMAIN` in `.env`.

---

## OCR Microservice

OCR is implemented as a separate Python service (FastAPI + OpenCV + Tesseract). Backend sends the receipt image to `OCR_SERVICE_URL` on `POST /extract` and receives parsed data.

You can run the OCR service locally (recommended for development) or deploy it separately.
See `ocr-service/` folder for example implementation and `requirements.txt`.

---

## Testing & Quick Commands

- MongoDB connectivity test:
```bash
node scripts/test-mongo-connection.js
```

- JWT sanity check (sign & verify):
```bash
node -e "require('dotenv').config(); const jwt=require('jsonwebtoken'); const t=jwt.sign({sub:'env-test'}, process.env.JWT_SECRET, {expiresIn:process.env.JWT_EXPIRES_IN||'15m'}); const d=jwt.verify(t, process.env.JWT_SECRET); console.log('JWT_OK', !!d.sub);"
```

- Run dev server (nodemon):
```bash
npm run dev
```

---

## Postman / Curl Examples

Health:
```bash
curl http://localhost:3000/health
```

Signup / Login examples:
```bash
curl -X POST http://localhost:3000/api/auth/signup -H "Content-Type: application/json" -d '{"email":"you@example.com","password":"Password123!","name":"You"}'

curl -X POST http://localhost:3000/api/auth/login  -H "Content-Type: application/json" -d '{"email":"you@example.com","password":"Password123!"}'
```

Create expense (no image):
```bash
curl -X POST http://localhost:3000/api/expenses -H "Authorization: Bearer <ACCESS_TOKEN>" -F "amount=12.50" -F "category=Food" -F "note=Lunch"
```

Create expense (with image):
```bash
curl -X POST http://localhost:3000/api/expenses -H "Authorization: Bearer <ACCESS_TOKEN>" -F "amount=45.00" -F "category=Travel" -F "receipt=@/path/to/receipt.jpg"
```

---

## Security & Best Practices

- Use short access token TTL and rotate refresh tokens on use.
- Store refresh tokens hashed (already implemented).
- Rotate credentials exposed in logs or chat immediately.
- Run the backend behind HTTPS and configure appropriate CORS.
- Use environment-specific configuration and Secret Manager for production.

---

## Troubleshooting

- `MongoServerError: bad auth` — check `MONGO_URI`, username, password, IP whitelist, and URL-encode password.
- `OCR service unavailable` — ensure `OCR_SERVICE_URL` is reachable; backend logs a warning and continues without blocking expense creation if OCR fails.
- Image upload errors — validate R2 env variables, bucket permissions, and ensure `R2_PUBLIC_DOMAIN` is set if expecting public CDN URLs.

---

## Useful Files

- `backend/src/app.js` — application entry
- `backend/src/routes/*` — route definitions
- `backend/src/controllers/*` — controller logic
- `backend/src/services/r2.service.js` — image upload logic
- `backend/scripts/test-mongo-connection.js` — Mongo connectivity test
- `backend/.env.example` — environment template

---

If you want, I can also:
- generate a Postman collection for these routes,
- add an OpenAPI/Swagger endpoint,
- scaffold CI/CD deployment files (Dockerfile, docker-compose, or GitHub Actions).

