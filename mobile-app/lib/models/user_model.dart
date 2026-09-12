import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for app users
/// Ported from React Native User type
class UserModel {
  final String id;
  final String email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final UserPreferences preferences;
  final List<String> familyIds;

  UserModel({
    required this.id,
    required this.email,
    this.phoneNumber,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    required this.preferences,
    this.familyIds = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt:
          (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      familyIds: List<String>.from(data['familyIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'preferences': preferences.toMap(),
      'familyIds': familyIds,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    UserPreferences? preferences,
    List<String>? familyIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      familyIds: familyIds ?? this.familyIds,
    );
  }
}

/// User preferences for app settings
class UserPreferences {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final String temperatureUnit;
  final String language;
  final bool biometricEnabled;

  UserPreferences({
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.temperatureUnit = 'celsius',
    this.language = 'en',
    this.biometricEnabled = false,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      darkModeEnabled: map['darkModeEnabled'] ?? false,
      temperatureUnit: map['temperatureUnit'] ?? 'celsius',
      language: map['language'] ?? 'en',
      biometricEnabled: map['biometricEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'temperatureUnit': temperatureUnit,
      'language': language,
      'biometricEnabled': biometricEnabled,
    };
  }

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    String? temperatureUnit,
    String? language,
    bool? biometricEnabled,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      language: language ?? this.language,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}
