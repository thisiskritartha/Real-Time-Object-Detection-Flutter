import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;
  bool isBusy = false;
  CameraImage? cameraImage;
  dynamic objectDetector;
  dynamic scannedResult;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  initializeCamera() async {
    const mode = DetectionMode.stream;
    final ObjectDetectorOptions options = ObjectDetectorOptions(
        mode: mode, classifyObjects: true, multipleObjects: true);
    objectDetector = ObjectDetector(options: options);

    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      controller.startImageStream((image) => {
            if (!isBusy)
              {
                isBusy = true,
                cameraImage = image,
                doObjectDetectionOnFrame(),
              }
          });
    });
  }

  doObjectDetectionOnFrame() async {
    final imgFrame = getInputImage();
    final List<DetectedObject> objects =
        await objectDetector.processImage(imgFrame);
    scannedResult = objects;
    print('${objects.length} 💥💥');
    for (DetectedObject object in objects) {
      final rect = object.boundingBox;
      final trackingId = object.trackingId;

      for (Label label in object.labels) {
        print('${label.text}: ${label.confidence}💥💥');
      }
    }
    setState(() {
      isBusy = false;
    });
  }

  Widget buildResult() {
    if (scannedResult == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Text('');
    }
    final Size imageSize = Size(controller.value.previewSize!.height,
        controller.value.previewSize!.width);
    CustomPainter? painter = ObjectDetectorPainter(imageSize, scannedResult);
    return CustomPaint(
      painter: painter,
    );
  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(cameraImage!.width.toDouble(), cameraImage!.height.toDouble());

    final camera = cameras[0];
    final InputImageRotation? imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);

    final InputImageFormat? inputImageFormat =
        InputImageFormatValue.fromRawValue(cameraImage!.format.raw);

    final planeData = cameraImage!.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );
    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    Size size = MediaQuery.of(context).size;

    stackChildren.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height,
        child: Container(
          child: (controller.value.isInitialized)
              ? AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller),
                )
              : Container(),
        ),
      ),
    );

    stackChildren.add(Positioned(
      top: 0,
      left: 0,
      width: size.width,
      height: size.height,
      child: buildResult(),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Object Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey,
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this.absoluteSize, this.objects);

  List<DetectedObject> objects;
  final Size absoluteSize;

  @override
  void paint(Canvas canvas, Size size) {
    double scaleX = size.width / absoluteSize.width;
    double scaleY = size.height / absoluteSize.height;

    final Paint p = Paint();
    p.color = Colors.green;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 6;

    for (DetectedObject obj in objects) {
      canvas.drawRect(
          Rect.fromLTRB(
            obj.boundingBox.left * scaleX,
            obj.boundingBox.top * scaleY,
            obj.boundingBox.right * scaleX,
            obj.boundingBox.bottom * scaleY,
          ),
          p);
      for (Label label in obj.labels) {
        TextSpan span = TextSpan(
            text: '${label.text}: ${label.confidence.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ));
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
            canvas,
            Offset(
                obj.boundingBox.left * scaleX, obj.boundingBox.top * scaleY));
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
