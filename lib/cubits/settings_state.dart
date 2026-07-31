part of 'settings_cubit.dart';

class SettingsState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? systemSettings;
  final Map<String, dynamic>? appSettings;

  const SettingsState({
    this.isLoading = true,
    this.errorMessage,
    this.systemSettings,
    this.appSettings,
  });

  SettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? systemSettings,
    Map<String, dynamic>? appSettings,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      systemSettings: systemSettings ?? this.systemSettings,
      appSettings: appSettings ?? this.appSettings,
    );
  }
}
