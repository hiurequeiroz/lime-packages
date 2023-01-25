local mylist = {}
for line in io.lines("/tmp/ffomppt/csv.log") do
        local nodeid, packetrev, timestamp, firmware_type, nextreboot, powersave, V_oc, V_in, V_out, charge_state_int, health_estimate, battery_temperature, low_voltage_disconnect, temp_corr, rated_batt_capacity, solar_module_capacity, lat, long, statuscode = line:match("(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-);(.-)")
        mylist[#mylist + 1] = { nodeid = nodeid, packetrev = packetrev, timestamp = timestamp, firmware_type = firmware_type, nextreboot = nextreboot, powersave = powersave, V_oc = V_oc, V_in = V_in, V_out = V_out, charge_state_int = charge_state_int, health_estimate = health_estimate, battery_temperature = battery_temperature , low_voltage_disconnect = low_voltage_disconnect, temp_corr = temp_corr, rated_batt_capacity = rated_batt_capacity, solar_module_capacity = solar_module_capacity, lat = lat, long = long, statuscode = statuscode}
        -- local nome, id, num1, num2 = line:match("(.-);(%d*);(%d*);(%d*)")
        -- mylist[#mylist +1] = {nome = nome, id = id, num1=num1, num2=num2}
        date = tonumber(mylist[#mylist]['timestamp'])
        print(os.date("%Y %m %d %H:%M:%S", date))
        print(mylist[#mylist]["charge_state_int"])
end

-- local time = 1674469893
-- print(os.date("%Y %m %d %H:%M:%S", time))