module oauth.provider;

import vibe.data.json : Json;
import vibe.inet.url;
import vibe.http.client : HTTPClientRequest;

import oauth.session : OAuthSession;
import oauth.settings : OAuthSettings;

version(DebugOAuth) import std.experimental.logger;

auto loadFromEnvironment(
    string providerName,
    string envPrefix,
    string redirectUri,
)
{
    import std.process : environment;
    string clientId = environment[envPrefix ~ "_CLIENTID"];
    string clientSecret = environment[envPrefix ~ "_CLIENTSECRET"];

    return new immutable(OAuthSettings)(
        providerName,
        clientId,
        clientSecret,
        redirectUri);
}

/++
All registered OAuth 2.0 Providers
+/
class OAuthProviders
{
    private
    {
        import std.typecons : Rebindable;

        /* Exclusively accessed by forName() and register(), synchronized. */
        __gshared Rebindable!(immutable OAuthProvider)[string] _servers;

        /* Set once and never changed, synchronization not necessary. */
        __gshared bool allowAutoRegister = true;
    }

    /++
        Disables automatic registration of authentication servers from JSON
        config.

        This will only prevent the application from changing the provider
        registry implicitly. Explicit registration of providers remains
        possible.

        Should be called only once and before using any OAuth functions.
      +/
    static disableAutoRegister() nothrow
    {
        import core.atomic : cas;

        static shared bool calledBefore;

        if(cas(&calledBefore, false, true))
            allowAutoRegister = false;
    }

    /++
        Get provider by name

        Params:
            name = The name of the provider
      +/
    static forName(string name) nothrow @trusted
    {
        // TODO: investigate why 'synchronized' is not nothrow
        //  Hacked around it for now.
        try synchronized(OAuthProviders.classinfo)
            if (auto p_srv = name in _servers)
                return p_srv.get;
        catch (Exception)
            assert (false);

        return null;
    }

    /++
        Register a provider

        Params:
            name = The name of the provider
            srv = The provider to register
      +/
    static register(string name, immutable OAuthProvider srv) nothrow @trusted
    {
        // TODO: investigate why 'synchronized' is not nothrow
        //  Hacked around it for now.
        try synchronized(OAuthProviders.classinfo)
            _servers[name] = srv;
        catch (Exception)
            assert (false);
    }
}

/++
Represents an OAuth 2.0 authentication server.
+/
class OAuthProvider
{
    package(oauth)
    {
        URL authUriParsed;
        SessionFactory _sessionFactory;
    }

    alias OAuthSession function(
        immutable OAuthSettings) nothrow @safe SessionFactory; ///

    // TODO: add get/set
    string authUri;     /// URI to which the user should be redirected
    string tokenUri;    /// URI from which the token should be requested

    /++
        Constructor

        Params:
            authUri = Authorization URI for this provider.
            tokenUri = Token URI for this provider.
            sessionFactory = (Optional) function that returns a new session
                object compatible with this provider.
      +/
    this(
        string authUri,
        string tokenUri,
        SessionFactory sessionFactory
            = (settings) => new OAuthSession(settings)) immutable @safe
    {
        this.authUri = authUri;
        this.tokenUri = tokenUri;
        this._sessionFactory = sessionFactory;

        this.authUriParsed = URL(authUri);
    }

    // TODO: was protected
    /++
    Customize the redirect to the OAuth Server.
    +/
    void authUriHandler(immutable OAuthSettings settings, string[string] params) const @safe {
        params["redirect_uri"] = settings.redirectUri;
    }

    // TODO: was protected
    /++
    Authenticate the token request call to the OAuth Provider.
    +/
    void tokenRequestor(
        in OAuthSettings settings,
        string[string] params,
        scope HTTPClientRequest req) const
    {
        import vibe.http.common : HTTPMethod;
        import vibe.inet.webform : formEncode;
        import vibe.http.auth.basic_auth : addBasicAuth;

        req.method = HTTPMethod.POST;
        addBasicAuth(req, settings.clientId, settings.clientSecret);
        req.contentType = "application/x-www-form-urlencoded";
        req.bodyWriter.write(formEncode(params));
    }

    package(oauth):

    this(in Json json) immutable @trusted
    {
        this(json["authUri"].get!string,
            json["tokenUri"].get!string);

        if (OAuthProviders.allowAutoRegister && "name" in json)
            OAuthProviders.register(json["name"].get!string, this);
    }
}
