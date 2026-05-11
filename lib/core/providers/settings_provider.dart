import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/settings_model.dart';
import 'app_providers.dart';

const _settingsStorageKey = 'settings_model_v1';
const _uuid = Uuid();

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsModel>((ref) {
      return SettingsController(
        ref.watch(sharedPreferencesProvider),
        ref.watch(initialSettingsModelProvider),
      );
    });

class SettingsController extends StateNotifier<SettingsModel> {
  SettingsController(this._sharedPreferences, SettingsModel initialState)
    : super(initialState);

  final SharedPreferences _sharedPreferences;

  static SettingsModel loadFromPreferences(
    SharedPreferences sharedPreferences,
  ) {
    final raw = sharedPreferences.getString(_settingsStorageKey);
    if (raw == null || raw.isEmpty) {
      return SettingsModel.initial();
    }

    try {
      return SettingsModel.decode(raw);
    } catch (_) {
      return SettingsModel.initial();
    }
  }

  Future<ApiProfile> addProfile({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    final nextIndex = state.profiles.length + 1;
    final profile = ApiProfile(
      id: _uuid.v4(),
      name: name ?? '配置 $nextIndex',
      baseUrl: baseUrl ?? 'https://api.openai.com',
      apiKey: apiKey ?? '',
      model: model ?? 'gpt-image-2',
    );
    state = state.copyWith(
      profiles: [...state.profiles, profile],
      activeProfileId: state.activeProfileId,
    );
    await _persist();
    return profile;
  }

  Future<void> updateProfile(ApiProfile profile) async {
    final profiles = [
      for (final item in state.profiles)
        if (item.id == profile.id) profile else item,
    ];
    state = state.copyWith(profiles: profiles);
    await _persist();
  }

  Future<void> deleteProfile(String id) async {
    if (state.profiles.length <= 1) {
      return;
    }

    final profiles = state.profiles
        .where((profile) => profile.id != id)
        .toList();
    final activeProfileId = state.activeProfileId == id
        ? profiles.first.id
        : state.activeProfileId;

    state = state.copyWith(
      profiles: profiles,
      activeProfileId: activeProfileId,
    );
    await _persist();
  }

  Future<void> setActiveProfile(String id) async {
    if (!state.profiles.any((profile) => profile.id == id)) {
      return;
    }
    state = state.copyWith(activeProfileId: id);
    await _persist();
  }

  Future<void> setRequestTimeoutSeconds(int seconds) async {
    if (seconds <= 0) {
      return;
    }

    state = state.copyWith(requestTimeoutSeconds: seconds);
    await _persist();
  }

  Future<void> _persist() async {
    await _sharedPreferences.setString(_settingsStorageKey, state.encode());
  }
}
