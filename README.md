# resty-auth0

Auth0 authentication using OpenResty

## dependencies
All installed with the LuaRocks package manager. See OpenResty [docs](https://openresty.org/en/using-luarocks.html) for LuaRocks installation.
* lua-resty-session - server session and cookie manager
* lua-resty-template - html server templates
* lua-requests - http client for making calls to Auth0 endpoints
* penlight - pretty printing of lua tables (for debug tracing) 

**penlight should be removed as a hard dependency, if it is available use it, otherwise just use tostring or something**
**you don't probably need dependency to lua-resty-template, and that should be removed as well**
**don't use lua-requests!!! it does not utilize OpenResty co-sockets, please use e.g. [lua-resty-http](https://github.com/pintsized/lua-resty-http) instead**

## usage

** try to build this as a library. Let user configure this how ever he wants without having him to touch some predefined config file**

Sign into [Auth0.com](https://auth0.com/) and get an authentication client. From the client settings page populate the file config/auth0.conf.lua.
```
auth0conf = {
    AUTH0_CLIENT_ID="[your auth0 client id]";
    AUTH0_CLIENT_SECRET="[your auth0 client secret]";
    AUTH0_DOMAIN="[your auth0 domain]";
    AUTH0_CALLBACK_URL="[your auth0 callback url]";
    APP_NAME="[login page title here]"
}
```

Add the config/site.conf into nginx, by copy or by symlink. The remaining files are found using the environment variable AUTH0_BASE_DIR which refers to the root of this repository. The following snippet shows how this environment variable is used

**I have commented this in site.conf**

```
init_by_lua_block {
   auth0BaseDir = os.getenv("AUTH0_BASE_DIR")
   package.path = auth0BaseDir .. "/lua/?.lua;" .. package.path
   auth0 = require "auth0"
}
```

If your using systemd you can set an environment variable in the service unit file using the Environment property in the Service section

**I'm not agains't environment vars, but that should probably be the last place to store this kind of configs.**

```
Environment=AUTH0_BASE_DIR=path-goes-here
```
