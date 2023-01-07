local c = require("component")
local event = require("event")
local os = require("os")
local computer = require("computer")
local modem = c.modem;
local address = require("address")
local serializer = require("serialization")

function Close()
    modem.close(DialerPort)
    modem.close(GdoPort)
    os.exit()
end

-- Port the dialer works on
DialerPort = 425
-- Port the GDO works on 
GdoPort = 428
-- Port the address storage works on
AddressPort = 431

-- Open ports on the modem
modem.open(DialerPort)
modem.open(GdoPort)

function Gdo() 
    io.write("Enter IDC: ")
    -- Read the IDC code from the user
    local code = io.read() 

    -- Broadcast the IDC
    if modem.broadcast(GdoPort, "IDC:" .. code) == true then
        print("Sent IDC code!")
    else
        print("Failed to send IDC")
        Close()
    end
    
    -- Try 5 times to recive a response from the iris computer
    local attempts = 5
    local timeout = 5

    for i = 1, attempts do
        local _, _, _, _, _, message_raw = event.pull(timeout, "modem_message")

        if message_raw == nil then
            io.write(tostring(i))
            goto continue
        end

        -- convert the message to a string
        local message = tostring(message_raw)

        -- if the message is correct, then the iris has been opened
        if message == "IRIS_IS_OPEN" then
            print("\nIris opened!")
            goto gdo_end
        elseif string.sub(message, 1, 4) ~= "IDC:" then
            print("\nInvalid response recived! res:" .. message)
        else
            print("\nPotential interference detected! IDC message recieved before iris open message!")
        end

        ::continue::
    end

    print("\nIris open message not recieved in " .. attempts * timeout .. " seconds over " .. attempts .. " attempts! Try moving closer to the Stargate!")

    ::gdo_end::
end

function PrintConversionTable(table)
    local i = 0
    for shorthand, glyph_name in pairs(table) do
        io.write("[" .. shorthand .. "] \"" .. glyph_name .. "\" ")

        i = i + 1
        if i == 4 then
            print()
            i = 0
        end
    end
    -- make sure there is always an ending newline
    if i ~= 0 then
        print()
    end
end

function PrintConversion(gate_type) 
    if gate_type == "MW" then
        PrintConversionTable(address.MW)
        return address.MW
    elseif gate_type == "PG" then
        PrintConversionTable(address.PG)
        return address.PG
    elseif gate_type == "UN" then
        PrintConversionTable(address.UN)
        return address.UN
    end
end

function Dialer() 
    -- TODO: add a way to get the current gate type from the dialing computer
    local gate_type = "MW"

    local conversion = PrintConversion(gate_type)

    -- TODO: add a local database of gate addresses

    io.write("Enter address: ")
    local address = tostring(io.read())

    -- TODO: strip the ending PoO from the address

    local converted_address = {}

    local address_len = string.len(address)
    for i = 1, address_len do
        local glyph = string.sub(address, i, i)

        local converted_glyph = conversion[glyph]
        
        table.insert(converted_address, converted_glyph)
    end

    table.insert(converted_address, conversion["q"])

    if #converted_address < 6 or #converted_address > 8 then
        print("Address is too short! (" .. string.len(address) .. ")")
        return
    end

    local serialized_address = serializer.serialize(converted_address)

    print("Sending address: " .. serialized_address)

    -- TODO: add a more robust API for sending addresses
    modem.broadcast(DialerPort, serialized_address)
end

function GetAddresses()
    local get_addresses = {
        ["type"] = "get_addresses"
    }

    modem.open(AddressPort)

    modem.broadcast(AddressPort, serializer.serialize(get_addresses))

    -- Pull the recieved message with a 5s timout
    local _, _, _, _, _, message_raw = event.pull(5, "modem_message")

    if message_raw == nil then
        print("No response recieved!")
        return
    end

    local addresses = serializer.unserialize(message_raw)

    for k, v in pairs(addresses) do
        print(k)
        if string.len(v[1]) ~= 0 then
            print("\tMW: " .. v[1])
        end
        if string.len(v[2]) ~= 0 then
            print("\tPG: " .. v[2])
        end
        if string.len(v[3]) ~= 0 then
            print("\tUN: " .. v[3])
        end
    end

    modem.close(AddressPort)
end

function AddAddress() 
    io.write("Enter name: ")
    local name = io.read()
    io.write("Enter MW address: ")
    local mw = io.read()
    io.write("Enter PG address: ")
    local pg = io.read()
    io.write("Enter UN address: ")
    local un = io.read()

    local add_address = {
        ["type"] = "add_address",
        ["name"] = name,
        ["address"] = {
            mw,
            pg,
            un
        }
    }

    modem.broadcast(AddressPort, serializer.serialize(add_address))
end

function Addresses()
    io.write("[G]et Addresses [A]dd address [C]ancel?")
    local input = io.read()

    input = string.sub(string.lower(input), 1, 1)

    if input == 'g' then 
        GetAddresses()
    elseif input == 'a' then
        AddAddress()
    elseif input == 'c' then
        return
    end
end

Run = true

function PrintInterface()
    io.write("[G]DO [D]ialer [A]ddresses [Q]uit?")
    local input = io.read()

    input = string.sub(string.lower(input), 1, 1)

    if input == 'g' then 
        Gdo()
    elseif input == 'd' then
        Dialer()
    elseif input == 'a' then
        Addresses()
    elseif input == 'q' then
        print("Quitting...")
        Run = false    
    else
        print("Unknown input! (" .. input .. ")")
    end
end

while Run do
    PrintInterface()
end