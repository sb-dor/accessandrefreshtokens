import 'package:flutter/foundation.dart';

@immutable
class User {
  const User({required this.id, this.name, this.email});

  factory User.fromMap(Map<String, Object?> map) =>
      User(id: map['id'] as int, name: map['name'] as String?, email: map['email'] as String?);

  final int id;
  final String? name;
  final String? email;

  /// Sanctum API token — kept in memory + SharedPreferences.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email);

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;

  @override
  String toString() => 'User{id: $id, name: $name, email: $email}';

  User copyWith({int? id, ValueGetter<String?>? name, ValueGetter<String?>? email}) => User(
    id: id ?? this.id,
    name: name != null ? name() : this.name,
    email: email != null ? email() : this.email,
  );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'email': email};
}
