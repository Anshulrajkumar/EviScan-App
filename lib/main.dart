import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final cameras = await availableCameras();
  runApp(EvidenceRecorderApp(cameras: cameras));
}

class EvidenceRecorderApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const EvidenceRecorderApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _EvidenceRecorderAppState createState() => _EvidenceRecorderAppState();
}

class _EvidenceRecorderAppState extends State<EvidenceRecorderApp> {
  CameraController? _controller;
  bool _isCameraOpen = false;
  ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
  }

  void _toggleCamera() async {
    if (_isCameraOpen) {
      await _controller?.dispose();
      setState(() {
        _isCameraOpen = false;
        _controller = null;
      });
    } else {
      if (widget.cameras.isNotEmpty) {
        try {
          _controller = CameraController(widget.cameras[0], ResolutionPreset.veryHigh);
          await _controller?.initialize();
          setState(() {
            _isCameraOpen = true;
          });
        } catch (e) {
          print("Error initializing camera: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to open camera. Please check permissions.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No cameras found.")),
        );
      }
    }
  }


  Future<void> _takeScreenshotAndSendToTelegram() async {
    Uint8List? image = await screenshotController.capture();

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      File file = File(filePath);
      await file.writeAsBytes(image);

      _sendToTelegram(file);
    }
  }

  Future<void> _sendToTelegram(File file) async {
    String botToken = "7611215096:AAFuOhGK1I9IqAeIQ7aTG5lJ6JxFneNEx7Y";  // Replace with your Telegram bot token
    String chatId = "6324700199";      // Replace with your chat ID

    var url = Uri.parse("https://api.telegram.org/bot$botToken/sendPhoto");

    var request = http.MultipartRequest("POST", url)
      ..fields['chat_id'] = chatId
      ..files.add(await http.MultipartFile.fromPath('photo', file.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Evidence sent to FSL!"))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send Evidence."))
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Screenshot(
        controller: screenshotController,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text(
              'National Forensic Sciences University - Evidence Capture',
              style: TextStyle(color: Colors.orange),
            ),
            backgroundColor: Colors.black,
          ),
          body: Column(
            children: [
              Expanded(
                child: _isCameraOpen && _controller != null && _controller!.value.isInitialized
                    ? CameraPreview(_controller!)
                    : const Center(child: Text('Camera is off, press open camera to turn it on.', style: TextStyle(color: Colors.white))),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[900],
                child: const Text(
                  'STATUS: IDLE | LOCATION: Imphal, India (24.809, 93.941)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _toggleCamera,
                    child: Text(_isCameraOpen ? 'Close Camera' : 'Open Camera'),
                  ),
                  ElevatedButton(
                    onPressed: _takeScreenshotAndSendToTelegram,
                    child: const Text("Send Evidence to FSL"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
