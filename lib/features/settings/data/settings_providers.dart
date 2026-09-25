import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/deterministic_policy_engine.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../models/security_decision.dart';
import '../../ai_security/domain/ai_provider.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final securityPoliciesProvider =
    StateNotifierProvider<SecurityPoliciesNotifier, SecurityPolicies>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecurityPoliciesNotifier(storage);
});

final deterministicPolicyEngineProvider =
    Provider<DeterministicPolicyEngine>((ref) {
  final policies = ref.watch(securityPoliciesProvider);
  return DeterministicPolicyEngine(policies: policies);
});

class SecurityPoliciesNotifier extends StateNotifier<SecurityPolicies> {
  final SecureStorageService _storage;

  SecurityPoliciesNotifier(this._storage) : super(const SecurityPolicies()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final loaded = await _storage.getPolicies();
    state = loaded;
  }

  Future<void> updatePolicies(SecurityPolicies newPolicies) async {
    state = newPolicies;
    await _storage.savePolicies(newPolicies);
  }

  void toggleSudo(bool value) =>
      updatePolicies(state.copyWith(requireConfirmationForSudo: value));

  void toggleDeletion(bool value) =>
      updatePolicies(state.copyWith(requireConfirmationForFileDeletion: value));

  void toggleCredentials(bool value) =>
      updatePolicies(state.copyWith(requireConfirmationForCredentials: value));

  void toggleSSH(bool value) =>
      updatePolicies(state.copyWith(requireConfirmationForSSH: value));

  void toggleNetworkScripts(bool value) => updatePolicies(
      state.copyWith(requireConfirmationForNetworkScripts: value));

  void togglePackages(bool value) => updatePolicies(
      state.copyWith(requireConfirmationForPackageInstall: value));

  void toggleUnknown(bool value) => updatePolicies(
      state.copyWith(requireConfirmationForUnknownCommands: value));
}

// AI Settings State
class AISettingsState {
  final bool isAiAnalysisEnabled;
  final bool isAutoApprovalEnabled;
  final AIProviderType providerType;
  final String model;
  final RiskMode riskMode;
  final BiometricPolicy biometricPolicy;

  const AISettingsState({
    this.isAiAnalysisEnabled = true,
    this.isAutoApprovalEnabled = false,
    this.providerType = AIProviderType.openAI,
    this.model = 'gpt-4o-mini',
    this.riskMode = RiskMode.balanced,
    this.biometricPolicy = BiometricPolicy.highRiskOnly,
  });

  AISettingsState copyWith({
    bool? isAiAnalysisEnabled,
    bool? isAutoApprovalEnabled,
    AIProviderType? providerType,
    String? model,
    RiskMode? riskMode,
    BiometricPolicy? biometricPolicy,
  }) {
    return AISettingsState(
      isAiAnalysisEnabled: isAiAnalysisEnabled ?? this.isAiAnalysisEnabled,
      isAutoApprovalEnabled:
          isAutoApprovalEnabled ?? this.isAutoApprovalEnabled,
      providerType: providerType ?? this.providerType,
      model: model ?? this.model,
      riskMode: riskMode ?? this.riskMode,
      biometricPolicy: biometricPolicy ?? this.biometricPolicy,
    );
  }
}

final aiSettingsProvider =
    StateNotifierProvider<AISettingsNotifier, AISettingsState>((ref) {
  return AISettingsNotifier();
});

class AISettingsNotifier extends StateNotifier<AISettingsState> {
  AISettingsNotifier() : super(const AISettingsState());

  void setAiAnalysisEnabled(bool val) =>
      state = state.copyWith(isAiAnalysisEnabled: val);

  void setAutoApprovalEnabled(bool val) =>
      state = state.copyWith(isAutoApprovalEnabled: val);

  void setProviderType(AIProviderType type) {
    state = state.copyWith(
      providerType: type,
      model: type.availableModels.first,
    );
  }

  void setModel(String model) => state = state.copyWith(model: model);

  void setRiskMode(RiskMode mode) => state = state.copyWith(riskMode: mode);

  void setBiometricPolicy(BiometricPolicy policy) =>
      state = state.copyWith(biometricPolicy: policy);
}
