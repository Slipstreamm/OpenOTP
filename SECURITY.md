# Security Policy

## Supported Versions

The following table outlines which versions of OpenOTP are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| latest  | ✅ Yes             |
| older   | ❌ No              |

## Reporting a Vulnerability

If you discover a security vulnerability in OpenOTP:

1. **Do not open a public issue.**
2. Instead, please email: [security@openotp.lol](mailto:security@openotp.lol)
3. Include as much detail as possible, including:
   - Steps to reproduce
   - Affected platform(s)
   - Potential impact
   - Suggested fix (if any)

## Scope

This policy covers:

- Vulnerabilities in OpenOTP's codebase (Flutter UI, storage handling, OTP parsing)
- Weaknesses in the cryptographic handling of TOTP/HOTP secrets
- Leaks or unsafe storage of sensitive user data

Out of scope:

- Issues in third-party packages used by OpenOTP (unless exploitable through OpenOTP)
- Social engineering or phishing attacks
- Vulnerabilities requiring root/admin access

## Responsible Disclosure

We appreciate responsible disclosures and will credit contributors who responsibly report issues, if desired.

Thank you for helping make OpenOTP safer for everyone.
