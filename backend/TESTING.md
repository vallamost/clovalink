# Testing Guide for ClovaLink Backend

This document describes the testing infrastructure and how to run tests for the ClovaLink backend.

## Test Overview

The backend includes comprehensive unit and integration tests covering:
- Security-critical functionality
- Database operations
- Business logic
- API endpoints
- Compliance requirements
- Storage backends

**Total Test Coverage: 89+ tests** across all backend crates.

## Running Tests

### Run All Tests

```bash
cd backend
cargo test
```

### Run Tests for Specific Crates

```bash
# Core functionality tests
cargo test --package clovalink_core

# Authentication and authorization tests
cargo test --package clovalink_auth

# Storage backend tests
cargo test --package clovalink_storage

# Extension system tests
cargo test --package clovalink_extensions

# AI features tests
cargo test --package clovalink_ai

# API tests
cargo test --package clovalink_api
```

### Run Integration Tests Only

```bash
cargo test --test '*'
```

### Run Tests with Output

```bash
# Show test output (useful for debugging)
cargo test -- --nocapture

# Show test output and use single thread (for debugging race conditions)
cargo test -- --nocapture --test-threads=1
```

### Run Specific Test

```bash
# Run a specific test by name
cargo test test_alert_severity_conversion

# Run all tests matching a pattern
cargo test security
```

## Test Structure

### Unit Tests

Unit tests are located in the same files as the code they test, in `#[cfg(test)]` modules.

**Examples:**
- `crates/core/src/security_service.rs` - Security alert tests
- `crates/auth/src/middleware.rs` - Authentication middleware tests
- `crates/core/src/models.rs` - Data model and permission tests
- `crates/storage/src/lib.rs` - Storage backend tests
- `crates/core/src/notification_service.rs` - Notification and templating tests

### Integration Tests

Integration tests are in the `tests/` directory of each crate and test interactions between components.

**Location:** `crates/api/tests/integration_test.rs`

**Coverage:**
- Tenant isolation
- Security features
- Compliance requirements (HIPAA, SOX, GDPR)
- File operations
- Audit logging
- Rate limiting

## Test Categories

### Security Tests (17 tests)

Located in `crates/auth/src/middleware.rs`:
- Role-based access control
- Permission hierarchy validation
- IP address extraction and fingerprinting
- Request authentication

**Key Tests:**
- `test_require_superadmin_success` / `test_require_superadmin_failure`
- `test_require_admin_success` / `test_require_admin_failure`
- `test_require_manager_success` / `test_require_manager_failure`
- `test_role_hierarchy`
- `test_extract_client_ip_*`
- `test_generate_fingerprint_*`

### Core Business Logic Tests (32 tests)

Located in `crates/core/src/`:
- Alert types and severity levels (`security_service.rs`)
- Data models and permissions (`models.rs`)
- Notification templates and rendering (`notification_service.rs`)
- Cache operations (`cache.rs`)
- Circuit breaker patterns (`circuit_breaker.rs`)
- Job queue operations (`queue.rs`)
- Repository operations (`repository.rs`)

**Key Tests:**
- `test_alert_default_severity`
- `test_get_base_permissions_*`
- `test_permission_hierarchy`
- `test_replace_template_variables_*`
- `test_notification_type_*`

### Storage Tests (8 tests)

Located in `crates/storage/src/lib.rs`:
- File metadata handling
- Encryption/decryption operations
- Storage backend capabilities
- Nonce uniqueness
- Backwards compatibility

**Key Tests:**
- `test_encrypted_local_storage_encryption_decryption`
- `test_encrypted_storage_roundtrip`
- `test_encrypted_storage_nonce_uniqueness`
- `test_encrypted_storage_backwards_compatibility`
- `test_*_supports_presigned_urls`

### Integration Tests (16 tests)

Located in `crates/api/tests/integration_test.rs`:
- Tenant isolation verification
- Compliance policy validation
- File operation security
- Audit log integrity
- Rate limiting calculations

**Key Tests:**
- `test_tenant_id_generation`
- `test_hipaa_retention_policy`
- `test_gdpr_retention_policy`
- `test_sox_retention_policy`
- `test_file_path_validation`
- `test_audit_log_immutability`

## Environment Variables for Tests

Some tests may require environment variables:

```bash
# For development/testing JWT
export ENVIRONMENT=development
export JWT_SECRET="test-secret-for-unit-tests-only-32chars"

# For database tests (optional, uses defaults if not set)
export TEST_DATABASE_URL="postgres://postgres:postgres@localhost:5432/clovalink_test"
```

## Best Practices

### Writing New Tests

1. **Unit tests** should be added in `#[cfg(test)]` modules in the same file as the code
2. **Integration tests** should go in the `tests/` directory
3. Use descriptive test names: `test_<what>_<scenario>_<expected_result>`
4. Test both success and failure cases
5. Test edge cases and boundary conditions
6. Keep tests independent and idempotent

### Test Patterns

```rust
#[test]
fn test_feature_success() {
    // Arrange
    let input = create_test_data();
    
    // Act
    let result = function_under_test(input);
    
    // Assert
    assert_eq!(result, expected_value);
}

#[test]
#[should_panic(expected = "error message")]
fn test_feature_validation_failure() {
    // Test that validation fails as expected
    invalid_operation();
}

#[tokio::test]
async fn test_async_feature() {
    // For async tests
    let result = async_function().await;
    assert!(result.is_ok());
}
```

## Continuous Integration

Tests are automatically run in CI/CD pipelines. All tests must pass before merging.

### CI Test Commands

```bash
# Format check
cargo fmt --all -- --check

# Linting
cargo clippy --all-targets --all-features -- -D warnings

# Run all tests
cargo test --all-features

# Build check
cargo build --release
```

## Code Coverage

To generate code coverage reports (requires `cargo-tarpaulin`):

```bash
# Install tarpaulin
cargo install cargo-tarpaulin

# Generate coverage report
cargo tarpaulin --out Html --output-dir coverage

# Open coverage report
open coverage/index.html
```

## Debugging Tests

### Show println! output

```bash
cargo test -- --nocapture
```

### Run in single-threaded mode

```bash
cargo test -- --test-threads=1
```

### Enable trace logging

```bash
RUST_LOG=debug cargo test
```

### Run only failing tests

```bash
cargo test --tests -- --test-threads=1 --show-output
```

## Performance Testing

Load tests are located in `/tests/load/`:
- `upload_stress.js` - File upload stress testing
- `virus_scan_load.js` - Virus scanning load testing

Run with:
```bash
cd tests/load
./setup.sh
# Follow instructions in setup script
```

## Database Tests

Database-dependent tests require:
1. PostgreSQL running locally or via Docker
2. Test database created
3. Migrations applied

```bash
# Start test database (Docker)
docker run -d \
  --name clovalink-test-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=clovalink_test \
  -p 5432:5432 \
  postgres:16

# Run migrations
sqlx migrate run --database-url postgres://postgres:postgres@localhost:5432/clovalink_test
```

## Contributing Tests

When adding new features:
1. Write tests first (TDD approach recommended)
2. Ensure all existing tests pass
3. Add integration tests for API endpoints
4. Document any special test setup required
5. Update this guide if adding new test categories

## Test Metrics

Current test statistics:
- **Total Tests**: 89+
- **Unit Tests**: 73
- **Integration Tests**: 16
- **Success Rate**: 100%
- **Coverage**: Significantly improved from ~18% baseline

## Troubleshooting

### Tests Fail with "database connection refused"

Ensure PostgreSQL is running and TEST_DATABASE_URL is set correctly.

### Compilation errors in tests

Run `cargo clean` and rebuild:
```bash
cargo clean
cargo test
```

### Slow test execution

Use `--test-threads` to control parallelism:
```bash
cargo test -- --test-threads=4
```

## Resources

- [Rust Testing Guide](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Cargo Test Documentation](https://doc.rust-lang.org/cargo/commands/cargo-test.html)
- [Project README](/README.md)
- [Backend Quickstart](/backend/QUICKSTART.md)
