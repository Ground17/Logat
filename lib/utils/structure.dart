import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

part 'structure.g.dart';

@HiveType(typeId: 0)
class LocData extends HiveObject {
  @HiveField(0, defaultValue: '')
  String? title;

  @HiveField(1)
  String? description;

  @HiveField(2, defaultValue: '')
  String? date;

  @HiveField(3)
  Loc? location;

  @HiveField(4)
  String? address;

  @HiveField(5)
  String? path;

  LocData({required this.title, required this.description, required this.date, required this.location, required this.address, required this.path});

  @override
  String toString() => "$title, $description, $date, $location, $address $path";

  LocData.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    description = json['description'];
    date = json['date'];
    location = Loc.fromJson(json['location']);
    address = json['address'];
    path = json['path'];
  }
}

@HiveType(typeId: 1)
class Loc extends HiveObject {
  @HiveField(0)
  double? lat;

  @HiveField(1)
  double? long;

  Loc({required this.lat, required this.long});

  @override
  String toString() => "lat: $lat, long: $long";

  Loc.fromJson(Map<String, dynamic> json) {
    lat = json['lat'];
    long = json['long'];
  }
}