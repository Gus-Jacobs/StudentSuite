import 'package:flutter/material.dart';

class EditorField extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle? style;
  final int? maxLines;
  final String hintText;
  final FontWeight? fontWeight;

  const EditorField({
    super.key,
    required this.controller,
    this.style,
    this.maxLines = 1,
    this.hintText = '',
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: style?.copyWith(fontWeight: fontWeight),
      decoration: InputDecoration.collapsed(
        hintText: hintText,
        hintStyle: style?.copyWith(color: Colors.grey),
      ),
    );
  }
}
