import '../../models/approval_request.dart';
import '../../models/risk_level.dart';

/// User-configurable policy toggles for strict manual confirmation.
class SecurityPolicies {
  final bool requireConfirmationForSudo;
  final bool requireConfirmationForFileDeletion;
  final bool requireConfirmationForCredentials;
  final bool requireConfirmationForSSH;
  final bool requireConfirmationForNetworkScripts;
  final bool requireConfirmationForPackageInstall;
  final bool requireConfirmationForUnknownCommands;

  const SecurityPolicies({
    this.requireConfirmationForSudo = true,
    this.requireConfirmationForFileDeletion = true,
    this.requireConfirmationForCredentials = true,
    this.requireConfirmationForSSH = true,
    this.requireConfirmationForNetworkScripts = true,
    this.requireConfirmationForPackageInstall = false,
    this.requireConfirmationForUnknownCommands = true,
  });

  SecurityPolicies copyWith({
    bool? requireConfirmationForSudo,
    bool? requireConfirmationForFileDeletion,
    bool? requireConfirmationForCredentials,
    bool? requireConfirmationForSSH,
    bool? requireConfirmationForNetworkScripts,
    bool? requireConfirmationForPackageInstall,
    bool? requireConfirmationForUnknownCommands,
  }) {
    return SecurityPolicies(
      requireConfirmationForSudo:
          requireConfirmationForSudo ?? this.requireConfirmationForSudo,
      requireConfirmationForFileDeletion:
          requireConfirmationForFileDeletion ?? this.requireConfirmationForFileDeletion,
      requireConfirmationForCredentials:
          requireConfirmationForCredentials ?? this.requireConfirmationForCredentials,
      requireConfirmationForSSH:
          requireConfirmationForSSH ?? this.requireConfirmationForSSH,
      requireConfirmationForNetworkScripts:
          requireConfirmationForNetworkScripts ?? this.requireConfirmationForNetworkScripts,
      requireConfirmationForPackageInstall:
          requireConfirmationForPackageInstall ?? this.requireConfirmationForPackageInstall,
      requireConfirmationForUnknownCommands:
          requireConfirmationForUnknownCommands ?? this.requireConfirmationForUnknownCommands,
    );
  }

  Map<String, bool> toMap() {
    return {
      'sudo': requireConfirmationForSudo,
      'deletion': requireConfirmationForFileDeletion,
      'credentials': requireConfirmationForCredentials,
      'ssh': requireConfirmationForSSH,
      'network_scripts': requireConfirmationForNetworkScripts,
      'packages': requireConfirmationForPackageInstall,
      'unknown': requireConfirmationForUnknownCommands,
    };
  }

  factory SecurityPolicies.fromMap(Map<String, dynamic> map) {
    return SecurityPolicies(
      requireConfirmationForSudo: map['sudo'] as bool? ?? true,
      requireConfirmationForFileDeletion: map['deletion'] as bool? ?? true,
      requireConfirmationForCredentials: map['credentials'] as bool? ?? true,
      requireConfirmationForSSH: map['ssh'] as bool? ?? true,
      requireConfirmationForNetworkScripts: map['network_scripts'] as bool? ?? true,
      requireConfirmationForPackageInstall: map['packages'] as bool? ?? false,
      requireConfirmationForUnknownCommands: map['unknown'] as bool? ?? true,
    );
  }
}

class PolicyEvaluationResult {
  final bool allowsAutoApproval;
  final RiskLevel calculatedRisk;
  final String? blockedByRule;
  final String reasoning;

  const PolicyEvaluationResult({
    required this.allowsAutoApproval,
    required this.calculatedRisk,
    this.blockedByRule,
    required this.reasoning,
  });
}

/// Deterministic Security Policy Engine.
/// Strictly evaluates commands and enforces policy rules before any AI suggestion.
class DeterministicPolicyEngine {
  final SecurityPolicies policies;

  const DeterministicPolicyEngine({this.policies = const SecurityPolicies()});

  PolicyEvaluationResult evaluate(ApprovalRequest request) {
    final cmd = request.command.toLowerCase().trim();

    // 1. Critical Destructive Commands (Root/System deletion, formatting)
    if (_isCriticalDestructive(cmd)) {
      return const PolicyEvaluationResult(
        allowsAutoApproval: false,
        calculatedRisk: RiskLevel.critical,
        blockedByRule: 'CRITICAL_DESTRUCTIVE_COMMAND',
        reasoning:
            'Command involves extreme filesystem deletion, disk formatting, or raw system modification.',
      );
    }

    // 2. Sudo / Privileged Elevation Check
    if (_isSudoOrElevated(cmd)) {
      if (policies.requireConfirmationForSudo) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.high,
          blockedByRule: 'POLICY_REQUIRE_SUDO_CONFIRMATION',
          reasoning: 'Policy requires manual user confirmation for all privileged/sudo commands.',
        );
      }
    }

    // 3. Credential & Secret Access Check (.env, id_rsa, tokens, keychain)
    if (_isCredentialAccess(cmd)) {
      if (policies.requireConfirmationForCredentials) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.high,
          blockedByRule: 'POLICY_REQUIRE_CREDENTIAL_CONFIRMATION',
          reasoning: 'Policy requires manual user confirmation for credential or secret access.',
        );
      }
    }

    // 4. File Deletion Check (rm, del, rmdir, unlink)
    if (_isFileDeletion(cmd)) {
      if (policies.requireConfirmationForFileDeletion) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.high,
          blockedByRule: 'POLICY_REQUIRE_DELETION_CONFIRMATION',
          reasoning: 'Policy requires manual user confirmation for file deletion operations.',
        );
      }
    }

    // 5. Shell Piping & Remote Scripts (curl | sh, wget | bash, etc.)
    if (_isRemoteScriptExecution(cmd)) {
      if (policies.requireConfirmationForNetworkScripts) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.high,
          blockedByRule: 'POLICY_REQUIRE_NETWORK_SCRIPT_CONFIRMATION',
          reasoning: 'Policy requires manual user confirmation for piped remote scripts.',
        );
      }
    }

    // 6. SSH and Remote Shell operations
    if (_isSshOperation(cmd)) {
      if (policies.requireConfirmationForSSH) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.high,
          blockedByRule: 'POLICY_REQUIRE_SSH_CONFIRMATION',
          reasoning: 'Policy requires manual user confirmation for SSH and remote access commands.',
        );
      }
    }

    // 7. Package installation (npm install, flutter pub get, pip install)
    if (_isPackageInstallation(cmd)) {
      if (policies.requireConfirmationForPackageInstall) {
        return const PolicyEvaluationResult(
          allowsAutoApproval: false,
          calculatedRisk: RiskLevel.low,
          blockedByRule: 'POLICY_REQUIRE_PACKAGE_CONFIRMATION',
          reasoning: 'Policy requires manual confirmation for package installations.',
        );
      }
      return const PolicyEvaluationResult(
        allowsAutoApproval: true,
        calculatedRisk: RiskLevel.low,
        reasoning: 'Standard package installation permitted by deterministic policy.',
      );
    }

    // 8. Safe Read-Only Commands (git status, git diff, ls, dir, cat, echo)
    if (_isSafeReadOnly(cmd)) {
      return const PolicyEvaluationResult(
        allowsAutoApproval: true,
        calculatedRisk: RiskLevel.low,
        reasoning: 'Read-only diagnostic command deemed safe by deterministic policy.',
      );
    }

    // Default fallback: Unknown command
    return PolicyEvaluationResult(
      allowsAutoApproval: !policies.requireConfirmationForUnknownCommands,
      calculatedRisk: RiskLevel.medium,
      blockedByRule: policies.requireConfirmationForUnknownCommands
          ? 'POLICY_UNKNOWN_COMMAND'
          : null,
      reasoning: 'Command does not match pre-approved safe patterns.',
    );
  }

  static bool _isCriticalDestructive(String cmd) {
    return cmd.contains('rm -rf /') ||
        cmd.contains('rm -rf /*') ||
        cmd.contains('del /s /q c:\\') ||
        cmd.contains('format ') ||
        cmd.contains('mkfs') ||
        cmd.contains(':(){ :|:& };:'); // fork bomb
  }

  static bool _isSudoOrElevated(String cmd) {
    return cmd.startsWith('sudo ') ||
        cmd.contains(' sudo ') ||
        cmd.startsWith('su ') ||
        cmd.contains('runas ') ||
        cmd.contains('chmod 777');
  }

  static bool _isCredentialAccess(String cmd) {
    return cmd.contains('.env') ||
        cmd.contains('id_rsa') ||
        cmd.contains('.ssh') ||
        cmd.contains('credentials') ||
        cmd.contains('secrets') ||
        cmd.contains('token') ||
        cmd.contains('api_key');
  }

  static bool _isFileDeletion(String cmd) {
    return cmd.startsWith('rm ') ||
        cmd.contains(' rm ') ||
        cmd.startsWith('del ') ||
        cmd.contains(' del ') ||
        cmd.startsWith('rmdir ') ||
        cmd.contains(' rmdir ') ||
        cmd.startsWith('unlink ') ||
        cmd.contains(' git clean -fd');
  }

  static bool _isRemoteScriptExecution(String cmd) {
    return (cmd.contains('curl') || cmd.contains('wget')) &&
        (cmd.contains('| sh') || cmd.contains('| bash') || cmd.contains('| powershell') || cmd.contains('| pwsh'));
  }

  static bool _isSshOperation(String cmd) {
    return cmd.startsWith('ssh ') ||
        cmd.contains(' ssh ') ||
        cmd.startsWith('scp ') ||
        cmd.startsWith('sftp ');
  }

  static bool _isPackageInstallation(String cmd) {
    return cmd.startsWith('npm install') ||
        cmd.startsWith('npm i ') ||
        cmd.startsWith('yarn add') ||
        cmd.startsWith('pnpm add') ||
        cmd.startsWith('flutter pub get') ||
        cmd.startsWith('flutter pub add') ||
        cmd.startsWith('pip install') ||
        cmd.startsWith('cargo add') ||
        cmd.startsWith('go get');
  }

  static bool _isSafeReadOnly(String cmd) {
    return cmd.startsWith('git status') ||
        cmd.startsWith('git diff') ||
        cmd.startsWith('git log') ||
        cmd.startsWith('ls') ||
        cmd.startsWith('dir') ||
        cmd.startsWith('pwd') ||
        cmd.startsWith('echo ') ||
        cmd.startsWith('flutter doctor');
  }
}
