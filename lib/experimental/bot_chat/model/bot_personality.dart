// CP: Bot personality definitions for experimental Discord-style chat
enum BotPersonality {
  statsBot('StatsBot', '📊'),
  concernBot('ConcernBot', '💙'),
  chaosBot('ChaosBot', '🔥'),
  coachBot('CoachBot', '💪'),
  memoryBot('MemoryBot', '🧠');

  const BotPersonality(this.displayName, this.emoji);

  final String displayName;
  final String emoji;
}

// CP: Bot personality behavior definitions
class BotPersonalityTraits {
  static const Map<BotPersonality, String> descriptions = {
    BotPersonality.statsBot:
        'Data-driven analyst focused on trends and statistics',
    BotPersonality.concernBot: 'Supportive and caring, monitors wellbeing',
    BotPersonality.chaosBot: 'Snarky observer who points out contradictions',
    BotPersonality.coachBot: 'Motivational coach with tough-love approach',
    BotPersonality.memoryBot: 'Nostalgic keeper of past patterns and memories',
  };

  static const Map<BotPersonality, List<String>> messageTriggers = {
    BotPersonality.statsBot: ['streak', 'count', 'frequency', 'trend', 'data'],
    BotPersonality.concernBot: [
      'missing',
      'health',
      'wellness',
      'mood',
      'tired',
    ],
    BotPersonality.chaosBot: ['contradiction', 'unusual', 'weird', 'funny'],
    BotPersonality.coachBot: ['goal', 'exercise', 'motivation', 'achievement'],
    BotPersonality.memoryBot: [
      'remember',
      'past',
      'before',
      'used to',
      'history',
    ],
  };
}
