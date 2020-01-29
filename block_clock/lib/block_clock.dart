// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'stage.dart';
import 'control.dart';

class BlockClock extends StatefulWidget {
  const BlockClock(this.model);

  final ClockModel model;

  @override
  _BlockClockState createState() => _BlockClockState();
}

class _BlockClockState extends State<BlockClock> with TickerProviderStateMixin {
  var _now = DateTime.now();
  var _temperature = '';
  var _condition = '';
  var _location = '';
  Timer _timer;

  Scene scene;
  ClockTimeControl _clockControl = ClockTimeControl();
  ClockHandControl _clockHandControl = ClockHandControl();

  AnimationController _cameraController;
  Animation<Matrix4> _cameraAnimation;
  int cameraAnimateIndex = -1;
  List<Matrix4> cameraAnimateMatrix = [
    makeViewMatrix(Vector3(0.0, 0.0, 1000.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
    makeViewMatrix(Vector3(-500.0, 0.0, 800.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
    makeViewMatrix(Vector3(-500.0, 0.0, 800.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
    makeViewMatrix(Vector3(0.0, 0.0, 1000.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
    makeViewMatrix(Vector3(500.0, 0.0, 800.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
    makeViewMatrix(Vector3(500.0, 0.0, 800.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)),
  ];

  void _updateCamera() {
    scene.camera.transform.setFrom(_cameraAnimation.value);
    scene.update();
  }

  void _updateCameraStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      cameraAnimateIndex = (cameraAnimateIndex + 1) % cameraAnimateMatrix.length;
      final Matrix4 nextMatrix = cameraAnimateMatrix[(cameraAnimateIndex) % cameraAnimateMatrix.length];
      _cameraAnimation = Matrix4Tween(
        begin: scene.camera.transform.clone(),
        end: nextMatrix,
      ).animate(CurveTween(curve: Curves.easeInOutCubic).animate(_cameraController));
      _cameraController.duration = Duration(seconds: 5);
      _cameraController
        ..reset()
        ..forward();
    }
  }

  void _onSceneCreated(Scene scene) {
    this.scene = scene;
    scene.camera.position.setFrom(Vector3(0.0, -500.0, 1500.0));
    scene.camera.target.setFrom(Vector3(0.0, 0.0, 0.0));
    scene.camera.up.setFrom(Vector3(0.0, 1.0, 0.0));
    scene.camera.updateTransform();
    // Animate camera
    _updateCameraStatus(AnimationStatus.completed);
  }

  void _updateTime() {
    final DateTime last = _now;
    _now = DateTime.now();
    if (last.day != _now.day) setState(() {});
    _timer = Timer(
      Duration(seconds: 60) - Duration(milliseconds: _now.second * 1000 + _now.millisecond),
      _updateTime,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
    _cameraController = AnimationController(vsync: this, duration: Duration(seconds: 3))
      ..addListener(_updateCamera)
      ..addStatusListener(_updateCameraStatus);
  }

  @override
  void didUpdateWidget(BlockClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    super.dispose();
    _cameraController.dispose();
  }

  void _updateModel() {
    setState(() {
      _temperature = '${widget.model.temperature.toStringAsFixed(0)}${widget.model.unitString}';
      _condition = widget.model.weatherString;
      _location = widget.model.location;
    });
  }

  Actor makeBlock({String name, Vector3 position, double size, List<Actor> faces}) {
    final double radius = size / 2 - size * 0.0015;
    return Actor(name: name, position: position, children: [
      Actor(name: faces[0].name, position: Vector3(0, 0, radius), rotation: Vector3(0, 0, 0), width: size, height: size, widget: faces[0].widget, children: faces[0].children),
      Actor(name: faces[1].name, position: Vector3(radius, 0, 0), rotation: Vector3(0, 90, 0), width: size, height: size, widget: faces[1].widget, children: faces[1].children),
      Actor(name: faces[2].name, position: Vector3(0, 0, -radius), rotation: Vector3(0, 180, 0), width: size, height: size, widget: faces[2].widget, children: faces[2].children),
      Actor(name: faces[3].name, position: Vector3(-radius, 0, 0), rotation: Vector3(0, 270, 0), width: size, height: size, widget: faces[3].widget, children: faces[3].children),
      Actor(name: faces[4].name, position: Vector3(0, -radius, 0), rotation: Vector3(90, 0, 0), width: size, height: size, widget: faces[4].widget, children: faces[4].children),
      Actor(name: faces[5].name, position: Vector3(0, radius, 0), rotation: Vector3(270, 0, 0), width: size, height: size, widget: faces[5].widget, children: faces[5].children),
    ]);
  }

  Widget makeBlockFace(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromRGBO(77, 77, 77, 1.0), width: size * 0.005),
        gradient: LinearGradient(
          colors: [Color.fromRGBO(25, 25, 25, 1.0), Color.fromRGBO(56, 56, 56, 1.0), Color.fromRGBO(25, 25, 25, 1.0)],
          stops: [0.1, 0.5, 0.9],
          begin: FractionalOffset.topRight,
          end: FractionalOffset.bottomLeft,
          tileMode: TileMode.repeated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double blockSize = 600;
    final String time = DateFormat.Hms().format(DateTime.now());
    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: 'Analog clock with time $time',
        value: time,
      ),
      child: FittedBox(
        child: Container(
          width: 500,
          height: 298,
          color: Color.fromRGBO(19, 19, 19, 1.0),
          child: Stage(
            interactive: false, // enable interactive need to remove _updateCameraStatus(AnimationStatus.completed)
            onSceneCreated: _onSceneCreated,
            children: [
              makeBlock(name: 'block', position: Vector3(0, 0, 0), size: blockSize * 1.1, faces: [
                Actor(
                  name: 'front',
                  widget: makeBlockFace(blockSize),
                  children: [
                    Actor(
                      position: Vector3(0, 0, blockSize * 0.06),
                      width: blockSize,
                      height: blockSize,
                      widget: Container(key: ValueKey('hour'), child: FlareActor('assets/clock/hour.flr', animation: 'idle', controller: _clockControl)),
                    ),
                    Actor(
                      position: Vector3(0, 0, 0),
                      width: blockSize,
                      height: blockSize,
                      widget: Container(key: ValueKey('minute'), child: FlareActor('assets/clock/minute.flr')),
                    ),
                    Actor(
                      position: Vector3(0, 0, blockSize * 0.068),
                      width: blockSize,
                      height: blockSize,
                      widget: Container(key: ValueKey('hour_hand'), child: FlareActor('assets/clock/hand.flr', controller: _clockHandControl)),
                    ),
                  ],
                ),
                Actor(
                  name: 'right',
                  widget: makeBlockFace(blockSize),
                  children: [
                    Actor(
                      position: Vector3(0, 0, 0),
                      width: blockSize,
                      height: blockSize * 0.85,
                      widget: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              DateFormat('MMMM').format(DateTime.now()),
                              style: TextStyle(fontSize: blockSize * 0.15, color: Colors.white.withOpacity(0.5)),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              DateFormat('EEEE').format(DateTime.now()),
                              style: TextStyle(fontSize: blockSize * 0.13, color: Colors.white.withOpacity(0.5)),
                            ),
                          )
                        ],
                      ),
                    ),
                    Actor(
                      position: Vector3(0, 0, blockSize * 0.02),
                      width: blockSize,
                      height: blockSize,
                      widget: Center(
                        child: Text(
                          DateFormat('d').format(DateTime.now()),
                          style: TextStyle(fontSize: blockSize * 0.5, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ),
                    Actor(
                      position: Vector3(0, 0, 0),
                      width: blockSize,
                      height: blockSize,
                      widget: Center(
                        child: Text(
                          DateFormat('d').format(DateTime.now()),
                          style: TextStyle(fontSize: blockSize * 0.5, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
                Actor(name: 'back', widget: makeBlockFace(blockSize)),
                Actor(
                  name: 'left',
                  widget: makeBlockFace(blockSize),
                  children: [
                    Actor(
                      position: Vector3(0, 0, 0),
                      width: blockSize,
                      height: blockSize * 0.85,
                      widget: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topCenter,
                            child: FittedBox(child: Text(_location, style: TextStyle(fontSize: blockSize * 0.09, color: Colors.white.withOpacity(0.35)))),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(_condition, style: TextStyle(fontSize: blockSize * 0.13, color: Colors.white.withOpacity(0.5))),
                          ),
                        ],
                      ),
                    ),
                    Actor(
                      position: Vector3(0, 0, blockSize * 0.02),
                      width: blockSize,
                      height: blockSize,
                      widget: Center(
                        child: Text(
                          _temperature,
                          style: TextStyle(fontSize: blockSize / 3, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ),
                    Actor(
                      position: Vector3(0, 0, 0),
                      width: blockSize,
                      height: blockSize,
                      widget: Center(
                        child: Text(
                          _temperature,
                          style: TextStyle(fontSize: blockSize / 3, color: Colors.black.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
                Actor(name: 'top', widget: makeBlockFace(blockSize)),
                Actor(name: 'bottom', widget: makeBlockFace(blockSize)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
