import 'package:mockito/annotations.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';

// Generate mocks for the Cubits and Repository
@GenerateMocks([EntryRepository, SpeechService, AudioRecorder])
void main() {}
