class University {
  final String name;
  final String location;
  final String? province;
  final String? established;
  final String? specialization;
  final String? type;

  University({
    required this.name,
    required this.location,
    this.province,
    this.established,
    this.specialization,
    this.type,
  });

  factory University.fromList(List<dynamic> data) {
    return University(
      name: data[0].toString().trim(),
      location: data.length > 1 ? data[1].toString().trim() : "",
      province: data.length > 2 ? data[2].toString().trim() : null,
      established: data.length > 3 ? data[3].toString().trim() : null,
      specialization: data.length > 4 ? data[4].toString().trim() : null,
      type: data.length > 5 ? data[5].toString().trim() : null,
    );
  }

  @override
  String toString() {
    return 'University: $name, $location';
  }
} 