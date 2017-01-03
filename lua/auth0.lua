local requests = require "requests"
-- I'm really not sure about this,
-- but it is better than depending
-- on external file. But really this
-- should be something that should
-- just go to documentation.
local template = require "resty.template".compile[[
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{{auth0Config.APP_NAME}} Login</title>
</head>
<body>
  <h1>{{message}}</h1>
  <script src="https://cdn.auth0.com/js/lock/10.6/lock.min.js"></script>
  <script type="text/javascript">
    var lock = new Auth0Lock('{{auth0Config.AUTH0_CLIENT_ID}}', '{{auth0Config.AUTH0_DOMAIN}}', {
      auth: {
        redirectUrl: '{*auth0Config.AUTH0_CALLBACK_URL*}'
      }
    });

    function signin() {
      lock.show();
    }
  </script>
  <button onclick="signin()">Login</button>
</body>
</html>
]]
local session = require "resty.session"
local redirect = ngx.redirect
local format = string.format
local concat = table.concat
local assert = assert
local uargs = ngx.req.get_uri_args
local gsub = string.gsub
local byte = string.byte
local var = ngx.var
local say = ngx.say

local function urlencode(str)
   if str then
      str = gsub (str, "\n", "\r\n")
      str = gsub (str, "([^%w ])", function (c) return format("%%%02X", byte(c)) end)
      str = gsub (str, " ", "+")
   end
   return str
end

local function getaccesstoken(authorization_code, config)
    local data = concat{ "client_id=", config.AUTH0_CLIENT_ID,
                  "&client_secret=", config.AUTH0_CLIENT_SECRET,
                  "&redirect_uri=", urlencode(config.AUTH0_CALLBACK_URL),
                  "&code=", authorization_code, "&grant_type=authorization_code" }
    local headers = {}
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    local response = requests.post{ url = concat{ "https://", config.AUTH0_DOMAIN, "/oauth/token" }, data = data, headers = headers }
    assert(response.status_code == 200, response.text)
    local json, error = response.json()
    assert(json, error)
    return json.access_token
end

local function getuserprofile(access_token, config)
    local response = requests.get(concat{ "https://", config.AUTH0_DOMAIN, "/userinfo?access_token=", access_token })
    assert(response.status_code == 200, response.text)
    local json, error = response.json()
    assert(json, error)
    return json
end

-- This should be removed!
-- It introduces a weak dependency
-- that should be avoided as it is
-- not needed anywhere else.
--local function writelog(tbl)
--   local msg = require 'pl.pretty'.write(tbl)
--   log(NOTICE, msg)
--   return msg
--end

-- This should be removed!
--
--local function loadconfig(filepath)
--  if not filepath then
--    local auth0BaseDir = os.getenv("AUTH0_BASE_DIR")
--    filepath = auth0BaseDir .. "/config/auth0.conf.lua"
--  end
--  assert(pcall(dofile, filepath))
--  return auth0conf
--end

local _M = {
  --config = loadconfig()
}

-- This should be removed!
--function _M.printconfig()
--   writelog("printing config")
--   writelog(_M.config)
--end

-- This should be removed!
--function _M.writelog(tbl)
--   writelog(tbl)
--end

function _M.isauth()
  local session = session.open()
  if not session.present or not session.data.user then
    ngx.status = 401 -- unauthorized
    session:start()
    session.data.original_url = var.request_uri
    session:save()
    say(template{ auth0Config = _M.config })
  end
end

function _M.login()
  session.start()
  say(template{ auth0Config = _M.config })
end

function _M.callback()
  local session = session.open()
  assert(session.present, "no session")
  local q = uargs()
  assert(q.code, "expected code query parameter")
  local token = getaccesstoken(q.code, _M.config)
  local profile = getuserprofile(token, _M.config)
  session:start()
  session.data.user = profile
  session:save()
  if session.data.original_url then
      return redirect(session.data.original_url)
  end
  return redirect "/"
end

return _M