#!/usr/bin/env lua

-- Used on lime-utils ubus script
local limewireless = require 'lime.wireless'
local iwinfo = require 'iwinfo'
local utils = require 'lime.utils'
local upgrade = require 'lime.upgrade'
local hotspot_wwan = require "lime.hotspot_wwan"

local limeutils = {}

function limeutils.get_cloud_nodes()
    local nodes = utils.unsafe_shell(
                      "cat /tmp/bat-hosts | grep bat0 | cut -d' ' -f2 | sed 's/_bat0//' | sed 's/_/-/g' | sort | uniq")
    local result = {}
    result.nodes = {}
    for line in nodes:gmatch("[^\n]*") do
        if line ~= "" then table.insert(result.nodes, line) end
    end
    result.status = "ok"
    return result
end

-- todo(kon): move to utility class?? 
function limeutils.get_station_traffic(params)
    local iface = params.iface
    local mac = params.station_mac
    local result = {}
    local traffic = utils.unsafe_shell(
                        "iw " .. iface .. " station get " .. mac ..
                            " | grep bytes | awk '{ print $3}'")
    words = {}
    for w in traffic:gmatch("[^\n]+") do table.insert(words, w) end
    rx = words[1]
    tx = words[2]
    result.station = mac
    result.rx_bytes = tonumber(rx, 10)
    result.tx_bytes = tonumber(tx, 10)
    result.status = "ok"
    return result
end

function limeutils.get_mesh_ifaces()
    local result = {}
    result.ifaces = limewireless.mesh_ifaces()
    return result
end

function limeutils.get_node_status()
    local result = {}
    result.hostname = utils.hostname()
    result.ips = {}
    local ips = utils.unsafe_shell(
                    "ip a s br-lan | grep inet | awk '{ print $1, $2 }'")
    for line in ips:gmatch("[^\n]+") do
        local words = {}
        for w in line:gmatch("%S+") do
            if w ~= "" then table.insert(words, w) end
        end
        local version = words[1]
        local address = words[2]
        if version == "inet6" then
            table.insert(result.ips, {version = "6", address = address})
        else
            table.insert(result.ips, {version = "4", address = address})
        end
    end
    local ifaces = limewireless.mesh_ifaces()
    local stations = {}
    for _, iface in ipairs(ifaces) do
        iface_type = iwinfo.type(iface)
        iface_stations = iface_type and iwinfo[iface_type].assoclist(iface)
        if iface_stations then
            for mac, station in pairs(iface_stations) do
                station['iface'] = iface
                station.station_mac = mac
                table.insert(stations, station)
            end
        end
    end
    if next(stations) ~= nil then
        local most_active_rx = 0
        local most_active = nil
        for _, station in ipairs(stations) do
            local traffic = utils.unsafe_shell(
                                "iw " .. station.iface .. " station get " ..
                                    station.station_mac ..
                                    " | grep bytes | awk '{ print $3}'")
            words = {}
            for w in traffic:gmatch("[^\n]+") do
                table.insert(words, w)
            end
            rx = words[1]
            tx = words[2]
            station.rx_bytes = tonumber(rx, 10)
            station.tx_bytes = tonumber(tx, 10)
            if station.rx_bytes > most_active_rx then
                most_active_rx = station.rx_bytes
                most_active = station
            end
        end
        local station_traffic = get_station_traffic({
            iface = most_active.iface,
            station_mac = most_active.station_mac
        })
        most_active.rx_bytes = station_traffic.rx_bytes
        most_active.tx_bytes = station_traffic.tx_bytes
        result.most_active = most_active
    end
    result.uptime = tostring(utils.uptime_s())

    result.status = "ok"
    return result
end

function limeutils.get_notes()
    local result = {}
    result.notes = utils.read_file('/etc/banner.notes') or ''
    result.status = "ok"
    return result
end

function limeutils.set_notes(msg)
    local banner = utils.write_file('/etc/banner.notes', msg.text)
    return limeutils.get_notes()
end

function limeutils.get_community_settings()
    local config = conn:call("uci", "get", {config = "lime-app"}).values
    if config ~= nil then
        for name, value in pairs(config) do
            -- TODO: Find a best way to remove uci keys
            function table.removekey(table, key)
                local element = table[key]
                table[key] = nil
                return element
            end
            table.removekey(value, ".name")
            table.removekey(value, ".index")
            table.removekey(value, ".anonymous")
            table.removekey(value, ".type")
            return value
        end
    else
        return {error = "config not found"}
    end
end

-- todo(kon): move to utility class?? 
function limeutils.get_channels()
    local devices = limewireless.scandevices()
    local phys = {}
    for k, radio in pairs(devices) do
        local phyIndex = radio[".name"].sub(radio[".name"], -1)
        phys[k] = {phy = "phy" .. phyIndex}
        if limewireless.is5Ghz(radio[".name"]) then
            phys[k].freq = '5ghz'
        else
            phys[k].freq = '2.4ghz'
        end
    end
    local frequencies = {}
    for _, phy in pairs(phys) do
        local info = utils.unsafe_shell("iw " .. phy.phy ..
                                            " info | sed -n '/Frequencies:/,/valid/p' | sed '1d;$d' | grep -v radar | grep -v disabled | sed -e 's/.*\\[\\(.*\\)\\].*/\\1/'")
        frequencies[phy.freq] = utils.split(info, '\n')
    end
    return frequencies
end

function limeutils.get_config()
    local result = conn:call("uci", "get",
                             {config = "lime-autogen", section = "wifi"})
    result.channels = get_channels()
    return result
end

function limeutils.get_upgrade_info()
    local result = upgrade.get_upgrade_info()
    if not result then return {status = "error"} end
    result.status = 'ok'
    return result
end

function limeutils.safe_reboot(msg)
    local result = {}
    local function getStatus()
        local f = io.open('/overlay/upper/.etc.last-good.tgz', "rb")
        if f then f:close() end
        return f ~= nil
    end

    -- Get safe-reboot status
    if msg.action == nil then return {error = true} end
    if msg.action == 'status' then result.stauts = getStatus() end

    --  Start safe-reboot
    if msg.action == 'start' then
        local args = ''
        if msg.value ~= nil then
            if msg.value.wait ~= nil then
                args = args .. ' -w ' .. msg.value.wait
            end
            if msg.value.fallback ~= nil then
                args = args .. ' -f ' .. msg.value.fallback
            end
        end
        local sr = assert(io.popen('safe-reboot ' .. args))
        sr:close()
        result.status = getStatus()
        if result.status == true then result.started = true end
    end

    -- Rreboot now and wait for fallback timeout
    if msg.action == 'now' then
        local sr = assert(io.popen('safe-reboot now'))
        result.status = getStatus()
        result.now = result.status
    end

    -- Keep changes and stop safe-reboot
    if msg.action == 'cancel' then
        result.status = true
        result.canceled = false
        local sr = assert(io.popen('safe-reboot cancel'))
        sr:close()
        if getStatus() == false then
            result.status = false
            result.canceled = true
        end
    end

    --  Discard changes - Restore previous state and reboot
    if msg.action == 'discard' then
        local sr = assert(io.popen('safe-reboot discard'))
        sr:close()
        result.status = getStatus()
        if result.status == true then result.started = true end
    end

    return result
end

function limeutils.hotspot_wwan_get_status(msg)
    local msg = msg or {}
    local status, errmsg = hotspot_wwan.status(msg.radio)
    if status then
        return {
            status = 'ok',
            enabled = status.enabled,
            connected = status.connected,
            signal = status.signal
        }
    else
        return {status = 'error', message = errmsg}
    end
end

return limeutils
