# SpendSense API Documentation

This document provides detailed API documentation for the SpendSense backend. Note that the frontend primarily uses local storage (Hive), but the backend API is available for optional features and future cloud sync capabilities.

## Base URL

```
http://localhost:5000/api
```

For Android Emulator:
```
http://10.0.2.2:5000/api
```

For iOS Simulator:
```
http://localhost:5000/api
```

For Physical Device:
```
http://<your-computer-ip>:5000/api
```

## Authentication

Most endpoints require authentication using JWT tokens. Include the token in the Authorization header:

```
Authorization: Bearer <token>
```

## Endpoints

### Authentication

#### Register User

Create a new user account.

**Endpoint:** `POST /api/auth/register`

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (201 Created):**
```json
{
  "token": "jwt-token-here",
  "user": {
    "_id": "user-id",
    "name": "username",
    "email": "",
    "currency": "R",
    "monthlyBudget": 0
  }
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input or username already exists
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "securepassword123"
  }'
```

---

#### Login User

Authenticate and receive JWT token.

**Endpoint:** `POST /api/auth/login`

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200 OK):**
```json
{
  "token": "jwt-token-here",
  "user": {
    "_id": "user-id",
    "name": "username",
    "email": "",
    "currency": "R",
    "monthlyBudget": 0
  }
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input
- `401 Unauthorized`: Invalid credentials
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "securepassword123"
  }'
```

---

### Transactions

#### Get All Transactions

Retrieve all transactions for the authenticated user.

**Endpoint:** `GET /api/transactions`

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `type` (optional): Filter by type (`income` or `expense`)
- `startDate` (optional): ISO 8601 date string
- `endDate` (optional): ISO 8601 date string

**Response (200 OK):**
```json
[
  {
    "_id": "transaction-id",
    "userId": "user-id",
    "amount": 150.50,
    "type": "expense",
    "category": "Food",
    "description": "Grocery shopping",
    "date": "2024-01-15T10:30:00.000Z",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:30:00.000Z"
  }
]
```

**Error Responses:**
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X GET http://localhost:5000/api/transactions \
  -H "Authorization: Bearer <token>"
```

---

#### Create Transaction

Create a new transaction.

**Endpoint:** `POST /api/transactions`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "amount": 150.50,
  "type": "expense",
  "category": "Food",
  "description": "Grocery shopping",
  "date": "2024-01-15T10:30:00.000Z"
}
```

**Response (201 Created):**
```json
{
  "_id": "transaction-id",
  "userId": "user-id",
  "amount": 150.50,
  "type": "expense",
  "category": "Food",
  "description": "Grocery shopping",
  "date": "2024-01-15T10:30:00.000Z",
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input or validation error
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X POST http://localhost:5000/api/transactions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 150.50,
    "type": "expense",
    "category": "Food",
    "description": "Grocery shopping",
    "date": "2024-01-15T10:30:00.000Z"
  }'
```

---

#### Update Transaction

Update an existing transaction.

**Endpoint:** `PUT /api/transactions/:id`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**URL Parameters:**
- `id`: Transaction ID

**Request Body:**
```json
{
  "amount": 200.00,
  "type": "expense",
  "category": "Food",
  "description": "Updated description",
  "date": "2024-01-15T10:30:00.000Z"
}
```

**Response (200 OK):**
```json
{
  "_id": "transaction-id",
  "userId": "user-id",
  "amount": 200.00,
  "type": "expense",
  "category": "Food",
  "description": "Updated description",
  "date": "2024-01-15T10:30:00.000Z",
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T11:00:00.000Z"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input
- `401 Unauthorized`: Missing or invalid token
- `404 Not Found`: Transaction not found or doesn't belong to user
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X PUT http://localhost:5000/api/transactions/transaction-id \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 200.00,
    "type": "expense",
    "category": "Food",
    "description": "Updated description",
    "date": "2024-01-15T10:30:00.000Z"
  }'
```

---

#### Delete Transaction

Delete a transaction.

**Endpoint:** `DELETE /api/transactions/:id`

**Headers:**
```
Authorization: Bearer <token>
```

**URL Parameters:**
- `id`: Transaction ID

**Response (200 OK):**
```json
{
  "message": "Transaction deleted successfully"
}
```

**Error Responses:**
- `401 Unauthorized`: Missing or invalid token
- `404 Not Found`: Transaction not found or doesn't belong to user
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X DELETE http://localhost:5000/api/transactions/transaction-id \
  -H "Authorization: Bearer <token>"
```

---

### Export

#### Generate Excel Report

Generate an Excel report for transactions within a date range.

**Endpoint:** `POST /api/export/excel`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "startDate": "2024-01-01T00:00:00.000Z",
  "endDate": "2024-01-31T23:59:59.999Z",
  "reportType": "all"
}
```

**Parameters:**
- `startDate`: ISO 8601 date string (required)
- `endDate`: ISO 8601 date string (required)
- `reportType`: `"all"`, `"income"`, or `"expense"` (optional, default: `"all"`)

**Response (200 OK):**
- Content-Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- Binary Excel file stream

**Error Responses:**
- `400 Bad Request`: Invalid date range or parameters
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X POST http://localhost:5000/api/export/excel \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "startDate": "2024-01-01T00:00:00.000Z",
    "endDate": "2024-01-31T23:59:59.999Z",
    "reportType": "all"
  }' \
  --output report.xlsx
```

---

#### Get Report Summary

Get a summary of transactions for a date range without generating a file.

**Endpoint:** `GET /api/export/summary`

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `startDate`: ISO 8601 date string (required)
- `endDate`: ISO 8601 date string (required)
- `reportType`: `"all"`, `"income"`, or `"expense"` (optional, default: `"all"`)

**Response (200 OK):**
```json
{
  "totalTransactions": 50,
  "totalIncome": 5000.00,
  "totalExpenses": 3500.00,
  "netTotal": 1500.00,
  "dailyIncome": [
    {
      "date": "2024-01-15",
      "amount": 500.00
    }
  ],
  "transactions": [
    {
      "date": "2024-01-15T10:30:00.000Z",
      "type": "expense",
      "category": "Food",
      "description": "Grocery shopping",
      "amount": 150.50
    }
  ]
}
```

**Error Responses:**
- `400 Bad Request`: Invalid date range or parameters
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

**Example:**
```bash
curl -X GET "http://localhost:5000/api/export/summary?startDate=2024-01-01T00:00:00.000Z&endDate=2024-01-31T23:59:59.999Z&reportType=all" \
  -H "Authorization: Bearer <token>"
```

---

## Data Models

### User Model

```json
{
  "_id": "string",
  "name": "string",
  "email": "string",
  "password": "string (hashed)",
  "currency": "string",
  "monthlyBudget": "number",
  "createdAt": "ISO 8601 string",
  "updatedAt": "ISO 8601 string"
}
```

### Transaction Model

```json
{
  "_id": "string",
  "userId": "string",
  "amount": "number",
  "type": "income" | "expense",
  "category": "string",
  "description": "string",
  "date": "ISO 8601 string",
  "createdAt": "ISO 8601 string",
  "updatedAt": "ISO 8601 string"
}
```

## Error Responses

All error responses follow this format:

```json
{
  "error": "Error message",
  "details": "Additional error details (optional)"
}
```

### Common HTTP Status Codes

- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Authentication required or invalid token
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

## Authentication Flow

1. Register or login to receive a JWT token
2. Include the token in the `Authorization` header for protected endpoints
3. Token expires after a set period (configured in backend)
4. Re-authenticate to get a new token

## Rate Limiting

Currently, there is no rate limiting implemented. Consider adding rate limiting for production use.

## CORS

CORS is enabled for all origins. For production, configure specific allowed origins.

## Notes

- The backend uses local file storage (JSON files) instead of a database
- All timestamps are in ISO 8601 format
- Amounts are stored as numbers (floating point)
- User IDs and transaction IDs are auto-generated strings
- Transactions are filtered by `userId` to ensure data isolation

---

**Last Updated**: 2024

