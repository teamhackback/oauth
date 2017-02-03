/++
    OAuth 2.0 client vibe.http.server integration

    Copyright: © 2016 Harry T. Vennik
    License: Subject to the terms of the MIT license, as written in the included LICENSE file.
    Authors: Harry T. Vennik
  +/
module oauth.webapp;

import oauth.settings : OAuthSettings;
import oauth.session : OAuthSession;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;

import std.datetime : Clock, SysTime;
import std.typecons : Rebindable;

//version = DebugOAuth;
version(DebugOAuth) import std.experimental.logger;

/++
    Convenience oauth API wrapper for web applications
  +/
class OAuthWebapp
{
    private
    {
        //Rebindable!(immutable OAuthSettings)[string] _settingsMap;

        struct SessionCacheEntry
        {
            OAuthSession session;
            SysTime timestamp;
        }

        SessionCacheEntry[string] _sessionCache;
    }

    /++
        Check if a request is from a logged in user

        Params:
            req = The request to be checked

        Returns: $(D true) if this request is from a logged in user.
      +/
    bool isLoggedIn(
        scope HTTPServerRequest req) @safe
    {
        version(DebugOAuth) log("isLoggedIn()");
        // For assert in oauthSession method
        version(assert) req.params["oauth.debug.login.checked"] = "yes";

        if (!req.session)
            return false;

        // TODO: is this caching really a good idea?
        if (auto pCE = req.session.id in _sessionCache)
        {
            if (pCE.session.verify(req.session))
            {
                pCE.timestamp = Clock.currTime;
                return true;
            }
            else
                _sessionCache.remove(req.session.id);
        }

        // TODO: it could be faster to use the result of .get directly
        if (req.session.isKeySet("user"))
        {
            return true;
        }

        //if (req.session.isKeySet("oauth.client"))
        //{
            //string hash = req.session.get!string("oauth.client");
            //log("hash", hash);
            //log("_settingsMap", _settingsMap);
            ////if (auto settings = hash in _settingsMap)
            //if (auto session =
                //settings ? settings.loadSession(req.session) : null)
            //{
                //static if (__traits(compiles, req.context))
                    //req.context["oauth.session"] = session;

                //_sessionCache[req.session.id] =
                    //SessionCacheEntry(session, Clock.currTime);

                //return true;
            //}
        //}

        return false;
    }

    /++
        Perform OAuth _login using the given _settings

        The route mapped to this method should normally match the redirectUri
        set on the settings. If multiple providers are to be supported, there
        should be a different route for each provider, all mapped to this
        method, but with different settings.

        If the request looks like a redirect back from the authentication
        server, settings.userSession is called to obtain an OAuthSession.

        Otherwise, the user agent is redirected to the authentication server.

        Params:
            req = The request
            res = Response object to be used to redirect the client to the
                authentication server
            settings = The OAuth settings that apply to this _login attempt
            extraParams = Extra parameters to include in the authentication
                uri. Use this to pass provider specific parameters that cannot
                be included in the settings because they won't be the same for
                every authorization request. (optional)
            scopes = An array of identifiers specifying the scope of
                the authorization requested. (optional)
      +/
    bool login(
        scope HTTPServerRequest req,
        scope HTTPServerResponse res,
        immutable OAuthSettings settings,
        in string[string] extraParams = null,
        in string[] scopes = null) @safe
    {
        version(DebugOAuth) log("login()");

        // redirect from the authentication server
        if (req.session && "code" in req.query && "state" in req.query)
        {
            //import std.digest.digest : toHexString;
            //auto hashString = settings.hash.toHexString();

            //if (hashString !in _settingsMap)
                //_settingsMap[hashString] = settings;

            auto session = settings.userSession(
                req.session, req.query["state"], req.query["code"]);

            if (session)
            {
                _sessionCache[req.session.id] =
                    SessionCacheEntry(session, Clock.currTime);

                // For assert in oauthSession method
                version(assert) req.params["oauth.debug.login.checked"] = "yes";
            }
            return true;
        }
        else
        {
            if (!req.session)
                req.session = res.startSession();

            res.redirect(settings.userAuthUri(req.session, extraParams, scopes));
            return false;
        }
    }

    /++
        Get the OAuthSession object associated to a request.

        This method is optimized for speed. It just performs a session cache
        lookup and doesn't do any validation.

        Always make sure that either `login` or `isLoggedIn` has been
        called for a request before this method is used.

        Params:
            req = the request to get the relevant session for

        Returns: The session associated to req, or `null` if no
            session was found.
      +/
    final
    OAuthSession oauthSession(in HTTPServerRequest req) nothrow @safe
    in
    {
        // https://issues.dlang.org/show_bug.cgi?id=17136 - dictionary get is not nothrow
        try assert (req.params.get("oauth.debug.login.checked", "no") == "yes");
        catch(Exception) assert(false);
    }
    body
    {
        try
        {
            version(OAuthDebug) log("oAuthSession");
            static if (__traits(compiles, req.context))
                if (auto pCM = "oauth.session" in req.context)
                    return pCM.get!OAuthSession;

            if (auto pCE = req.session.id in _sessionCache)
                return pCE.session;
        }
        catch (Exception) { }

        return null;
    }
}
