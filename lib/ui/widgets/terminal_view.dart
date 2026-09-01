import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/ui/app_theme.dart';

class TerminalView extends StatefulWidget {
  final DownloadController controller;

  const TerminalView({super.key, required this.controller});

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terminal',
            style: TText.display(context, size: 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TColors.jackBg,
                border: Border.all(color: TColors.line),
              ),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: widget.controller.log.length,
                    itemBuilder: (context, index) {
                      final line = widget.controller.log[index];
                      final isError =
                          line.startsWith('ERROR:') || line.contains('Error');
                      return SelectableText(
                        line,
                        style: TText.mono(
                          context,
                          size: 11.5,
                          color: isError ? TColors.red : TColors.textMuted,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
