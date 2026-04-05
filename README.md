## Get Started

### Requirements
- Flutter 3.x+
- Dart 3.x+
- Android device/emulator on the same local network as the backend

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Configure the backend URL

Edit `config/development.json` and set your server's local IP:
```json
{
  "API_BASE_URL": "http://192.168.100.96:8000",
  "WS_KEY": "must_match_REVERB_APP_KEY_in_laravel_env",
  "WS_HOST": "192.168.100.96",
  "WS_PORT": 8080,
  "WS_TLS": false
}
```

### 3. Run the app
```bash
flutter run --dart-define-from-file=config/development.json
```

> **Note:** `WS_KEY` must be the same value as `REVERB_APP_KEY` in the Laravel `.env`. Both are strings you make up yourself — just keep them in sync.

Make sure the Laravel HTTP server (port 8000) and Reverb WebSocket server (port 8080) are both running before launching the app.

---

## What is Pusher?

[pusher.com](https://pusher.com) is a **paid cloud service** that invented the Pusher WebSocket protocol — the message format, channel naming rules (`private-`, `presence-`), the auth flow, and everything around it. It became so widely adopted that the protocol itself turned into an open standard.

**Laravel Reverb** is a self-hosted WebSocket server that implements the same Pusher protocol. Instead of paying pusher.com to run the servers, you run your own — but it speaks the exact same protocol so any Pusher-compatible client works with it.

**`dart_pusher_channels`** is a Flutter client library that implements the Pusher protocol. It doesn't care whether it's talking to pusher.com or your own Reverb server.

```
pusher.com           ← original paid cloud service (they manage servers)
Laravel Reverb       ← self-hosted, same protocol, you manage the server  ← used here
dart_pusher_channels ← Flutter client, speaks Pusher protocol
```

Reverb is free because you provide the hardware. Pusher.com charges because they do.

---

## How channel authentication works

Presence channels are private — Reverb won't allow a subscription without proof that the user is allowed in. The flow is:

```
Flutter → Reverb: "I want to join presence-room.ABC123"
Reverb  → Flutter: "Prove you're allowed. Hit your auth endpoint."
Flutter → Laravel POST /api/broadcasting/auth  (with Bearer token)
Laravel → verifies token, signs response with REVERB_APP_SECRET (HMAC)
Flutter → Reverb: "Here's the signed proof"
Reverb  → verifies signature → allows subscription
```

`Broadcast::routes(...)` in Laravel's `routes/api.php` automatically registers `POST /api/broadcasting/auth`. The channel authorization logic lives in `routes/channels.php`.

> **Important:** Laravel strips the `presence-` / `private-` prefix before matching `channels.php`. Flutter uses `presence-room.{code}`, so `channels.php` must define `room.{code}` — not `presence-room.{code}`.

### Channel types

| | Auth required | Knows who's subscribed | Name prefix |
|-|---|---|---|
| Public | No | No | `channel-name` |
| Private | Yes | No | `private-` |
| Presence | Yes | Yes | `presence-` |

Private and presence use the exact same auth mechanism — same endpoint, same HMAC signing, same `channels.php` logic. The only differences are:
- **Private** returns `true/false` from `channels.php`
- **Presence** returns a user info array (e.g. `['id' => 1, 'name' => 'John']`) — Reverb uses this to maintain a live member list and fires `pusher:member_added` / `pusher:member_removed` events when users join or leave

This app uses presence because the chat room needs to know which users are currently online. If you only needed messaging without a member list, private would be sufficient.

### The prefix IS the declaration

The channel name prefix is how both the client library and Reverb determine the channel type — there is no separate config. The prefix must be consistent on both sides:

**Flutter (dart_pusher_channels):**
```dart
_client.publicChannel('room.$roomCode')            // public  — no auth
_client.privateChannel('private-room.$roomCode')   // private — auth required
_client.presenceChannel('presence-room.$roomCode') // presence — auth + member tracking
```

**Laravel (channels.php):**

Laravel **strips the prefix** before matching, so `private-room.ABC` and `presence-room.ABC` both match the same base rule:
```php
Broadcast::channel('room.{code}', function ($user, $code) {
    // return true/false  → works as a private channel
    // return array       → works as a presence channel (member info)
});
```

Public channels don't need a `channels.php` entry — they require no auth.

No prefix = public, `private-` = private, `presence-` = presence. The prefix is for the client and Reverb only — Laravel always sees the base name.

---

## Rename the project (optional)

```bash
dart run tool/dart/rename_project.dart --name="project" --organization="dev.flutter" --description="My project description"
```
