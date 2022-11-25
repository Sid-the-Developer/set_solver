import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:opencv_4/factory/pathfrom.dart';
import 'package:opencv_4/opencv_4.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Set Solver',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.red,
      ),
      home: const MyHomePage(title: 'Set Solver'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late CameraController _controller;
  final ValueNotifier<Uint8List> _cvImage = ValueNotifier(Uint8List(0));
  final ValueNotifier<File> _originalImage = ValueNotifier(File(""));
  final Directory gallery =
      Directory('/storage/emulated/0/Download/SET Solver');
  late final _picker = ImagePicker();
  final Map<String, dynamic> threshDefaults = {
    'thresholdValue': 125,
    'maxThresholdValue': 255,
    'thresholdType': Cv2.THRESH_OTSU
  };
  final Map<String, int> thresholdTypes = {
    'Otsu': Cv2.THRESH_OTSU,
    'Binary': Cv2.THRESH_BINARY,
    'Binary Invert': Cv2.THRESH_BINARY_INV,
    'Mask': Cv2.THRESH_MASK,
    'To Zero': Cv2.THRESH_TOZERO,
    'To Zero Invert': Cv2.THRESH_TOZERO_INV,
    'Triangle': Cv2.THRESH_TRIANGLE,
    'Truncate': Cv2.THRESH_TRUNC
  };
  final Map<String, dynamic> adaptiveThreshDefaults = {
    'adaptiveMethod': Cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
    'maxValue': 255,
    'thresholdType': Cv2.THRESH_OTSU,
    'blockSize': 5,
    'constantValue': 12
  };
  final Map<String, dynamic> scharrDefaults = {'dx': 0, 'dy': 1};
  final Map<String, dynamic> sobelDefaults = {'dx': 1, 'dy': 1};
  final Map<String, dynamic> morphDefaults = {
    'operation': Cv2.MORPH_GRADIENT,
    'kernelSize': 5
  };
  final Map<String, int> morphTypes = {
    'Gradient': Cv2.MORPH_GRADIENT,
    'Black Hat': Cv2.MORPH_BLACKHAT,
    'Close': Cv2.MORPH_CLOSE,
    'Open': Cv2.MORPH_OPEN,
    'Dilate': Cv2.MORPH_DILATE,
    'Erode': Cv2.MORPH_ERODE,
    'Hit Miss': Cv2.MORPH_HITMISS,
    'Top Hat': Cv2.MORPH_TOPHAT
  };
  final Map<String, dynamic> laplacian = {'depth': -1};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _controller = CameraController(cameras.first, ResolutionPreset.max);
    _controller.initialize().then((_) => mounted ? setState(() {}) : null);
    WidgetsBinding.instance.addObserver(this);
  }

  void _requestPermissions() async {
    if ((await Permission.manageExternalStorage.request()).isGranted) {
      if (!await gallery.exists()) gallery.create(recursive: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.initialize().then((_) => mounted ? setState(() {}) : null);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller.pausePreview();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// display dialog and return values in map based on [options]
  Future<Map<String, dynamic>?> _pickOption(
      {required Map<String, Widget> options,
      required Map<String, dynamic> returnMap}) {
    assert(options.isNotEmpty);

    Map<String, dynamic> values = returnMap;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        contentPadding: const EdgeInsets.all(12),
        title: const Text('Options'),
        children: [
          ...options.entries
              .map<Widget>((e) =>
                  // returns a text with the field name followed by the widget returned by the function value
                  Row(
                    children: [
                      Expanded(child: Text(e.key)),
                      Expanded(
                          child:e.value)
                    ],
                  ))
              .toList(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(values),
            child: const Center(child: Text('OK')),
          )
        ],
      ),
    );
  }

  Widget _createDropdown<T>(
      {required Map<String, T> values,
      Function(T?)? onChanged,
      T? defaultValue}) {
    ValueNotifier<T?> valueNotifier = ValueNotifier(defaultValue);
    return ValueListenableBuilder(
      valueListenable: valueNotifier,
      builder: (context, T? value, child) => DropdownButton<T>(
        items: values.entries
            .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
            .toList(),
        value: value,
        onChanged: (T? newValue) {
          valueNotifier.value = newValue;
          onChanged!(newValue);
        },
      ),
    );
  }

  Widget _createNumericField(
      {TextEditingController? controller, void Function(String)? onChanged}) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  /// gets file path from image taken with camera picker
  Future<String> _imagePath() async {
    Map<String, dynamic>? mapForReturn = {};
    Map<String, dynamic>? values = await _pickOption(options: {
      'source': _createDropdown<ImageSource>(
        values: {'Camera': ImageSource.camera, 'Gallery': ImageSource.gallery},
        onChanged: (newValue) {
          mapForReturn['source'] = newValue;
        },
        defaultValue: ImageSource.camera,
      ),
    }, returnMap: mapForReturn);
    if (values != null) {
      _controller.pausePreview();
      XFile? pickedFile = await _picker.pickImage(
          source: values['source'] ?? ImageSource.camera);
      _originalImage.value = File(pickedFile!.path);
      _controller.resumePreview();
      return pickedFile.path;
    } else {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
        ), //TODO add blocky font
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Make sure the entire board is clearly in view',
                ),
                CameraPreview(_controller),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(threshDefaults);
                            List<TextEditingController> controllers = [];
                            for (String field in [
                              'thresholdValue',
                              'maxThresholdValue'
                            ]) {
                              controllers.add(TextEditingController(
                                  text: '${threshDefaults[field]}'));
                            }

                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'thresholdValue': _createNumericField(
                                  controller: controllers[0],
                                  onChanged: (newText) =>
                                      mapForReturn['thresholdValue'] = double.parse(newText)),
                              'maxThresholdValue': _createNumericField(
                                  controller: controllers[1],
                                  onChanged: (newText) =>
                                      mapForReturn['maxThresholdValue'] =
                                          double.parse(newText)),
                              'thresholdType': _createDropdown(
                                  values: thresholdTypes,
                                  defaultValue: threshDefaults['thresholdType'],
                                  onChanged: (newValue) =>
                                      mapForReturn['thresholdType'] = newValue)
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              // if null barrier dismissed
                              _cvImage.value = await Cv2.threshold(
                                      pathFrom: CVPathFrom.GALLERY_CAMERA,
                                      pathString: await _imagePath(),
                                      thresholdValue:
                                          values['thresholdValue'] / 1.0,
                                      maxThresholdValue:
                                          values['maxThresholdValue'] / 1.0,
                                      thresholdType: values['thresholdType']) ??
                                  Uint8List(0);
                            }
                          },
                          child: const Text('Threshold')),
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(adaptiveThreshDefaults);
                            List<TextEditingController> controllers = [];
                            for (String field in [
                              'blockSize',
                              'maxValue',
                              'constantValue'
                            ]) {
                              controllers.add(TextEditingController(
                                  text: '${adaptiveThreshDefaults[field]}'));
                            }

                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'blockSize': _createNumericField(
                                  controller: controllers[0],
                                  onChanged: (newText) =>
                                      mapForReturn['blockSize'] = int.parse(newText)),
                              'maxValue': _createNumericField(
                                  controller: controllers[1],
                                  onChanged: (newText) =>
                                      mapForReturn['maxValue'] = double.parse(newText)),
                              'constantValue': _createNumericField(
                                  controller: controllers[2],
                                  onChanged: (newText) =>
                                      mapForReturn['constantValue'] = double.parse(newText)),
                              'adaptiveMethod': _createDropdown(
                                  values: {
                                    'Gaussian': Cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                    'Mean': Cv2.ADAPTIVE_THRESH_MEAN_C
                                  },
                                  defaultValue:
                                      adaptiveThreshDefaults['adaptiveMethod'],
                                  onChanged: (newValue) =>
                                      mapForReturn['adaptiveMethod'] =
                                          newValue),
                              'thresholdType': _createDropdown(
                                  values: thresholdTypes,
                                  defaultValue:
                                      adaptiveThreshDefaults['thresholdType'],
                                  onChanged: (newValue) =>
                                      mapForReturn['thresholdType'] = newValue)
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              _cvImage.value = await Cv2.adaptiveThreshold(
                                  pathFrom: CVPathFrom.GALLERY_CAMERA,
                                  pathString: await _imagePath(),
                                  maxValue: values['maxValue'] / 1.0,
                                  adaptiveMethod: values['adaptiveMethod'],
                                  thresholdType: values['thresholdType'],
                                  blockSize: values['blockSize'],
                                  constantValue: values['constantValue'] / 1.0);
                            }
                          },
                          child: const Text('Adaptive Threshold')),
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(scharrDefaults);
                            List<TextEditingController> controllers = [];
                            for (String field in ['dx', 'dy']) {
                              controllers.add(TextEditingController(
                                  text: '${scharrDefaults[field]}'));
                            }
                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'dx': _createNumericField(
                                  controller: controllers[0],
                                  onChanged: (newText) =>
                                      mapForReturn['dx'] = int.parse(newText)),
                              'dy': _createNumericField(
                                  controller: controllers[1],
                                  onChanged: (newText) =>
                                      mapForReturn['dy'] = int.parse(newText))
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              _cvImage.value = await Cv2.scharr(
                                      pathFrom: CVPathFrom.GALLERY_CAMERA,
                                      pathString: await _imagePath(),
                                      depth: Cv2.CV_SCHARR,
                                      dx: values['dx'],
                                      dy: values['dy']) ??
                                  Uint8List(0);
                            }
                          },
                          child: const Text('Scharr')),
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(sobelDefaults);
                            List<TextEditingController> controllers = [];
                            for (String field in ['dx', 'dy']) {
                              controllers.add(TextEditingController(
                                  text: '${sobelDefaults[field]}'));
                            }
                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'dx': _createNumericField(
                                  controller: controllers[0],
                                  onChanged: (newText) =>
                                      mapForReturn['dx'] = int.parse(newText)),
                              'dy': _createNumericField(
                                  controller: controllers[1],
                                  onChanged: (newText) =>
                                      mapForReturn['dy'] = int.parse(newText)),
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              _cvImage.value = await Cv2.sobel(
                                      pathFrom: CVPathFrom.GALLERY_CAMERA,
                                      pathString: await _imagePath(),
                                      depth: -1,
                                      dx: 1,
                                      dy: 1) ??
                                  Uint8List(0);
                            }
                          },
                          child: const Text('Sobel')),
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(morphDefaults);
                            TextEditingController kernelController =
                                TextEditingController(
                                    text: '${morphDefaults['kernelSize']}');

                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'kernelSize': _createNumericField(
                                  controller: kernelController,
                                  onChanged: (newText) =>
                                      mapForReturn['kernelSize'] = int.parse(newText)),
                              'operation': _createDropdown<int>(
                                  values: morphTypes,
                                  defaultValue: morphDefaults['operation'],
                                  onChanged: (newValue) =>
                                      mapForReturn['operation'] = newValue)
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              print('\n\noperation: ${values['operation']}\n\n');

                              _cvImage.value = await Cv2.morphologyEx(
                                      pathFrom: CVPathFrom.GALLERY_CAMERA,
                                      pathString: await _imagePath(),
                                      operation: values['operation'],
                                      kernelSize: [
                                        values['kernelSize'],
                                        values['kernelSize']
                                      ]) ??
                                  Uint8List(0);
                            }
                          },
                          child: const Text('MorphologyEx')),
                      TextButton(
                          onPressed: () async {
                            Map<String, dynamic>? mapForReturn = Map.of(laplacian);
                            TextEditingController depthController =
                                TextEditingController(
                                    text: '${laplacian['depth']}');

                            Map<String, dynamic>? values =
                                await _pickOption(options: {
                              'depth': _createNumericField(
                                  controller: depthController,
                                  onChanged: (newText) =>
                                      mapForReturn['depth'] = int.parse(newText))
                            }, returnMap: mapForReturn);

                            if (values != null) {
                              _cvImage.value = await Cv2.laplacian(
                                      pathFrom: CVPathFrom.GALLERY_CAMERA,
                                      pathString: await _imagePath(),
                                      depth: values['depth']) ??
                                  Uint8List(0);
                            }
                          },
                          child: const Text('Laplacian')),
                    ],
                  ),
                ),
                InteractiveViewer(
                  clipBehavior: Clip.none,
                  child: GestureDetector(
                      onDoubleTap: () async {
                        await Permission.manageExternalStorage.request();
                        DateTime now = DateTime.now();
                        String fileData =
                            DateFormat('yyyyMMdd_HHmmss').format(now);
                        XFile.fromData(_cvImage.value)
                            .saveTo('${gallery.path}/$fileData.jpg');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Image saved to ${gallery.path}')));
                        }
                      },
                      child: ValueListenableBuilder(
                          valueListenable: _cvImage,
                          builder: (context, Uint8List imageBytes, child) =>
                              Image.memory(imageBytes))),
                ),
                InteractiveViewer(
                    clipBehavior: Clip.none,
                    child: GestureDetector(
                      onDoubleTap: () async {
                        await Permission.manageExternalStorage.request();
                        DateTime now = DateTime.now();
                        String fileData =
                            DateFormat('yyyyMMdd_HHmmss').format(now);
                        XFile(_originalImage.value.path)
                            .saveTo('${gallery.path}/$fileData.jpg');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Image saved to ${gallery.path}')));
                        }
                      },
                      child: ValueListenableBuilder(
                          valueListenable: _originalImage,
                          builder: (context, File image, child) =>
                              Image.file(image)),
                    ))
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.takePicture(),
        // TODO implement camera api image stream
        tooltip: 'Capture board',
        child: const Icon(Icons.camera),
      ), // This trailing comma makes auto-formatting nicer for build methods.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
