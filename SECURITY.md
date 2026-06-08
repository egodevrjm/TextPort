# Security Policy

## Supported Versions

TextPort is early open-source software. Security fixes are handled on the main branch until formal releases are introduced.

## Reporting a Vulnerability

Please avoid posting exploitable security details in public issues.

If the GitHub repository has private vulnerability reporting enabled, use GitHub's security advisory flow. Otherwise, contact the maintainer privately through the repository profile and include:

- affected TextPort version or commit
- macOS version
- a concise description of the issue
- reproduction steps or a minimal sample file when safe to share

## Security Notes

- TextPort is a local macOS app and does not require an account.
- Sharing and GitHub helpers are optional and disabled by default.
- Running project tasks or runnable code files executes local shell commands. Only run commands from projects you trust.
- Imported PDFs, Word files, PowerPoint files, spreadsheets, zip projects, rendered previews, and JSON visualizations should be treated as untrusted input until inspected.
