/// Reads [value] as a JSON object. Platform channels hand back untyped maps,
/// at the top level and for every nested object.
Map<String, Object?> jsonObject(Object? value) =>
    Map<String, Object?>.from(value! as Map);
