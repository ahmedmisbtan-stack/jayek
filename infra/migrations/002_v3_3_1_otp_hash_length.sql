-- v3.3.1: OTP codes are stored as SHA-256 hex hashes (64 chars), not plaintext 4-6 digit codes.
ALTER TABLE otp_challenges ALTER COLUMN code TYPE VARCHAR(64);
