import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessandrefreshtoken/src/common/constant/config.dart';

class PusherClient {
  PusherClient({required final SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  late final PusherChannelsClient _pusherChannelsClient;

  PusherChannelsClient get client => _pusherChannelsClient;

  EndpointAuthorizableChannelTokenAuthorizationDelegate<PresenceChannelAuthorizationData>
  get authDelegate {
    final token = _sharedPreferences.getString('auth_token');
    return EndpointAuthorizableChannelTokenAuthorizationDelegate.forPresenceChannel(
      authorizationEndpoint: Uri.parse('${Config.apiBaseUrl}/api/broadcasting/auth'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> initilize() async {
    const options = PusherChannelsOptions.fromHost(
      scheme: Config.wsTls ? 'wss' : 'ws',
      host: Config.wsHost,
      key: Config.wsKey,
      port: Config.wsPort,
    );

    _pusherChannelsClient = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) async {
        Error.throwWithStackTrace(Exception('Pusher channel client exception: $exception'), trace);
      },
    );

    await _pusherChannelsClient.connect();
  }
}
