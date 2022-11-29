local utils = require "lime.utils"
local test_utils = require "tests.utils"
local hotspot_wwan = require 'lime.hotspot_wwan'
local limeutils = require "lime-utils"
local json = require 'luci.jsonc'

local uci
local snapshot -- to revert luassert stubs and spies

describe('ubus-lime-utils tests #ubuslimeutils', function()

    it('test get_notes', function()
        stub(utils, "read_file", function () return 'a note' end)

        local response  = limeutils.get_notes()
        assert.is.equal("ok", response.status)
        assert.is.equal("a note", response.notes)
        assert.stub(utils.read_file).was.called_with('/etc/banner.notes')
    end)

    it('test get_notes when there are no notes', function()
        local response  = limeutils.get_notes()
        assert.is.equal("ok", response.status)
        assert.is.equal("", response.notes)
    end)

    it('test set_notes', function()
        stub(utils, "read_file", function () return 'a note' end)
        stub(utils, "write_file", function ()  end)
        local response  = limeutils.set_notes(json.parse('{"text": "a new note"}'))
        assert.is.equal("ok", response.status)
        assert.is.equal("a note", response.notes)
        assert.stub(utils.read_file).was.called_with('/etc/banner.notes')
    end)

    it('test get_cloud_nodes', function()
        stub(utils, "unsafe_shell", function () return 'lm-node1\nlm-node2\n' end)
        local response  = limeutils.get_cloud_nodes()
        assert.is.equal("ok", response.status)
        assert.are.same({"lm-node1", "lm-node2"}, response.nodes)
    end)

    it('test get_node_status', function()
        stub(utils, "unsafe_shell", function () return '' end)
        stub(utils, "uptime_s", function () return '123' end)

        local response  = limeutils.get_node_status()
        assert.is.equal("ok", response.status)
        assert.is.equal(utils.hostname(), response.hostname)
        assert.are.same({}, response.ips)
        assert.is.equal("123", response.uptime)
    end)

    it('test get_upgrade_info', function()
        stub(utils, "unsafe_shell", function () return '-1' end)
        stub(os, "execute", function () return '0' end)

        local response  = limeutils.get_upgrade_info()
        assert.is.equal("ok", response.status)
        assert.is_false(response.is_upgrade_confirm_supported)
        assert.are.same(-1, response.safe_upgrade_confirm_remaining_s)

        os.execute:revert()
        os.execute("rm -f /tmp/upgrade_info_cache")
    end)

    it('test hotspot_wwan_get_status', function()
        stub(hotspot_wwan, "status", function () return {connected = false} end)

        local response  = limeutils.hotspot_wwan_get_status()
        assert.is.equal("ok", response.status)
        assert.is_false(response.connected)
        assert.stub(hotspot_wwan.status).was.called()

        local response  = limeutils.hotspot_wwan_get_status(json.parse('{"radio":"radio1"}'))
        assert.stub(hotspot_wwan.status).was.called_with('radio1')
    end)

    it('test hotspot_wwan_is_connected when connected', function()
        stub(hotspot_wwan, "status", function () return {connected = true, signal = -66} end)
        local response  = limeutils.hotspot_wwan_get_status()
        assert.is.equal("ok", response.status)
        assert.is_true(response.connected)
        assert.is.equal(-66, response.signal)
    end)

    before_each('', function()
        snapshot = assert:snapshot()
        uci = test_utils.setup_test_uci()
    end)

    after_each('', function()
        snapshot:revert()
        test_utils.teardown_test_uci(uci)
    end)
end)
