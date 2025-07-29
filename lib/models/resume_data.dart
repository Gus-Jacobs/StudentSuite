import 'package:hive/hive.dart';

part 'resume_data.g.dart';

@HiveType(typeId: 8) // Next available typeId is 8
class ResumeData extends HiveObject {
  @HiveField(0)
  ContactInfoData contactInfo;

  @HiveField(1)
  List<String> skills;

  @HiveField(2)
  List<EducationData> education;

  @HiveField(3)
  List<ExperienceData> experience;

  @HiveField(4)
  List<CertificateData> certificates;

  ResumeData({
    required this.contactInfo,
    required this.skills,
    required this.education,
    required this.experience,
    required this.certificates,
  });
}

@HiveType(typeId: 9)
class ContactInfoData extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String email;
  @HiveField(2)
  String phone;
  @HiveField(3)
  String linkedin;
  @HiveField(4)
  String github;
  @HiveField(5)
  String portfolio;

  ContactInfoData({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.linkedin = '',
    this.github = '',
    this.portfolio = '',
  });
}

@HiveType(typeId: 10)
class EducationData extends HiveObject {
  @HiveField(0)
  String school;
  @HiveField(1)
  String degree;
  @HiveField(2)
  String gradDate;

  EducationData({this.school = '', this.degree = '', this.gradDate = ''});
}

@HiveType(typeId: 11)
class ExperienceData extends HiveObject {
  @HiveField(0)
  String company;
  @HiveField(1)
  String title;
  @HiveField(2)
  String dates;
  @HiveField(3)
  String responsibilities;

  ExperienceData(
      {this.company = '',
      this.title = '',
      this.dates = '',
      this.responsibilities = ''});
}

@HiveType(typeId: 12)
class CertificateData extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String organization;
  @HiveField(2)
  String date;

  CertificateData({this.name = '', this.organization = '', this.date = ''});
}
