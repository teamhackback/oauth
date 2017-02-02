# OAuth
The `oauth` package provides an implementation of the [OAuth 2.0 Authorization
framework][RFC6749].

This package is in early development phase. Subsequent versions may not be fully
compatible. Especially between versions 0.0.1 and 0.1.0 the API changed a lot.

# API Overview

Full documentation is in the source, here is just an overview of the 0.1.0+ API.

You'll need at least one `OAuthProvider`. Support for Facebook, Google and Azure
is included, though the latter two are to be considered beta. You generally
don't reference instances of this class directly, except when registering a
custom provider.

An `OAuthSettings` instance contains application-specific settings, such as the
client id, for use with a particular provider. Also it provides methods to
obtain authorization using these settings. If authorization is successful, an
`OAuthSession` instance is returned. For three-legged OAuth, use the
`userAuthUri` method to obtain the URL where the user agent is to be redirected
to. When the authorization code is received, through redirection back to the
application, call `userSession` to obtain the `OAuthSession`.

An `OAuthSession` holds an access token and optionally a refresh token. Use its
`authorizeRequest` method to apply the access token to an
[HTTPClientRequest](http://vibed.org/api/vibe.http.client/HTTPClientRequest).
If the access token  has expired, it will automatically be refreshed, if a
refresh token is available.

[RFC6749]: https://tools.ietf.org/html/rfc6749

## Session

oauth.authorization: LoginData(timestamp, rndLong, scopesJoined, redirectUriInReqParams)

oauth.session: SaveData(timestamp, jsonTokenData, signature)    -- signature = (settings.hash + tokenData).toHash

// TODO: not needed?
oauth.client (this.hash.toHexString)

# Request to AuthUri

settings.userAuthUri()

reqParams
	state: LoginKey(timestamp, rndLong, scopesJoined).toHash
	scope: scopesJoined
	response_code: code
	client_id: clientId
	[extraParams]

# Request to TokenUri

settings.userSession(state: req.query.state, code: req.query.code)

settings.requestAuthorization -> tokenUri

session.handleAccessTokenResponse (saves token (json) and timestamp)


# LoadSession

oauth.session -> session.handleAccessTokenResponse


# Architecture

OAuthWebApp: convenience interface
 - settingsMap: OAuthSettings[string]   - settings.hash
 - sessionCache: SessionCacheEntry(OAuthSession, SysTime)[string]  - req.session.id

OAuthSession: Access token & (optionally) refresh token
	- timestamp
	- tokenData
	- signature
	- OAuthSettings
		- OAuthProvider
		- clientId
		- clientSecret
		- redirectUri
