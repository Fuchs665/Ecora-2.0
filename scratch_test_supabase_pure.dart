import 'dart:convert';
import 'dart:io';

void main() async {
  final baseUrl = 'https://fswzykzclfrpzlufjhfg.supabase.co';
  final apiKey = 'sb_publishable_qv2R89l53F8gK_cJ6rS66Q_7TLWe_-B';

  final client = HttpClient();

  try {
    // 1. SignUp
    final signupUrl = Uri.parse('$baseUrl/auth/v1/signup');
    print('Sending SignUp request to $signupUrl...');
    final signupRequest = await client.postUrl(signupUrl);
    signupRequest.headers.set('apikey', apiKey);
    signupRequest.headers.set('Content-Type', 'application/json');

    final email = 'test.antigravity${DateTime.now().millisecondsSinceEpoch}@gmail.com';
    final password = 'Password123!';
    
    signupRequest.write(json.encode({
      'email': email,
      'password': password,
    }));

    var response = await signupRequest.close();
    var responseBody = await response.transform(utf8.decoder).join();

    print('SignUp Status: ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('SignUp failed: $responseBody');
      return;
    }

    final signupData = json.decode(responseBody);
    print('SignUp Response: $signupData');
    final userId = signupData['user']['id'];
    final accessToken = signupData['access_token'];

    print('SignUp successful. User ID: $userId');

    // 2. Insert Profile
    final profileUrl = Uri.parse('$baseUrl/rest/v1/profiles');
    print('Inserting profile into $profileUrl...');
    final profileRequest = await client.postUrl(profileUrl);
    profileRequest.headers.set('apikey', apiKey);
    profileRequest.headers.set('Authorization', 'Bearer $accessToken');
    profileRequest.headers.set('Content-Type', 'application/json');
    profileRequest.headers.set('Prefer', 'return=representation');

    profileRequest.write(json.encode({
      'id': userId,
      'nickname': 'TestAntigravity',
      'role': 'cliente',
      'generic_location': 'Firenze',
      'is_verified': false,
      'profile_type': 'Coppia',
    }));

    response = await profileRequest.close();
    responseBody = await response.transform(utf8.decoder).join();

    print('Profile Insert Status: ${response.statusCode}');
    print('Response Body:');
    try {
      final decodedJson = json.decode(responseBody);
      final prettyJson = JsonEncoder.withIndent('  ').convert(decodedJson);
      print(prettyJson);
    } catch (e) {
      print(responseBody);
    }

  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
