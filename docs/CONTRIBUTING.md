# Contributing to PitLab Wallet

Thank you for your interest in contributing to PitLab Wallet! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Development Process

1. Fork the repository
2. Create a feature branch from `dev`
3. Make your changes
4. Run tests and validation
5. Submit a pull request

### Branch Naming

- Feature branches: `feature/description`
- Bug fixes: `fix/description`
- Documentation: `docs/description`

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Adding or modifying tests
- `chore:` Maintenance tasks

### Code Style

- Shell scripts: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Python: Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
- C/C++: Follow [Linux kernel coding style](https://www.kernel.org/doc/html/latest/process/coding-style.html)

### Testing

Before submitting a PR:

1. Run `./scripts/check_dependencies.sh`
2. Run `./scripts/verify-config.sh`
3. Build for at least one board configuration
4. Validate the firmware image

## Security

- Never commit sensitive information
- Follow security best practices in [SECURITY.md](SECURITY.md)
- Report security issues according to our security policy

## Documentation

- Update documentation for new features
- Include code comments explaining complex logic
- Update the changelog

## Review Process

1. All PRs require at least one review
2. Address review comments promptly
3. Keep PR size manageable
4. Include relevant tests

## Questions?

Join our [community chat](https://gitter.im/pitlab-wallet/community) or [open an issue](https://github.com/pitlab-wallet/issues/new).