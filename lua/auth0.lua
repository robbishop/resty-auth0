local function urlencode(str)
   if (str) then
      str = string.gsub (str, "\n", "\r\n")
      str = string.gsub (str, "([^%w ])",
         function (c) return string.format ("%%%02X", string.byte(c)) end)
      str = string.gsub (str, " ", "+")
   end
   return str
end

local function getaccesstoken(authorization_code, config)
    local requests = require("requests")
    local data = "client_id=" .. config.AUTH0_CLIENT_ID ..
                  "&client_secret=" .. config.AUTH0_CLIENT_SECRET ..
                  "&redirect_uri=" .. urlencode(config.AUTH0_CALLBACK_URL) ..
                  "&code=" .. authorization_code .. "&grant_type=authorization_code"
    local headers = {}
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    local response = requests.post{url = "https://".. config.AUTH0_DOMAIN .. "/oauth/token", data = data, headers = headers}
    if response.status_code ~= 200 then error(response.text) end
    local json_body, error = response.json()
    if error then error(error) end
    return json_body.access_token
end

local function getuserprofile(access_token, config)
    local requests = require("requests")
    local response = requests.get("https://".. config.AUTH0_DOMAIN .. "/userinfo?access_token=" .. access_token)
    if response.status_code ~= 200 then error(response.text) end
    local json_body, error = response.json()
    if error then error(error) end
    return json_body
end

local function writelog(tbl)
   local msg = require 'pl.pretty'.write(tbl)
   ngx.log(ngx.NOTICE, msg)
   return msg
end

local function loadconfig(filepath)
  if not filepath then
    local auth0BaseDir = os.getenv("AUTH0_BASE_DIR")
    filepath = auth0BaseDir .. "/config/auth0.conf.lua"
  end
  local ok,e = pcall(dofile,filepath)
  if not ok then
    error(e)
  end
  return auth0conf
end

local _M = {
  config = loadconfig()
}

function _M.printconfig()
   writelog("printing config")
   writelog(_M.config)
end

function _M.writelog(tbl)
   writelog(tbl)
end

function _M.isauth()
  local session = require "resty.session".open()
  if not session.present or not session.data.user then
    session:start()
    session.data.original_url = ngx.var.request_uri
    session:save()
    return ngx.redirect("/login")
  end
end

function _M.login()
  local session = require "resty.session".open()
  if not session.present then
      session:start()
      session:save()
  end
  local template = require "resty.template"
  template.render("login.html", { auth0Config = _M.config })
end

function _M.callback()
  local session = require "resty.session".open()
  if not session.present then
      error("no session")
  end
  local query_string = ngx.req.get_uri_args()
  if not query_string["code"] then return error("expected code query parameter") end
  local token = getaccesstoken(query_string["code"], _M.config)
  local profile = getuserprofile(token, _M.config)
  session.data.user = profile
  session:save()
  if session.data.original_url then
      ngx.redirect(session.data.original_url)
  else
      ngx.redirect("/")
  end
end

return _M