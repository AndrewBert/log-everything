// Mocks generated by Mockito 5.4.6 from annotations
// in myapp/test/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:convert' as _i20;
import 'dart:typed_data' as _i8;

import 'package:flutter_bloc/flutter_bloc.dart' as _i21;
import 'package:http/http.dart' as _i3;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i16;
import 'package:myapp/chat/cubit/chat_cubit.dart' as _i4;
import 'package:myapp/chat/model/chat_message.dart' as _i15;
import 'package:myapp/entry/category.dart' as _i13;
import 'package:myapp/entry/entry.dart' as _i12;
import 'package:myapp/services/ai_service.dart' as _i14;
import 'package:myapp/services/audio_recorder_service.dart' as _i17;
import 'package:myapp/services/entry_persistence_service.dart' as _i11;
import 'package:myapp/services/permission_service.dart' as _i9;
import 'package:myapp/services/vector_store_service.dart' as _i18;
import 'package:myapp/speech_service.dart' as _i5;
import 'package:permission_handler/permission_handler.dart' as _i10;
import 'package:record/record.dart' as _i7;
import 'package:record_platform_interface/record_platform_interface.dart'
    as _i2;
import 'package:shared_preferences/shared_preferences.dart' as _i19;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeAmplitude_0 extends _i1.SmartFake implements _i2.Amplitude {
  _FakeAmplitude_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeResponse_1 extends _i1.SmartFake implements _i3.Response {
  _FakeResponse_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeStreamedResponse_2 extends _i1.SmartFake
    implements _i3.StreamedResponse {
  _FakeStreamedResponse_2(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeChatState_3 extends _i1.SmartFake implements _i4.ChatState {
  _FakeChatState_3(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [SpeechService].
///
/// See the documentation for Mockito's code generation for more information.
class MockSpeechService extends _i1.Mock implements _i5.SpeechService {
  MockSpeechService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<String?> transcribeAudio(
    String? filePath, {
    String? language = 'en',
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #transcribeAudio,
              [filePath],
              {#language: language},
            ),
            returnValue: _i6.Future<String?>.value(),
          )
          as _i6.Future<String?>);
}

/// A class which mocks [AudioRecorder].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudioRecorder extends _i1.Mock implements _i7.AudioRecorder {
  MockAudioRecorder() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<void> start(_i2.RecordConfig? config, {required String? path}) =>
      (super.noSuchMethod(
            Invocation.method(#start, [config], {#path: path}),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<_i6.Stream<_i8.Uint8List>> startStream(_i2.RecordConfig? config) =>
      (super.noSuchMethod(
            Invocation.method(#startStream, [config]),
            returnValue: _i6.Future<_i6.Stream<_i8.Uint8List>>.value(
              _i6.Stream<_i8.Uint8List>.empty(),
            ),
          )
          as _i6.Future<_i6.Stream<_i8.Uint8List>>);

  @override
  _i6.Future<String?> stop() =>
      (super.noSuchMethod(
            Invocation.method(#stop, []),
            returnValue: _i6.Future<String?>.value(),
          )
          as _i6.Future<String?>);

  @override
  _i6.Future<void> cancel() =>
      (super.noSuchMethod(
            Invocation.method(#cancel, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<void> pause() =>
      (super.noSuchMethod(
            Invocation.method(#pause, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<void> resume() =>
      (super.noSuchMethod(
            Invocation.method(#resume, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<bool> isRecording() =>
      (super.noSuchMethod(
            Invocation.method(#isRecording, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> isPaused() =>
      (super.noSuchMethod(
            Invocation.method(#isPaused, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> hasPermission() =>
      (super.noSuchMethod(
            Invocation.method(#hasPermission, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<List<_i2.InputDevice>> listInputDevices() =>
      (super.noSuchMethod(
            Invocation.method(#listInputDevices, []),
            returnValue: _i6.Future<List<_i2.InputDevice>>.value(
              <_i2.InputDevice>[],
            ),
          )
          as _i6.Future<List<_i2.InputDevice>>);

  @override
  _i6.Future<_i2.Amplitude> getAmplitude() =>
      (super.noSuchMethod(
            Invocation.method(#getAmplitude, []),
            returnValue: _i6.Future<_i2.Amplitude>.value(
              _FakeAmplitude_0(this, Invocation.method(#getAmplitude, [])),
            ),
          )
          as _i6.Future<_i2.Amplitude>);

  @override
  _i6.Future<bool> isEncoderSupported(_i2.AudioEncoder? encoder) =>
      (super.noSuchMethod(
            Invocation.method(#isEncoderSupported, [encoder]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<void> dispose() =>
      (super.noSuchMethod(
            Invocation.method(#dispose, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Stream<_i2.RecordState> onStateChanged() =>
      (super.noSuchMethod(
            Invocation.method(#onStateChanged, []),
            returnValue: _i6.Stream<_i2.RecordState>.empty(),
          )
          as _i6.Stream<_i2.RecordState>);

  @override
  _i6.Stream<_i2.Amplitude> onAmplitudeChanged(Duration? interval) =>
      (super.noSuchMethod(
            Invocation.method(#onAmplitudeChanged, [interval]),
            returnValue: _i6.Stream<_i2.Amplitude>.empty(),
          )
          as _i6.Stream<_i2.Amplitude>);

  @override
  List<int> convertBytesToInt16(
    _i8.Uint8List? bytes, [
    dynamic endian = _i8.Endian.little,
  ]) =>
      (super.noSuchMethod(
            Invocation.method(#convertBytesToInt16, [bytes, endian]),
            returnValue: <int>[],
          )
          as List<int>);
}

/// A class which mocks [PermissionService].
///
/// See the documentation for Mockito's code generation for more information.
class MockPermissionService extends _i1.Mock implements _i9.PermissionService {
  MockPermissionService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i10.PermissionStatus> getMicrophoneStatus() =>
      (super.noSuchMethod(
            Invocation.method(#getMicrophoneStatus, []),
            returnValue: _i6.Future<_i10.PermissionStatus>.value(
              _i10.PermissionStatus.denied,
            ),
          )
          as _i6.Future<_i10.PermissionStatus>);

  @override
  _i6.Future<_i10.PermissionStatus> requestMicrophonePermission() =>
      (super.noSuchMethod(
            Invocation.method(#requestMicrophonePermission, []),
            returnValue: _i6.Future<_i10.PermissionStatus>.value(
              _i10.PermissionStatus.denied,
            ),
          )
          as _i6.Future<_i10.PermissionStatus>);
}

/// A class which mocks [EntryPersistenceService].
///
/// See the documentation for Mockito's code generation for more information.
class MockEntryPersistenceService extends _i1.Mock
    implements _i11.EntryPersistenceService {
  MockEntryPersistenceService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<List<_i12.Entry>> loadEntries() =>
      (super.noSuchMethod(
            Invocation.method(#loadEntries, []),
            returnValue: _i6.Future<List<_i12.Entry>>.value(<_i12.Entry>[]),
          )
          as _i6.Future<List<_i12.Entry>>);

  @override
  _i6.Future<void> saveEntries(List<_i12.Entry>? entries) =>
      (super.noSuchMethod(
            Invocation.method(#saveEntries, [entries]),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<List<_i13.Category>> loadCategories() =>
      (super.noSuchMethod(
            Invocation.method(#loadCategories, []),
            returnValue: _i6.Future<List<_i13.Category>>.value(
              <_i13.Category>[],
            ),
          )
          as _i6.Future<List<_i13.Category>>);

  @override
  _i6.Future<void> saveCategories(List<_i13.Category>? categories) =>
      (super.noSuchMethod(
            Invocation.method(#saveCategories, [categories]),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);
}

/// A class which mocks [AiService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAiService extends _i1.Mock implements _i14.AiService {
  MockAiService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<List<({String category, bool isTask, String textSegment})>>
  extractEntries(String? text, List<_i13.Category>? categories) =>
      (super.noSuchMethod(
            Invocation.method(#extractEntries, [text, categories]),
            returnValue: _i6.Future<
              List<({String category, bool isTask, String textSegment})>
            >.value(<({String category, bool isTask, String textSegment})>[]),
          )
          as _i6.Future<
            List<({String category, bool isTask, String textSegment})>
          >);

  @override
  _i6.Future<(String, String?)> getChatResponse({
    required List<_i15.ChatMessage>? messages,
    DateTime? currentDate,
    bool? store = true,
    String? previousResponseId,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#getChatResponse, [], {
              #messages: messages,
              #currentDate: currentDate,
              #store: store,
              #previousResponseId: previousResponseId,
            }),
            returnValue: _i6.Future<(String, String?)>.value((
              _i16.dummyValue<String>(
                this,
                Invocation.method(#getChatResponse, [], {
                  #messages: messages,
                  #currentDate: currentDate,
                  #store: store,
                  #previousResponseId: previousResponseId,
                }),
              ),
              null,
            )),
          )
          as _i6.Future<(String, String?)>);
}

/// A class which mocks [AudioRecorderService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudioRecorderService extends _i1.Mock
    implements _i17.AudioRecorderService {
  MockAudioRecorderService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<void> start(_i2.RecordConfig? config, {required String? path}) =>
      (super.noSuchMethod(
            Invocation.method(#start, [config], {#path: path}),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<String?> stop() =>
      (super.noSuchMethod(
            Invocation.method(#stop, []),
            returnValue: _i6.Future<String?>.value(),
          )
          as _i6.Future<String?>);

  @override
  _i6.Future<bool> isRecording() =>
      (super.noSuchMethod(
            Invocation.method(#isRecording, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Stream<_i2.RecordState> onStateChanged() =>
      (super.noSuchMethod(
            Invocation.method(#onStateChanged, []),
            returnValue: _i6.Stream<_i2.RecordState>.empty(),
          )
          as _i6.Stream<_i2.RecordState>);

  @override
  void dispose() => super.noSuchMethod(
    Invocation.method(#dispose, []),
    returnValueForMissingStub: null,
  );

  @override
  _i6.Future<String> generateRecordingPath() =>
      (super.noSuchMethod(
            Invocation.method(#generateRecordingPath, []),
            returnValue: _i6.Future<String>.value(
              _i16.dummyValue<String>(
                this,
                Invocation.method(#generateRecordingPath, []),
              ),
            ),
          )
          as _i6.Future<String>);
}

/// A class which mocks [VectorStoreService].
///
/// See the documentation for Mockito's code generation for more information.
class MockVectorStoreService extends _i1.Mock
    implements _i18.VectorStoreService {
  MockVectorStoreService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<String?> getOrCreateVectorStoreId() =>
      (super.noSuchMethod(
            Invocation.method(#getOrCreateVectorStoreId, []),
            returnValue: _i6.Future<String?>.value(),
          )
          as _i6.Future<String?>);

  @override
  _i6.Future<void> synchronizeMonthlyLogFile(
    String? vectorStoreId,
    DateTime? date,
    String? formattedMonthlyLogContent,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#synchronizeMonthlyLogFile, [
              vectorStoreId,
              date,
              formattedMonthlyLogContent,
            ]),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<void> performInitialBackfillIfNeeded() =>
      (super.noSuchMethod(
            Invocation.method(#performInitialBackfillIfNeeded, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<void> cleanupDuplicateFiles() =>
      (super.noSuchMethod(
            Invocation.method(#cleanupDuplicateFiles, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  _i6.Future<void> debugListVectorStoreFiles() =>
      (super.noSuchMethod(
            Invocation.method(#debugListVectorStoreFiles, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);
}

/// A class which mocks [SharedPreferences].
///
/// See the documentation for Mockito's code generation for more information.
class MockSharedPreferences extends _i1.Mock implements _i19.SharedPreferences {
  MockSharedPreferences() {
    _i1.throwOnMissingStub(this);
  }

  @override
  Set<String> getKeys() =>
      (super.noSuchMethod(
            Invocation.method(#getKeys, []),
            returnValue: <String>{},
          )
          as Set<String>);

  @override
  Object? get(String? key) =>
      (super.noSuchMethod(Invocation.method(#get, [key])) as Object?);

  @override
  bool? getBool(String? key) =>
      (super.noSuchMethod(Invocation.method(#getBool, [key])) as bool?);

  @override
  int? getInt(String? key) =>
      (super.noSuchMethod(Invocation.method(#getInt, [key])) as int?);

  @override
  double? getDouble(String? key) =>
      (super.noSuchMethod(Invocation.method(#getDouble, [key])) as double?);

  @override
  String? getString(String? key) =>
      (super.noSuchMethod(Invocation.method(#getString, [key])) as String?);

  @override
  bool containsKey(String? key) =>
      (super.noSuchMethod(
            Invocation.method(#containsKey, [key]),
            returnValue: false,
          )
          as bool);

  @override
  List<String>? getStringList(String? key) =>
      (super.noSuchMethod(Invocation.method(#getStringList, [key]))
          as List<String>?);

  @override
  _i6.Future<bool> setBool(String? key, bool? value) =>
      (super.noSuchMethod(
            Invocation.method(#setBool, [key, value]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> setInt(String? key, int? value) =>
      (super.noSuchMethod(
            Invocation.method(#setInt, [key, value]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> setDouble(String? key, double? value) =>
      (super.noSuchMethod(
            Invocation.method(#setDouble, [key, value]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> setString(String? key, String? value) =>
      (super.noSuchMethod(
            Invocation.method(#setString, [key, value]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> setStringList(String? key, List<String>? value) =>
      (super.noSuchMethod(
            Invocation.method(#setStringList, [key, value]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> remove(String? key) =>
      (super.noSuchMethod(
            Invocation.method(#remove, [key]),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> commit() =>
      (super.noSuchMethod(
            Invocation.method(#commit, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<bool> clear() =>
      (super.noSuchMethod(
            Invocation.method(#clear, []),
            returnValue: _i6.Future<bool>.value(false),
          )
          as _i6.Future<bool>);

  @override
  _i6.Future<void> reload() =>
      (super.noSuchMethod(
            Invocation.method(#reload, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);
}

/// A class which mocks [Client].
///
/// See the documentation for Mockito's code generation for more information.
class MockClient extends _i1.Mock implements _i3.Client {
  MockClient() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i3.Response> head(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#head, [url], {#headers: headers}),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(#head, [url], {#headers: headers}),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<_i3.Response> get(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#get, [url], {#headers: headers}),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(#get, [url], {#headers: headers}),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<_i3.Response> post(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i20.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #post,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(
                  #post,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<_i3.Response> put(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i20.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #put,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(
                  #put,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<_i3.Response> patch(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i20.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #patch,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(
                  #patch,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<_i3.Response> delete(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i20.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #delete,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i6.Future<_i3.Response>.value(
              _FakeResponse_1(
                this,
                Invocation.method(
                  #delete,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i6.Future<_i3.Response>);

  @override
  _i6.Future<String> read(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#read, [url], {#headers: headers}),
            returnValue: _i6.Future<String>.value(
              _i16.dummyValue<String>(
                this,
                Invocation.method(#read, [url], {#headers: headers}),
              ),
            ),
          )
          as _i6.Future<String>);

  @override
  _i6.Future<_i8.Uint8List> readBytes(
    Uri? url, {
    Map<String, String>? headers,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#readBytes, [url], {#headers: headers}),
            returnValue: _i6.Future<_i8.Uint8List>.value(_i8.Uint8List(0)),
          )
          as _i6.Future<_i8.Uint8List>);

  @override
  _i6.Future<_i3.StreamedResponse> send(_i3.BaseRequest? request) =>
      (super.noSuchMethod(
            Invocation.method(#send, [request]),
            returnValue: _i6.Future<_i3.StreamedResponse>.value(
              _FakeStreamedResponse_2(
                this,
                Invocation.method(#send, [request]),
              ),
            ),
          )
          as _i6.Future<_i3.StreamedResponse>);

  @override
  void close() => super.noSuchMethod(
    Invocation.method(#close, []),
    returnValueForMissingStub: null,
  );
}

/// A class which mocks [ChatCubit].
///
/// See the documentation for Mockito's code generation for more information.
class MockChatCubit extends _i1.Mock implements _i4.ChatCubit {
  MockChatCubit() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.ChatState get state =>
      (super.noSuchMethod(
            Invocation.getter(#state),
            returnValue: _FakeChatState_3(this, Invocation.getter(#state)),
          )
          as _i4.ChatState);

  @override
  _i6.Stream<_i4.ChatState> get stream =>
      (super.noSuchMethod(
            Invocation.getter(#stream),
            returnValue: _i6.Stream<_i4.ChatState>.empty(),
          )
          as _i6.Stream<_i4.ChatState>);

  @override
  bool get isClosed =>
      (super.noSuchMethod(Invocation.getter(#isClosed), returnValue: false)
          as bool);

  @override
  _i6.Future<void> addUserMessage(String? text) =>
      (super.noSuchMethod(
            Invocation.method(#addUserMessage, [text]),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);

  @override
  void loadDummyMessages() => super.noSuchMethod(
    Invocation.method(#loadDummyMessages, []),
    returnValueForMissingStub: null,
  );

  @override
  void emit(_i4.ChatState? state) => super.noSuchMethod(
    Invocation.method(#emit, [state]),
    returnValueForMissingStub: null,
  );

  @override
  void onChange(_i21.Change<_i4.ChatState>? change) => super.noSuchMethod(
    Invocation.method(#onChange, [change]),
    returnValueForMissingStub: null,
  );

  @override
  void addError(Object? error, [StackTrace? stackTrace]) => super.noSuchMethod(
    Invocation.method(#addError, [error, stackTrace]),
    returnValueForMissingStub: null,
  );

  @override
  void onError(Object? error, StackTrace? stackTrace) => super.noSuchMethod(
    Invocation.method(#onError, [error, stackTrace]),
    returnValueForMissingStub: null,
  );

  @override
  _i6.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i6.Future<void>.value(),
            returnValueForMissingStub: _i6.Future<void>.value(),
          )
          as _i6.Future<void>);
}
