import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../di.dart';
import '../../../gen/assets.gen.dart';
import '../../../l10n/l10n.dart';
import '../../../routes.gr.dart';
import '../../../ui/dialogs.dart';
import '../../../ui/theme.dart';
import '../models/qr_scanner_request.dart';
import '../services/qr_scanner_bloc.dart';
import '../widgets/qr_scanner_background.dart';

@RoutePage<QrScannerRequest>()
class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({
    super.key,
  });

  static const route = QrScannerRoute.new;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<QrScannerBloc>(),
        child: const _Content(),
      );
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  bool _flashEnabled = false;
  bool _cameraEnabled = false;

  @override
  void initState() {
    super.initState();
    context.read<QrScannerBloc>().add(const QrScannerEvent.initialized());
    _qrViewController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    )..start()
        .then((it) => it != null)
        .then(_onPermissionSet)
        .catchError((_) => _onPermissionSet(false));
  }

  @override
  void dispose() {
    _qrViewController.dispose();
    super.dispose();
  }

  void _onQRScanError() => showWarningDialog(
        context,
        title: context.l10n.qrCodeScanErrorTitle,
        message: context.l10n.qrCodeScanErrorContent,
      );

  Future<void> _onQRToggleFlash() async {
    await _qrViewController.toggleTorch();
    if (!mounted) return;

    setState(() => _flashEnabled = !_flashEnabled);
  }

  void _onBlocChange(BuildContext context, QrScannerState state) {
    state.map(
      initial: (_) {},
      done: (d) {
        _qrViewController.stop();
        _onScanComplete(d.request);
      },
      error: (_) {
        _qrViewController.stop();
        _onQRScanError();

        context.router.pop();
      },
    );
  }

  void _onCloseButtonPressed() {
    _qrViewController.stop();
    context.router.pop();
  }

  void _onPermissionSet(bool allowed) {
    if (!mounted) return;
    if (_cameraEnabled != allowed) setState(() => _cameraEnabled = allowed);
  }

  void _onDetected(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) {
      context.read<QrScannerBloc>().add(QrScannerEvent.received(code));
    }
  }

  void _onScanComplete([QrScannerRequest? request]) =>
      context.router.pop(request);

  @override
  Widget build(BuildContext _) => BlocListener<QrScannerBloc, QrScannerState>(
        listener: _onBlocChange,
        child: CpTheme.black(
          child: Scaffold(
            body: Stack(
              children: [
                if (_cameraEnabled)
                  QrScannerBackground(
                    child: MobileScanner(
                      key: _qrKey,
                      controller: _qrViewController,
                      onDetect: _onDetected,
                    ),
                  ),
                if (_cameraEnabled)
                  Align(
                    alignment: const Alignment(0, -0.7),
                    child: GestureDetector(
                      onTap: _onQRToggleFlash,
                      child: _flashEnabled
                          ? Assets.images.flashOn.svg()
                          : Assets.images.flashOff.svg(),
                    ),
                  ),
                if (!_cameraEnabled)
                  const Align(
                    alignment: Alignment(0, -0.3),
                    child: _PermissionText(),
                  ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 16,
                      right: 24,
                    ),
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: _onCloseButtonPressed,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  late final MobileScannerController _qrViewController;
}

class _PermissionText extends StatelessWidget {
  const _PermissionText();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedContainer(
          duration: const Duration(seconds: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.qrCameraPermissionTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.qrCameraPermissionMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.3),
              ),
            ],
          ),
        ),
      );
}
