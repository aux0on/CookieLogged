local _shared = odh_shared_plugins
local _game = _shared.game_name

if _game == "Murder Mystery 2" then
    _shared.load_from_github_url("/aux0on/bomb/refs/heads/main/jump.lua")
elseif _game == "Murder Mystery Modded" then
    _shared.load_from_github_url("/aux0on/bomb/refs/heads/main/jump.lua")
end
