# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security Scanning

This repository has the following security measures enabled:

- **CodeQL Analysis** - Automated code scanning for Python
- **PSScriptAnalyzer** - PowerShell script security analysis
- **Gitleaks** - Secret scanning to prevent credential leaks
- **Dependabot** - Automated dependency vulnerability scanning and updates
- **GitHub Secret Scanning** - Native GitHub secret detection (public repos)

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow these steps:

### 1. DO NOT Open a Public Issue

Please **do not** open a public GitHub issue for security vulnerabilities.

### 2. Report Privately

Report security vulnerabilities through one of these methods:

- **Preferred:** Use GitHub's [Security Advisories](https://github.com/dbbuilder/wsl-windows-script-runner/security/advisories/new)
- **Alternative:** Email security concerns to the repository maintainer (see GitHub profile)

### 3. Include Details

When reporting, please include:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact
- Suggested fix (if available)
- Your contact information for follow-up

### 4. Response Timeline

- **Initial Response:** Within 48 hours
- **Confirmation:** Within 7 days
- **Fix Timeline:** Depends on severity
  - Critical: Within 7 days
  - High: Within 14 days
  - Medium: Within 30 days
  - Low: Next scheduled release

## Security Considerations

### Known Security Implications

This tool has important security considerations:

#### 1. Privilege Escalation
- Windows Script Watcher runs as **SYSTEM** (highest privileges)
- Any script placed in the queue will execute with full system access
- **Risk:** Malicious scripts can compromise the entire Windows system

#### 2. Code Execution
- No authentication or authorization checks on queued scripts
- Scripts execute automatically when detected
- **Risk:** Unauthorized code execution if queue folder is accessible to untrusted users

#### 3. WSL-Windows Bridge
- Shared folder accessible from both WSL and Windows
- No encryption of data in transit
- **Risk:** Data exposure if WSL environment is compromised

### Recommended Security Practices

#### For Production Use:

1. **Restrict Queue Folder Access**
   ```powershell
   # Set NTFS permissions to allow only trusted users
   icacls "D:\Dev2\wsl-windows-script-runner\queue" /inheritance:r
   icacls "D:\Dev2\wsl-windows-script-runner\queue" /grant:r "SYSTEM:(OI)(CI)F"
   icacls "D:\Dev2\wsl-windows-script-runner\queue" /grant:r "Administrators:(OI)(CI)F"
   icacls "D:\Dev2\wsl-windows-script-runner\queue" /grant:r "YourTrustedUser:(OI)(CI)M"
   ```

2. **Enable Logging and Monitoring**
   - Review logs regularly for suspicious activity
   - Set up alerts for unusual script executions
   - Monitor the archive folder (failed scripts)

3. **Use in Isolated Environments**
   - Deploy on development/testing machines only
   - Avoid production servers
   - Use virtual machines when possible

4. **Code Review All Scripts**
   - Review scripts before placing in queue
   - Use version control for all automation scripts
   - Implement approval processes

5. **Network Isolation**
   - Use on air-gapped or firewalled systems
   - Restrict network access from script execution environment

6. **Regular Security Audits**
   - Review scheduled task permissions
   - Audit queue folder access logs
   - Check for unauthorized scripts

#### For Development Use:

1. **Personal Machines Only**
   - Use on your own development workstation
   - Don't deploy on shared systems

2. **Test Scripts First**
   - Always test scripts manually before automation
   - Use non-destructive operations when possible

3. **Keep Software Updated**
   - Update MCP server dependencies regularly
   - Monitor Dependabot alerts
   - Apply Windows security patches

## Security Best Practices for Users

### When Using the Bash Helper:

```bash
# Review script before submission
cat script.ps1

# Submit only after review
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh script.ps1
```

### When Using the MCP Server:

- Understand that Claude-generated scripts will execute with SYSTEM privileges
- Review log outputs to ensure scripts behave as expected
- Monitor the Windows Script Watcher status regularly

### Script Safety Guidelines:

1. **Avoid Hardcoded Credentials**
   - Never include passwords or API keys in scripts
   - Use Windows Credential Manager or Azure Key Vault

2. **Validate Inputs**
   - Check parameters before use
   - Sanitize user-provided data

3. **Limit Scope**
   - Use principle of least privilege
   - Avoid system-wide changes when possible

4. **Error Handling**
   - Implement proper try-catch blocks
   - Fail safely without leaving system in bad state

## Dependency Security

### Python Dependencies (MCP Server)

Dependencies are automatically scanned by:
- **Dependabot** - Weekly checks for vulnerabilities
- **GitHub Advisory Database** - Continuous monitoring

### Updating Dependencies:

```bash
cd mcp-server
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

## Disclosure Policy

- **Private Disclosure:** Security issues will be fixed privately
- **Public Disclosure:** After fix is released and users have had time to update
- **Credit:** Security researchers will be credited (if desired)

## Security Updates

Security updates will be released as:
- Patch versions (1.0.x) for security fixes
- Documented in CHANGELOG.md with "Security" label
- Announced in GitHub Releases

## Contact

For security-related questions or concerns:
- Use GitHub Security Advisories (preferred)
- Open a regular issue for non-sensitive security questions
- Check existing issues for common questions

## Acknowledgments

We appreciate the security research community's efforts in keeping this project secure. Contributors who report valid security issues will be acknowledged in our release notes (with permission).

---

**Remember:** This tool provides significant automation power but requires responsible use. Always consider security implications when deploying automation tools with elevated privileges.
