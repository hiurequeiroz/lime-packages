#!/usr/bin/env lua
--[[
  Copyright (C) 2020 LibreMesh.org
  This is free software, licensed under the GNU AFFERO GENERAL PUBLIC LICENSE Version 3

  Copyright 2020 Santiago Piccinini <spiccinini@altermindi.net>
]]--


local utils = require 'lime.utils'
local config = require 'lime.config'
local upgrade = require 'lime.upgrade'
local hotspot_wwan = require "lime.hotspot_wwan"


local UPGRADE_METADATA_FILE = "/etc/upgrade_metadata"

local limeutilsadmin = {}

function limeutilsadmin.set_root_password(msg)
    local result = nil
    if type(msg.password) ~= "string" then
        result = {status = 'error', msg = 'Password must be a string'}
    else
        utils.set_shared_root_password(msg.password or '')
        result = {status = 'ok'}
    end
    return result
end

function limeutilsadmin.set_hostname(msg)
    if msg.hostname ~= nil and utils.is_valid_hostname(msg.hostname) then
        local uci = config.get_uci_cursor()
        uci:set(config.UCI_NODE_NAME, 'system', 'hostname', msg.hostname)
        uci:commit(config.UCI_NODE_NAME)
        utils.unsafe_shell("lime-config")
        return { status = 'ok'}
    else
        local err
        if msg.hostname then
            err = 'Invalid hostname'
        else
            err = 'Hostname not provided'
        end
        return { status = 'error', msg = err }
    end
end

function limeutilsadmin.is_upgrade_confirm_supported()
    local supported = upgrade.is_upgrade_confirm_supported()
    return {status = 'ok', supported = supported}
end


function limeutilsadmin.firmware_upgrade(msg)
    local status, ret = upgrade.firmware_upgrade(msg.fw_path, msg.preserve_config, msg.metadata, msg.fw_type)
    if status then
        return {status = 'ok', metadata = ret}
    else
        return {status = 'error', message = ret}
    end
end

function limeutilsadmin.last_upgrade_metadata()
    local metadata
    if utils.file_exists(UPGRADE_METADATA_FILE) then
        metadata = utils.read_obj_store(UPGRADE_METADATA_FILE)
        return {status = 'ok', metadata = metadata}
    else
        return {status = 'error', message = 'No metadata available'}
    end
end

function limeutilsadmin.firmware_confirm()
    local exit_code = os.execute("safe-upgrade confirm > /dev/null 2>&1")
    local status = 'error'
    if exit_code == 0 then
        status = 'ok'
    end
    return {status = status, exit_code = exit_code}
end

--! Creates a client connection to a wifi hotspot
function limeutilsadmin.hotspot_wwan_enable(msg)
    local msg = msg or {}
    local status, errmsg = hotspot_wwan.safe_enable(msg.ssid, msg.password, msg.encryption, msg.radio)
    if status then
        return {status = 'ok'}
    else
        return {status = 'error', message = errmsg}
    end
end


function limeutilsadmin.hotspot_wwan_disable(msg)
    local msg = msg or {}
    local status, errmsg = hotspot_wwan.disable(msg.radio)
    if status then
        return {status = 'ok'}
    else
        return {status = 'error', message = errmsg}
    end
end

return limeutilsadmin

