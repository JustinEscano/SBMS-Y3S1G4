/// Personality/Role-playing extraction utility for LLM queries
/// Detects and extracts personality instructions from user queries
class PersonalityExtractor {
  /// Extract personality instruction from query
  /// Returns a map with 'cleanedQuery' and 'personality' (null if none detected)
  static Map<String, String?> extractPersonality(String query) {
    if (query.isEmpty) {
      return {'cleanedQuery': query, 'personality': null};
    }

    final queryLower = query.toLowerCase();
    String? personality;
    String cleanedQuery = query;

    // Patterns to detect personality instructions (ordered by specificity)
    final patterns = [
      // "can you act like/as X" (at start)
      _Pattern(
        regex: RegExp(
          r'^can\s+you\s+act\s+(?:like|as)\s+([a-z\s]+?)(?:\s+(?:while|and|when|to))',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "while acting as X" (at start)
      _Pattern(
        regex: RegExp(
          r'^while\s+acting\s+(?:as|like)\s+([a-z\s]+?)(?:\s+(?:can\s+you|please|tell|show|give|provide|check))',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "while acting as X" (at end)
      _Pattern(
        regex: RegExp(
          r'\s+while\s+acting\s+(?:as|like)\s+([a-z\s]+)$',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "act as X" (at start)
      _Pattern(
        regex: RegExp(
          r'^act\s+(?:as|like)\s+([a-z\s]+?)(?:\s+(?:and|can|please|tell|show))',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "as X" at the END (e.g., "show me energy as lebron james")
      _Pattern(
        regex: RegExp(
          r'\s+as\s+([a-z][a-z\s]{2,})$',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "pretend to be X"
      _Pattern(
        regex: RegExp(
          r'pretend\s+(?:to\s+be|you\s+are|you\'re)\s+([a-z\s]+?)(?:\s+(?:and|can|please|tell|show)|$)',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "as X," (with comma)
      _Pattern(
        regex: RegExp(
          r'as\s+(?:a\s+)?([a-z\s]+?),',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "be X and"
      _Pattern(
        regex: RegExp(
          r'be\s+(?:a\s+)?([a-z\s]+?)\s+and',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "you are X" or "you're X"
      _Pattern(
        regex: RegExp(
          r'you(?:\'re|\s+are)\s+([a-z\s]+?)(?:\s+(?:and|can|please|tell|show)|$)',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
      // "in the style of X"
      _Pattern(
        regex: RegExp(
          r'(?:in\s+the\s+style\s+of|like)\s+([a-z\s]+?)\s+would',
          caseSensitive: false,
        ),
        formatter: (match) => _capitalizeName(match.group(1)!),
      ),
    ];

    // Try each pattern
    for (final pattern in patterns) {
      final match = pattern.regex.firstMatch(queryLower);
      if (match != null) {
        // Extract personality
        final name = pattern.formatter(match);
        personality = 'You are $name';

        // Remove personality instruction from query
        cleanedQuery = query.replaceFirst(pattern.regex, '').trim();

        // Clean up leftover phrases
        cleanedQuery = cleanedQuery.replaceFirst(
          RegExp(r'^(?:can\s+you\s+|please\s+|now\s+)', caseSensitive: false),
          '',
        ).trim();
        cleanedQuery = cleanedQuery.replaceFirst(RegExp(r'^\s*,\s*'), '').trim();

        print('🎭 Personality detected: $personality');
        print('📝 Cleaned query: $cleanedQuery');
        break;
      }
    }

    return {
      'cleanedQuery': cleanedQuery,
      'personality': personality,
    };
  }

  /// Capitalize names properly (e.g., 'lebron james' -> 'LeBron James')
  static String _capitalizeName(String name) {
    // Special cases for known names and roles
    const specialCases = {
      // Sports & Athletes
      'lebron james': 'LeBron James',
      'michael jordan': 'Michael Jordan',
      'serena williams': 'Serena Williams',
      'cristiano ronaldo': 'Cristiano Ronaldo',
      'lionel messi': 'Lionel Messi',
      'kobe bryant': 'Kobe Bryant',
      'tom brady': 'Tom Brady',
      
      // Tech & Business Leaders
      'elon musk': 'Elon Musk',
      'steve jobs': 'Steve Jobs',
      'bill gates': 'Bill Gates',
      'mark zuckerberg': 'Mark Zuckerberg',
      'jeff bezos': 'Jeff Bezos',
      'tim cook': 'Tim Cook',
      'sundar pichai': 'Sundar Pichai',
      
      // Scientists & Inventors
      'albert einstein': 'Albert Einstein',
      'einstein': 'Einstein',
      'nikola tesla': 'Nikola Tesla',
      'marie curie': 'Marie Curie',
      'stephen hawking': 'Stephen Hawking',
      'isaac newton': 'Isaac Newton',
      'neil degrasse tyson': 'Neil deGrasse Tyson',
      
      // Historical Figures
      'abraham lincoln': 'Abraham Lincoln',
      'winston churchill': 'Winston Churchill',
      'nelson mandela': 'Nelson Mandela',
      'mahatma gandhi': 'Mahatma Gandhi',
      'martin luther king': 'Martin Luther King Jr.',
      'cleopatra': 'Cleopatra',
      
      // Writers & Philosophers
      'shakespeare': 'Shakespeare',
      'william shakespeare': 'William Shakespeare',
      'mark twain': 'Mark Twain',
      'jane austen': 'Jane Austen',
      'ernest hemingway': 'Ernest Hemingway',
      'socrates': 'Socrates',
      'plato': 'Plato',
      'aristotle': 'Aristotle',
      
      // Entertainment & Pop Culture
      'morgan freeman': 'Morgan Freeman',
      'david attenborough': 'David Attenborough',
      'oprah winfrey': 'Oprah Winfrey',
      'beyonce': 'Beyoncé',
      'taylor swift': 'Taylor Swift',
      'dwayne johnson': 'Dwayne "The Rock" Johnson',
      'robert downey jr': 'Robert Downey Jr.',
      
      // Fictional Characters
      'sherlock holmes': 'Sherlock Holmes',
      'tony stark': 'Tony Stark',
      'iron man': 'Iron Man',
      'batman': 'Batman',
      'yoda': 'Yoda',
      'gandalf': 'Gandalf',
      'dumbledore': 'Dumbledore',
      'darth vader': 'Darth Vader',
      
      // Roles & Archetypes
      'pirate': 'a pirate',
      'robot': 'a robot',
      'cowboy': 'a cowboy',
      'ninja': 'a ninja',
      'detective': 'a detective',
      'scientist': 'a scientist',
      'doctor': 'a doctor',
      'teacher': 'a teacher',
      'chef': 'a chef',
      'astronaut': 'an astronaut',
      'superhero': 'a superhero',
      'wizard': 'a wizard',
      'knight': 'a knight',
      'samurai': 'a samurai',
      'viking': 'a viking',
      'spy': 'a spy',
      'comedian': 'a comedian',
      'news anchor': 'a news anchor',
      'tour guide': 'a tour guide',
      'motivational speaker': 'a motivational speaker',
    };

    final nameLower = name.toLowerCase().trim();
    if (specialCases.containsKey(nameLower)) {
      return specialCases[nameLower]!;
    }

    // Default: title case
    return name
        .trim()
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

/// Helper class for pattern matching
class _Pattern {
  final RegExp regex;
  final String Function(RegExpMatch) formatter;

  _Pattern({required this.regex, required this.formatter});
}
