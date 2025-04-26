import 'package:mockito/annotations.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/pages/cubit/home_screen_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';

// Generate mocks for the Cubits and Repository
@GenerateMocks([EntryCubit, VoiceInputCubit, HomeScreenCubit, EntryRepository])
void main() {}
