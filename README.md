# Logat - Local Social Media with AI Friends

A unique social media app where your only friends are AI personas. Share photos and videos, and watch as AI friends interact with your posts through likes and comments.

## Features

### Core Functionality
- **Multi-Media Posts**: Share up to 20 photos/videos in a single post
- **AI Personas**: 6 unique AI friends with different personalities:
  - Emma - Best Friend (Cheerful, positive, and always supportive)
  - Alex - Photographer (Artistic eye with professional photography insights)
  - Sophie - Travel Expert (Passionate traveler with extensive knowledge)
  - Ryan - Gamer (Tech-savvy gamer with a great sense of humor)
  - Olivia - Foodie (Food lover and restaurant explorer)
  - Max - Fitness Coach (Health-conscious and energetic fitness enthusiast)

### AI Interactions
- **Automated Reactions**: AI friends automatically like and comment on your posts
- **Smart Comments**: Context-aware comments generated based on your post content
- **Direct Chat**: Have one-on-one conversations with each AI friend
- **Customizable Behavior**: Configure each persona individually with unique settings

### Settings & Customization
- **Initial Setup**: Configure app on first launch
- **Per-Persona Configuration**: Each AI friend has individual settings:
  - AI Provider (Google Gemini or OpenAI)
  - Comment probability (0-100%)
  - Like probability (0-100%)
- **Persona Management**:
  - Create, edit, or delete AI personas
  - Customize names, avatars, roles, and personalities
  - Configure unique system prompts for each persona
  - Enable/disable specific AI friends
- **Per-Post Control**: Toggle AI reactions for individual posts

## Setup

### Prerequisites
- Flutter SDK (^3.2.0)
- Dart SDK
- AI API Keys:
  - Google Gemini API key OR
  - OpenAI API key

### Installation

1. Clone the repository
```bash
cd logat
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure API Keys
Edit `lib/key.dart` and add your API keys:
```dart
const String GEMINI_KEYS = 'your-gemini-api-key';
const String OPENAI_KEYS = 'your-openai-api-key';
```

4. Run the app
```bash
flutter run
```

## First Launch

On first launch, you'll be guided through initial setup:

1. **Select AI Friends**: Choose which personas to activate
2. **View Persona Settings**: Each AI friend shows their default configuration
3. **Start Using**: Begin sharing posts!
4. **Customize Later**: Fine-tune individual persona settings in the Settings menu

## Usage

### Creating Posts
1. Tap the '+' button on the main feed
2. Select photos/videos (up to 20 files)
3. Add caption and location (optional)
4. Toggle "Enable AI Reactions" on/off
5. Share!

### Viewing AI Reactions
- See likes and comments on your posts
- Tap on a post to view details
- Click on AI avatar to start a chat

### Managing Settings
1. Tap the settings icon in the app bar
2. View and toggle active personas
3. Click "Edit Settings" on any persona to customize:
   - AI Provider (Gemini/OpenAI)
   - Comment probability
   - Like probability
   - Name, avatar, role, personality
   - System prompt
4. Use "Manage Personas" to add, edit, or delete AI friends
5. Save changes

## Project Structure

```
lib/
├── main.dart                         # App entry point with splash screen
├── data/
│   └── default_personas.dart        # Pre-defined AI personas (English names)
├── database/
│   └── database_helper.dart         # SQLite database operations
├── models/
│   ├── ai_persona.dart              # AI persona model with per-persona settings
│   ├── app_settings.dart            # App settings model
│   ├── chat_message.dart            # Chat message model
│   ├── comment.dart                 # Comment model
│   ├── like.dart                    # Like model
│   └── post.dart                    # Post model (multi-media support)
├── screens/
│   ├── chat_screen.dart             # AI chat interface
│   ├── create_post_screen.dart      # Post creation with multi-media
│   ├── edit_persona_screen.dart     # Persona creation/editing
│   ├── feed_screen.dart             # Main feed
│   ├── friends_screen.dart          # AI friends list
│   ├── persona_management_screen.dart # Persona CRUD operations
│   ├── post_detail_screen.dart      # Post details & comments
│   ├── settings_screen.dart         # Settings & persona configuration
│   └── setup_screen.dart            # Initial setup wizard
└── services/
    ├── ai_service.dart              # AI API integration (per-persona provider)
    └── settings_service.dart        # Settings persistence
```

## Database Schema

### Tables
- **posts**: Multi-media posts with captions and locations
- **comments**: AI-generated comments
- **likes**: AI likes
- **ai_personas**: AI friend configurations with individual settings
  - Includes: aiProvider, commentProbability, likeProbability
- **chat_messages**: One-on-one chat history

## Dependencies

Key packages:
- `sqflite`: Local database
- `image_picker`: Media selection
- `http`: AI API communication
- `shared_preferences`: Settings storage
- `google_generative_ai`: Gemini integration

## Contributing

This is a personal project, but suggestions are welcome!

## License

Private project - All rights reserved

## Notes

- All data is stored locally on the device
- AI reactions are generated in real-time when posting
- No internet connection required except for AI API calls
- Privacy-focused: No user data is collected or shared
