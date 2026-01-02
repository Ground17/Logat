import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_persona.dart';
import '../models/post.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../key.dart';

class AiService {
  static const String geminiApiKey = GEMINI_KEYS;
  static const String openaiApiKey = OPENAI_KEYS;

  /// Generate comment for a post
  static Future<String> generateComment({
    required AiPersona persona,
    required Post post,
    String userProfile = '',
  }) async {
    final mediaCount = post.mediaPaths.length;
    final userContext =
        userProfile.isNotEmpty ? '\n- About the user: $userProfile' : '';
    final prompt = '''Post information:
- Caption: ${post.caption ?? 'None'}
- Location: ${post.locationName ?? 'None'}
- Media: $mediaCount photo${mediaCount > 1 ? 's' : ''}/video${mediaCount > 1 ? 's' : ''}$userContext

Based on this post, write a natural comment that matches ${persona.name}'s personality and role.
Keep the comment brief (1-2 sentences) and let ${persona.name}'s unique character shine through.''';

    // Get first media if available
    String? imagePath;
    if (post.mediaPaths.isNotEmpty) {
      final firstMedia = post.mediaPaths.first;
      if (firstMedia.toLowerCase().endsWith('.mp4') ||
          firstMedia.toLowerCase().endsWith('.mov')) {
        // Extract thumbnail from video
        imagePath = await _extractVideoThumbnail(firstMedia);
      } else {
        // Use image directly
        imagePath = firstMedia;
      }
    }

    return await _generateResponse(
      persona: persona,
      systemPrompt: persona.systemPrompt,
      userPrompt: prompt,
      imagePath: imagePath,
    );
  }

  /// Extract thumbnail from video (middle frame)
  static Future<String?> _extractVideoThumbnail(String videoPath) async {
    try {
      // Note: VideoThumbnail package extracts from middle of video by default when timeMs is not specified
      // According to the package documentation, if timeMs is null, it defaults to middle frame
      // So we simply don't specify timeMs and let it use the default middle frame behavior
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
        // timeMs not specified = defaults to middle of video
      );
      return thumbnailPath;
    } catch (e) {
      print('Failed to extract video thumbnail: $e');
      return null;
    }
  }

  /// Determine if AI should like the post
  static Future<bool> shouldLikePost({
    required AiPersona persona,
    required Post post,
    String userProfile = '',
  }) async {
    final userContext =
        userProfile.isNotEmpty ? '\n- About the user: $userProfile' : '';
    final prompt = '''Post information:
- Caption: ${post.caption ?? 'None'}
- Location: ${post.locationName ?? 'None'}$userContext

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
    String userProfile = '',
  }) async {
    final enrichedPrompt = persona.systemPrompt +
        (userProfile.isNotEmpty ? '\n\nUser information: $userProfile' : '');

    return await _generateResponse(
      persona: persona,
      systemPrompt: enrichedPrompt,
      userPrompt: userMessage,
      chatHistory: chatHistory,
    );
  }

  /// Generate AI response (uses Gemini or OpenAI based on persona's model)
  static Future<String> _generateResponse({
    required AiPersona persona,
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
    String? imagePath,
  }) async {
    try {
      if (persona.aiModel.isGemini) {
        return await _generateWithGemini(
          model: persona.aiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          chatHistory: chatHistory,
          imagePath: imagePath,
        );
      } else {
        return await _generateWithOpenAI(
          model: persona.aiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          chatHistory: chatHistory,
          imagePath: imagePath,
        );
      }
    } catch (e) {
      print('AI response generation error: $e');
      return 'Oops, I can\'t respond right now 😅';
    }
  }

  /// Call Gemini API
  static Future<String> _generateWithGemini({
    required AiModel model,
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
    String? imagePath,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${model.modelId}:generateContent?key=$geminiApiKey',
    );

    // Build conversation history
    final contents = <Map<String, dynamic>>[];

    // Add system prompt as first user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': systemPrompt}
      ],
    });
    contents.add({
      'role': 'model',
      'parts': [
        {'text': 'Understood. I will act accordingly.'}
      ],
    });

    // Add chat history
    if (chatHistory != null) {
      for (var message in chatHistory) {
        contents.add({
          'role': message['isUser'] == 'true' ? 'user' : 'model',
          'parts': [
            {'text': message['content']}
          ],
        });
      }
    }

    // Add current user message with optional image
    final parts = <Map<String, dynamic>>[];
    parts.add({'text': userPrompt});

    // Add image if available
    if (imagePath != null) {
      try {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(imageBytes);

          // Determine MIME type
          String mimeType = 'image/jpeg';
          if (imagePath.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imagePath.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
          }

          parts.add({
            'inline_data': {
              'mime_type': mimeType,
              'data': base64Image,
            }
          });
        }
      } catch (e) {
        print('Failed to encode image: $e');
      }
    }

    contents.add({
      'role': 'user',
      'parts': parts,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.5,
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
    required AiModel model,
    required String systemPrompt,
    required String userPrompt,
    List<Map<String, String>>? chatHistory,
    String? imagePath,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Build messages
    final messages = <Map<String, dynamic>>[];

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

    // Add current user message with optional image
    if (imagePath != null) {
      try {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(imageBytes);

          // Determine MIME type
          String mimeType = 'image/jpeg';
          if (imagePath.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imagePath.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
          }

          messages.add({
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userPrompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                }
              }
            ],
          });
        } else {
          messages.add({
            'role': 'user',
            'content': userPrompt,
          });
        }
      } catch (e) {
        print('Failed to encode image for OpenAI: $e');
        messages.add({
          'role': 'user',
          'content': userPrompt,
        });
      }
    } else {
      messages.add({
        'role': 'user',
        'content': userPrompt,
      });
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openaiApiKey',
      },
      body: jsonEncode({
        'model': model.modelId,
        'messages': messages,
        'temperature': 0.5,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }
  }

  /// Generate AI avatar image using Gemini or OpenAI
  static Future<String?> generateAvatarImage({
    required String description,
  }) async {
    final enhancedPrompt = _enhancePrompt(description);

    // Load user's preferred model
    final settings = await SettingsService.loadSettings();
    final preferredModel = settings.preferredImageModel;

    if (preferredModel == AiImageModel.gemini) {
      // Try Gemini first
      final geminiResult = await _generateImageWithGemini(enhancedPrompt);
      if (geminiResult != null) {
        return geminiResult;
      }
      // Fallback to OpenAI if Gemini fails
      return await _generateImageWithOpenAI(enhancedPrompt);
    } else {
      // Try OpenAI first
      final openaiResult = await _generateImageWithOpenAI(enhancedPrompt);
      if (openaiResult != null) {
        return openaiResult;
      }
      // Fallback to Gemini if OpenAI fails
      return await _generateImageWithGemini(enhancedPrompt);
    }
  }

  /// Generate image using Gemini 3 Pro Image
  static Future<String?> _generateImageWithGemini(String prompt) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=$geminiApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['IMAGE'],
            "imageConfig": {"aspectRatio": "1:1", "imageSize": "1K"}
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;

        if (candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;

          // Find inlineData with image
          for (var part in parts) {
            if (part.containsKey('inlineData')) {
              final inlineData = part['inlineData'];
              final base64Image = inlineData['data'] as String;
              final mimeType = inlineData['mimeType'] as String;

              // Save the base64 image to file
              return await _saveBase64Image(base64Image, mimeType);
            }
          }
        }
      } else {
        print(
            'Gemini Image Generation error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Failed to generate image with Gemini: $e');
    }
    return null;
  }

  /// Generate image using OpenAI Images API
  static Future<String?> _generateImageWithOpenAI(String prompt) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/images/generations');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-image-1.5',
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Image = data['data'][0]['b64_json'] as String;

        // Save the base64 image to file
        return await _saveBase64Image(base64Image, 'image/png');
      } else {
        print(
            'OpenAI Image Generation error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Failed to generate image with OpenAI: $e');
    }
    return null;
  }

  /// Enhance prompt for better image generation
  static String _enhancePrompt(String description) {
    return '$description, character avatar, friendly, high quality, professional illustration, isolated on white background';
  }

  /// Save base64 encoded image to local storage
  /// Returns only the filename (not the full path)
  static Future<String?> _saveBase64Image(
      String base64Image, String mimeType) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      String extension = 'png';
      if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
        extension = 'jpg';
      } else if (mimeType.contains('webp')) {
        extension = 'webp';
      }

      final fileName = 'ai_gen_$timestamp.$extension';
      final file = File('${appDir.path}/$fileName');

      final imageBytes = base64Decode(base64Image);
      await file.writeAsBytes(imageBytes);

      // Return only the filename, not the full path
      return fileName;
    } catch (e) {
      print('Failed to save base64 image: $e');
    }
    return null;
  }

  /// Edit avatar image using Gemini or OpenAI
  static Future<String?> editAvatarImage({
    required String imagePath,
    required String editPrompt,
  }) async {
    // Load user's preferred model
    final settings = await SettingsService.loadSettings();
    final preferredModel = settings.preferredImageModel;

    if (preferredModel == AiImageModel.gemini) {
      // Try Gemini first
      final geminiResult = await _editImageWithGemini(imagePath, editPrompt);
      if (geminiResult != null) {
        return geminiResult;
      }
      // Fallback to OpenAI if Gemini fails
      return await _editImageWithOpenAI(imagePath, editPrompt);
    } else {
      // Try OpenAI first
      final openaiResult = await _editImageWithOpenAI(imagePath, editPrompt);
      if (openaiResult != null) {
        return openaiResult;
      }
      // Fallback to Gemini if OpenAI fails
      return await _editImageWithGemini(imagePath, editPrompt);
    }
  }

  /// Edit image using Gemini
  static Future<String?> _editImageWithGemini(
    String imagePath,
    String editPrompt,
  ) async {
    try {
      // Get full path if only filename is provided
      String fullPath = imagePath;
      if (!imagePath.contains('/')) {
        final appDir = await getApplicationDocumentsDirectory();
        fullPath = '${appDir.path}/$imagePath';
      }

      final imageFile = File(fullPath);
      if (!await imageFile.exists()) {
        print('Image file not found: $fullPath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Determine MIME type
      String mimeType = 'image/png';
      if (fullPath.toLowerCase().endsWith('.jpg') ||
          fullPath.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fullPath.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=$geminiApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': editPrompt},
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['IMAGE'],
            'imageConfig': {'aspectRatio': '1:1', 'imageSize': '1K'}
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;

        if (candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;

          // Find inlineData with image
          for (var part in parts) {
            if (part.containsKey('inlineData')) {
              final inlineData = part['inlineData'];
              final editedBase64 = inlineData['data'] as String;
              final editedMimeType = inlineData['mimeType'] as String;

              return await _saveBase64Image(editedBase64, editedMimeType);
            }
          }
        }
      } else {
        print(
            'Gemini Image Edit error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Failed to edit image with Gemini: $e');
    }
    return null;
  }

  /// Edit image using OpenAI
  static Future<String?> _editImageWithOpenAI(
    String imagePath,
    String editPrompt,
  ) async {
    try {
      // Get full path if only filename is provided
      String fullPath = imagePath;
      if (!imagePath.contains('/')) {
        final appDir = await getApplicationDocumentsDirectory();
        fullPath = '${appDir.path}/$imagePath';
      }

      final imageFile = File(fullPath);
      if (!await imageFile.exists()) {
        print('Image file not found: $fullPath');
        return null;
      }

      final url = Uri.parse('https://api.openai.com/v1/images/edits');

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $openaiApiKey';

      // Determine MIME type from file extension
      String mimeSubtype = 'png';
      if (fullPath.toLowerCase().endsWith('.jpg') ||
          fullPath.toLowerCase().endsWith('.jpeg')) {
        mimeSubtype = 'jpeg';
      } else if (fullPath.toLowerCase().endsWith('.webp')) {
        mimeSubtype = 'webp';
      }

      // Add image file with explicit MIME type
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          fullPath,
          contentType: MediaType('image', mimeSubtype),
        ),
      );

      // Add prompt
      request.fields['prompt'] = editPrompt;
      request.fields['model'] = 'gpt-image-1.5';
      request.fields['n'] = '1';
      request.fields['size'] = '1024x1024';

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        final base64Image = data['data'][0]['b64_json'] as String;

        // Save the base64 image to file
        return await _saveBase64Image(base64Image, 'image/png');
      } else {
        final responseBody = await response.stream.bytesToString();
        print(
            'OpenAI Image Edit error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Failed to edit image with OpenAI: $e');
    }
    return null;
  }
}
