import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/material_files.dart';
import '../services/material_storage.dart';
import 'common.dart';
import 'flex_modal.dart';

class MaterialPdf extends StatefulWidget {
  const MaterialPdf({
    super.key,
    required this.fileKey,
    required this.title,
    this.files = const LocalMaterialFiles(),
  });
  final String fileKey, title;
  final MaterialFiles files;
  @override
  State<MaterialPdf> createState() => _MaterialPdfState();
}

class _MaterialPdfState extends State<MaterialPdf> {
  late final Future<Uint8List> bytes = widget.files.read(widget.fileKey);
  @override
  Widget build(BuildContext context) => FlexModal(
    maxWidth: 1100,
    title: Text(widget.title),
    onClose: () => Navigator.pop(context),
    scrollable: false,
    content: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: FutureBuilder<Uint8List>(
        future: bytes,
        builder: (ctx, s) {
          if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfViewer.data(s.data!, sourceName: widget.fileKey);
        },
      ),
    ),
  );
}
