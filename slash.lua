local discordia = require 'discordia'
local discordia_interactions = require 'discordia-interactions'

local classes = discordia.class.classes
local enums = discordia.enums
local f = string.format

---@alias slashcommand {id: string, type: 1, application_id: string, name: string, description: string, options?: commandoptions, default_member_permissions: true, default_permission: true}
---@alias commandoptions {type: optiontypes, name: string, description: string, required?: boolean, choices: optionchoices, options?: commandoptions, min_value?: number, max_value?: number, min_length?: integer, max_length?: integer}
---@alias optionchoices {name: string, value: string|number}
---@alias optiontypes
---SUB_COMMAND
---|1
---SUB_COMMAND_GROUP
---|2
---STRING
---|3
---INTEGER
---|4
---BOOLEAN
---|5
---USER
---|6
---CHANNEL
---|7
---ROLE
---|8
---MENTIONABLE
---|9
---NUMBER
---|10
---ATTACHMENT
---|11

-- First inject the needed endpoints into Discordia's API.lua
do
  -- define API.request to be identical to discordia/API.request
  local discordia_api = classes.API
  local API = {
    request = discordia_api.request,
  }

  -- endpoints we will need
  local endpoints = {
    guildApplicationCommands  = '/applications/%s/guilds/%s/commands',
    globalApplicationCommands = '/applications/%s/commands',
  }

  function API:getGlobalApplicationCommands(application_id)
    local endpoint = f(endpoints.globalApplicationCommands, application_id)
    return self:request('GET', endpoint)
  end

  function API:createGlobalApplicationCommand(application_id, payload)
    local endpoint = f(endpoints.globalApplicationCommands, application_id)
    return self:request('POST', endpoint, payload)
  end

  function API:createGuildApplicationCommand(application_id, payload, guild_id)
    local endpoint = f(endpoints.guildApplicationCommands, application_id, guild_id)
    return self:request('POST', endpoint, payload)
  end

  function API:bulkOverwriteGlobalApplicationCommands(application_id, payload)
    local endpoint = f(endpoints.globalApplicationCommands, application_id)
    return self:request('PUT', endpoint, payload)
  end

  -- inject the new API calls into the actual discordia/API
  do
    for k, v in pairs(API) do
      rawset(discordia_api, k, v)
    end
  end
end

-- Inject Client methods we will need
do
  ---@type Client
  local discordia_client = classes.Client

  -- A method to create slash commands.
  -- Note that this method cannot be used as a general implementation;
  -- it is very bare-bones and only includes stuff we need in this bot,
  -- plus it makes many assumptions such as we always want `dm_permission` to be true.
  -- There is also almost no validation checks. No version control, therefor you are suppose
  -- have this in a client:once('ready') event, and it will recreate the command on each time you launch the client.
  ---@param name string
  ---@param description string
  ---@param options? commandoptions
  ---@return slashcommand|nil command, string? err
  function discordia_client:createSlashCommand(name, description, options, guild)
    local call
    if guild then
      call = self._api.createGuildApplicationCommand
    else
      call = self._api.createGlobalApplicationCommand
    end
    local data, err = call(self._api, self.user.id, {
      type = 1, -- CHAT_INPUT
      name = name,
      description = description,
      options = options,
      dm_permission = true,
      default_permission = true,
    }, guild)

    if data then
      return data
    else
      return nil, err
    end
  end

  function discordia_client:bulkOverwriteSlashCommands(commands)
    local payload = {}
    for _, command in pairs(commands) do
      table.insert(payload, {
        type = 1,
        name = command.name,
        description = command.description,
        options = command.options,
        dm_permission = true,
        default_permission = true,
      })
    end
    local data, err = self._api:bulkOverwriteGlobalApplicationCommands(self.user.id, payload)
    if data then
      return data
    else
      return nil, err
    end
  end
end

-- Add an interactions prelistener to emit needed events
do
  ---@param intr Interaction
  ---@param client Client
  function discordia_interactions.EventHandler.interaction_create_prelisteners.slashCommands(intr, client)
    if intr.type == enums.interactionType.applicationCommand and intr.data.type == 1 then
      client:emit('slashCommand', intr)
    end
  end

  function discordia_interactions.EventHandler.interaction_create_prelisteners.autocomplete(intr, client)
    if intr.type == enums.interactionType.applicationCommandAutocomplete and intr.data.type == 1 then
      client:emit('slashCommandAutocomplete', intr)
    end
  end
end
