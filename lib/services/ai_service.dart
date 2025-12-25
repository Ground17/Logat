import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_persona.dart';
import '../models/post.dart';
import '../key.dart';

class AiService {
  static const String geminiApiKey = GEMINI_KEYS;
  static const String openaiApiKey = OPENAI_KEYS;

  /// Generate comment for a post
  static Future<String> generateComment({
    required AiPersona persona,
    required Post post,
  }) async {
    final mediaCount = post.mediaPaths.length;
    final prompt = '''Post information:
- Caption: ${post.caption ?? 'None'}
- Location: ${post.location ?? 'None'}
- Media: $mediaCount photo${mediaCount > 1 ? 's' : ''}/video${mediaCount > 1 ? 's' : ''}

Based on this post, write a natural comment that matches ${persona.name}'s personality and role.
Keep the comment brief (1-2 sentences) and let ${persona.name}'s unique character shine through.''';

    return await _generateResponse(
      persona: persona,
      systemPrompt: persona.systemPrompt,
      userPrompt: prompt,
    );
  }

  /// Determine if AI should like the post
  static Future<bool> shouldLikePost({
    required AiPersona persona,
    required Post post,
  }) async {
    final prompt = '''Post information:
- Caption: ${post.caption ?? 'None'}
- Location: ${post.location ?? 'None'}

Considering ${persona.name}'s personality and interests, would they like this post?
Answer only "yes" or "no".''';

    final response = await _generateResponse(
      persona: persona,
      systemPrompt: persona.systemPrompt,
      userPrompt: prompt,
    );

    return response.toLowerCase().contains('yes');
  }

  /// Generate chat response
  static Future<String> generateChatResponse({
    required AiPersona persona,
    required String userMessage,
    List<Map<String, String>>? chatHistory,
  }) async {
    return await _generateResponse(
      persona: persona,
      systemPrompt: persona.systemPrompt,
      userPrompt: userMessage,
      chatHistory: chatHistory,
    );
  }

  /// Generate AI response (uses Gemini or OpenAI based on persona's provider)
  static Future<String> _generateResponse({
    required AiPersona persona,
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      if (persona.aiProvider == AiProvider.gemini) {
        return await _generateWithGemini(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          chatHistory: chatHistory,
        );
      } else {
        return await _generateWithOpenAI(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          chatHistory: chatHistory,
        );
      }
    } catch (e) {
      print('AI response generation error: $e');
      return 'Oops, I can\'t respond right now 😅';
    }
  }

  /// Call Gemini API
  static Future<String> _generateWithGemini({
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$geminiApiKey',
    );

    // Build conversation history
    final contents = <Map<String, dynamic>>[];

    // Add system prompt as first user message
    contents.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}],
    });
    contents.add({
      'role': 'model',
      'parts': [{'text': 'Understood. I will act accordingly.'}],
    });

    // Add chat history
    if (chatHistory != null) {
      for (var message in chatHistory) {
        contents.add({
          'role': message['isUser'] == 'true' ? 'user' : 'model',
          'parts': [{'text': message['content']}],
        });
      }
    }

    // Add current user message
    contents.add({
      'role': 'user',
      'parts': [{'text': userPrompt}],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.9,
          'maxOutputTokens': 200,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else {
      throw Exception('Gemini API error: ${response.statusCode}');
    }
  }

  /// Call OpenAI API
  static Future<String> _generateWithOpenAI({
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Build messages
    final messages = <Map<String, String>>[];

    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // Add chat history
    if (chatHistory != null) {
      for (var message in chatHistory) {
        messages.add({
          'role': message['isUser'] == 'true' ? 'user' : 'assistant',
          'content': message['content']!,
        });
      }
    }

    messages.add({
      'role': 'user',
      'content': userPrompt,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openaiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': messages,
        'temperature': 0.9,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }
  }
}
