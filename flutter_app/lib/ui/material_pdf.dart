import 'dart:typed_data';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/material.dart';
import 'common.dart';
import 'flex_modal.dart';

class MaterialPdf extends StatefulWidget {
  const MaterialPdf({super.key, required this.fileKey, required this.title});
  final String fileKey, title;
  @override
  State<MaterialPdf> createState() => _MaterialPdfState();
}

class _MaterialPdfState extends State<MaterialPdf> {
  late final Future<int> count = FlexDevice.channel
      .invokeMapMethod<String, dynamic>('pdfMaterialInfo', {
        'key': widget.fileKey,
      })
      .then((v) => v!['pages'] as int);
  int page = 0;
  late Future<Uint8List?> rendered = render();
  Future<Uint8List?> render() => FlexDevice.channel.invokeMethod<Uint8List>(
    'renderMaterialPage',
    {'key': widget.fileKey, 'page': page, 'width': 1200},
  );
  @override
  Widget build(BuildContext context) => FlexModal(
    maxWidth: 1000,
    title: Text(widget.title),
    onClose: () => Navigator.pop(context),
    scrollable: false,
    content: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: FutureBuilder<int>(
        future: count,
        builder: (ctx, s) {
          if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: FutureBuilder<Uint8List?>(
                  future: rendered,
                  builder: (ctx, image) {
                    if (image.hasError) {
                      return Center(child: Text(friendlyError(image.error!)));
                    }
                    if (!image.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return InteractiveViewer(
                      key: ValueKey(page),
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          image.data!,
                          fit: BoxFit.contain,
                          semanticLabel: 'PDF-Seite ${page + 1}',
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Vorherige Seite',
                    onPressed: page == 0
                        ? null
                        : () => setState(() {
                            page--;
                            rendered = render();
                          }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Flexible(child: Text('${page + 1} / ${s.data}')),
                  IconButton(
                    tooltip: 'Nächste Seite',
                    onPressed: page + 1 >= s.data!
                        ? null
                        : () => setState(() {
                            page++;
                            rendered = render();
                          }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
