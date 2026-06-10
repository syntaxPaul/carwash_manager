class VehicleDetails {
  final String? car;
  final String? licensePlate;

  const VehicleDetails({this.car, this.licensePlate});
}

VehicleDetails splitVehicleDetails(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return const VehicleDetails();

  final bulletParts = text
      .split(RegExp(r'\s*(?:•|\||/|,)\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (bulletParts.length >= 2) {
    return VehicleDetails(
      car: bulletParts.take(bulletParts.length - 1).join(' '),
      licensePlate: bulletParts.last,
    );
  }

  final separatedParts = text
      .split(RegExp(r'\s+[/|]\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (separatedParts.length >= 2) {
    return VehicleDetails(
      car: separatedParts.take(separatedParts.length - 1).join(' '),
      licensePlate: separatedParts.last,
    );
  }

  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) {
    final plateStart = _plateTailStart(words);
    if (plateStart != null && plateStart > 0) {
      return VehicleDetails(
        car: words.take(plateStart).join(' '),
        licensePlate: words.skip(plateStart).join(' ').toUpperCase(),
      );
    }
  }

  return VehicleDetails(car: text);
}

int? _plateTailStart(List<String> words) {
  final last = words.last;
  if (_containsDigit(last) && last.length >= 5) return words.length - 1;

  if (words.length >= 3 &&
      _looksLikeProvinceSuffix(last) &&
      _containsDigit(words[words.length - 2])) {
    if (words.length >= 4 && _looksLikePlateToken(words[words.length - 3])) {
      return words.length - 3;
    }
    return words.length - 2;
  }

  return null;
}

bool _containsDigit(String value) => RegExp(r'\d').hasMatch(value);

bool _looksLikeProvinceSuffix(String value) {
  return RegExp(r'^[A-Za-z]{1,3}$').hasMatch(value);
}

bool _looksLikePlateToken(String value) {
  return value.length <= 4 && RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value);
}
