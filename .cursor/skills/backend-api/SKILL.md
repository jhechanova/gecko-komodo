---
name: backend-api
description: Extends notif_app calls to the school server at /app/api.cf (login, FCM token, new tpl/tph actions). Use when changing login, registerFcmToken, base URL probing, or adding a backend API request.
---

# School server API

Every request is HTTP GET built by `ApiService._apiUri`:

`{baseUrl}/app/api.cf` plus query parameters. `baseUrl` has no trailing slash.

Existing actions:

| Action | Query |
| --- | --- |
| Reachability | GET with empty query. Any HTTP status counts as reachable. Timeout is 8 seconds. Try `https`, then `http`. |
| Login | `tpl=login`, `username`, `password` |
| Register device token | `tpl=fcm_token`, `tph=set_fcm_token`, `user_id`, `fcm_token`, `device_id` |

## Adding a call

1. Add a method on `ApiService` that builds the URI with `_apiUri` and `http.get`.
2. If the response has branching user-visible outcomes, parse it in a top-level pure function (see `interpretLoginResponse`) and unit-test that function. Do not assert through a widget.
3. Read `baseUrl` from `DatabaseService.getBaseUrl()`. Do not hardcode a school host.
4. Call `FcmService.syncToken` only when a user row exists. Login must not copy an FCM token out of the login JSON.

## Login outcomes

Keep these messages:

- HTTP status other than 200, invalid JSON, or unexpected body → `The URL is not accessible.`
- HTTP 200 and body `status_code` `"404"` → `User not found.`
- HTTP 200 and body `status_code` `"200"` → `LoginSuccess` via `AppUser.fromLoginJson`

`status_code` is read with `.toString()` because the server may send a number or a string.

## Verify

`flutter test test/login_result_test.dart` and any new pure-function test file.
