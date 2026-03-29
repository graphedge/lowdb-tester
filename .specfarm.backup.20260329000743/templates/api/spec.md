# Feature: {{NAME}}

**Type**: {{TYPE}}  
**Created**: {{DATE}}  
**Status**: Draft

## Overview

This is a specseed template for a REST API feature.

## Goals

- Provide RESTful API endpoints for data access
- Implement authentication and authorization
- Support CRUD operations on resources
- Maintain API versioning and backwards compatibility

## Constraints

- Must follow REST best practices
- Response times < 200ms for 95th percentile
- Rate limiting: 1000 requests/hour per API key
- All endpoints must support JSON format

## Acceptance Criteria

1. All CRUD operations function correctly
2. Authentication required for protected endpoints
3. Error responses follow RFC 7807 Problem Details
4. API documentation generated via OpenAPI/Swagger

## Testing

- Unit tests for business logic
- Integration tests for endpoint behavior
- Load tests for performance validation
- Security tests for authentication/authorization

## API Endpoints

- `GET /api/v1/resources` - List resources
- `GET /api/v1/resources/{id}` - Get resource by ID
- `POST /api/v1/resources` - Create resource
- `PUT /api/v1/resources/{id}` - Update resource
- `DELETE /api/v1/resources/{id}` - Delete resource

## Dependencies

- Authentication service
- Database connection pool
- API gateway
