import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/settings_repository.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState()) {
    loadSettings();
  }

  final SettingsRepository _repository;

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final systemSettings = await _repository.getSystemSettings();
      final appSettings = await _repository.getAppSettings();
      emit(state.copyWith(
        systemSettings: systemSettings,
        appSettings: appSettings,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  String? get defaultCurrency =>
      state.systemSettings?['default_currency']?.toString() ?? 'MAD';

  String? get defaultCountry =>
      state.systemSettings?['company_country']?.toString() ?? 'Maroc';

  double get tvaPercentage =>
      (state.appSettings?['percentage'] as num?)?.toDouble() ?? 0.0;

  bool get tvaEnabled =>
      (state.appSettings?['is_enabled'] as bool?) ?? true;
}
