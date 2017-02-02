/++
    Settings and customizations for provider "github"
  +/
module oauth.provider.github;

import oauth.provider : OAuthProvider, OAuthProviders;

shared static this()
{
    OAuthProviders.register("github", new immutable(OAuthProvider)(
        "https://github.com/login/oauth/authorize",
        "https://github.com/login/oauth/access_token"
    ));
}
