// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ResumeDataAdapter extends TypeAdapter<ResumeData> {
  @override
  final int typeId = 8;

  @override
  ResumeData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResumeData(
      contactInfo: fields[0] as ContactInfoData,
      skills: (fields[1] as List).cast<String>(),
      education: (fields[2] as List).cast<EducationData>(),
      experience: (fields[3] as List).cast<ExperienceData>(),
      certificates: (fields[4] as List).cast<CertificateData>(),
    );
  }

  @override
  void write(BinaryWriter writer, ResumeData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.contactInfo)
      ..writeByte(1)
      ..write(obj.skills)
      ..writeByte(2)
      ..write(obj.education)
      ..writeByte(3)
      ..write(obj.experience)
      ..writeByte(4)
      ..write(obj.certificates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumeDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContactInfoDataAdapter extends TypeAdapter<ContactInfoData> {
  @override
  final int typeId = 9;

  @override
  ContactInfoData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactInfoData(
      name: fields[0] as String,
      email: fields[1] as String,
      phone: fields[2] as String,
      linkedin: fields[3] as String,
      github: fields[4] as String,
      portfolio: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContactInfoData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.linkedin)
      ..writeByte(4)
      ..write(obj.github)
      ..writeByte(5)
      ..write(obj.portfolio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactInfoDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EducationDataAdapter extends TypeAdapter<EducationData> {
  @override
  final int typeId = 10;

  @override
  EducationData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EducationData(
      school: fields[0] as String,
      degree: fields[1] as String,
      gradDate: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EducationData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.school)
      ..writeByte(1)
      ..write(obj.degree)
      ..writeByte(2)
      ..write(obj.gradDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EducationDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExperienceDataAdapter extends TypeAdapter<ExperienceData> {
  @override
  final int typeId = 11;

  @override
  ExperienceData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExperienceData(
      company: fields[0] as String,
      title: fields[1] as String,
      dates: fields[2] as String,
      responsibilities: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExperienceData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.company)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.dates)
      ..writeByte(3)
      ..write(obj.responsibilities);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExperienceDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CertificateDataAdapter extends TypeAdapter<CertificateData> {
  @override
  final int typeId = 12;

  @override
  CertificateData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CertificateData(
      name: fields[0] as String,
      organization: fields[1] as String,
      date: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CertificateData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.organization)
      ..writeByte(2)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
