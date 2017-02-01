/++
    Settings and customizations for provider "facebook"

    Copyright: © 2016 Harry T. Vennik
    License: Subject to the terms of the MIT license, as written in the included LICENSE file.
    Authors: Harry T. Vennik
  +/
module oauth.provider.facebook;

import oauth.provider : OAuthProvider, OAuthProviders;
import oauth.settings : OAuthSettings;

import vibe.data.json;
import vibe.http.client;
import vibe.inet.webform;

import std.exception;

/++
    Settings for 'facebook' provider.

    You can just use the OAuthSettings class if you do not need any facebook-
    specific settings.
  +/
class FacebookAuthSettings : OAuthSettings
{
    bool rerequest;

    /++
        See OAuthSettings constructor for common documentation.

        The 'provider' field may be omitted. If it is included, it MUST be set
        to "facebook".

        Additionally, this constructor supports the following JSON key:
        $(TABLE
            $(TR $(TH Key) $(TH Type) $(TH Description))
            $(TR $(TD authType) $(TD string) $(TD If set to "rerequest",
                force Facebook to ask te user again for permissions that
                were previously denied by the user.)))
      +/
    this(in Json config) immutable
    {
        enforce("provider" !in config
            || (config["provider"].type == Json.Type.string
            && config["provider"].get!string == "facebook"),
            "FacebookAuthSettings can only be used with provider 'facebook'.");

        super("facebook",
            config["clientId"].get!string,
            config["clientSecret"].get!string,
            config["redirectUri"].get!string);

        if (config["authType"].type == Json.Type.string
            && config["authType"].get!string == "rerequest")
            rerequest = true;

        // Also allow for the key to be written as auth_type for compatibility
        // with release 0.1.0.
        // TODO: remove deprecated JSON key for facebook: auth_type
        else if (config["auth_type"].type == Json.Type.string
            && config["auth_type"].get!string == "rerequest")
            rerequest = true;
    }
}

/++
    Facebook specialized derivative of OAuthProvider.

    This class should not be used directly. It registers itself as an
    OAuthProvider with name `facebook`.
+/
class FacebookAuthProvider : OAuthProvider
{
    shared static this()
    {
        OAuthProviders.register("facebook", new immutable(FacebookAuthProvider));
    }

    private this() immutable
    {
        super(
            "https://www.facebook.com/dialog/oauth",
            "https://graph.facebook.com/v2.3/oauth/access_token"
        );
    }

    override
    void authUriHandler(
        immutable OAuthSettings settings,
        string[string] params) const
    {
        params["redirect_uri"] = settings.redirectUri;

        if (auto fbSettings = cast(immutable FacebookAuthSettings) settings)
            if ("auth_type" !in params && fbSettings.rerequest)
                params["auth_type"] = "rerequest";
    }

    override
    void tokenRequestor(
        in OAuthSettings settings,
        string[string] params,
        scope HTTPClientRequest req) const
    {
        params["client_id"] = settings.clientId;
        params["client_secret"] = settings.clientSecret;
        req.requestURL = req.requestURL ~ '?' ~ formEncode(params);
    }
}

unittest
{
    auto facebook = OAuthProvider.forName("facebook");
    assert (facebook, "Name 'facebook' not registered!");
    assert (cast(FacebookAuthProvider) facebook,
        "Some unkown OAuthProvider has been registered as 'facebook'.");
}
