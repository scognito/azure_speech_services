import 'package:azure_speech_services/src/config/azure_speech_config.dart';

Map<String, String> buildAuthHeaders(AzureSpeechConfig config) {
  if (config.subscriptionKey != null) {
    return {'Ocp-Apim-Subscription-Key': config.subscriptionKey!};
  }
  return {'Authorization': config.authorizationToken!};
}
