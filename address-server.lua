local component = require("component")
local event = require("event")
local os = require("os")
local computer = require("computer")
local modem = component.modem;
local address = require("address")
local serialization = require("serialization")
local filesystem = require("filesystem")

AddressPort = 431

Filename = "addresses.json"

function GetAddresses() 
    if pcall(function() 
        local file = io.open(Filename, "r")
    
        io.close(file)
    end) == false then
        print("No addresses file found...")
        return {}
    end

    -- Open the file for reading
    local file = io.open(Filename, "r")

    -- Read the addresses into a table
    local addresses = serialization.unserialize(file:read("*a"))

    -- Close the file
    io.close(file)

    -- Return the table
    return addresses;
end

function AddAddress(name, address) 
    -- Get the current list of addresses
    local addresses = GetAddresses()

    -- Add the address to the list
    addresses[name] = address

    -- Open the file for writing (recreating if exists)
    local file = io.open(Filename, "w")

    -- Write the new list to the file
    file:write(serialization.serialize(addresses))

    -- Close the file
    io.close(file)
end

function Listen(_, _, from, port, _, message_raw) 
    if port ~= AddressPort then
        return
    end

    if message_raw == nil then
        return
    end

    local message = serialization.unserialize(tostring(message_raw))

    if message == nil then
        return
    end

    if message["type"] == "get_addresses" then
        modem.send(from, AddressPort, serialization.serialize(GetAddresses()))
        return
    elseif message["type"] == "add_address" then
        local name = message["name"]
        local address = message["address"]

        print("Raw: " .. message_raw)
        print("Recieved address from " .. from)
        print("Adding address: " .. name .. " " .. address[1] .. " " .. address[2] .. " " .. address[3])

        -- TODO: send error messages back if any of these verification checks are hit
        if address == nil or name == nil then
            print("address or name is nil")
            return
        end

        if type(address) ~= "table" then
            print("address is not a table")
            return
        end

        if #address ~= 3 then
            print("address table is not 3 long")
            return
        end

        if type(address[1]) ~= "string" or type(address[2]) ~= "string" or type(address[3]) ~= "string" then
            print("addresses are not all strings")
            return
        end

        AddAddress(name, address)
        return
    end
end 

modem.open(AddressPort)

-- Set up the event listener
EventRecieved = event.listen("modem_message", Listen)

print("Press enter to exit.")
_ = io.read()

modem.close(AddressPort)

event.cancel(EventRecieved)