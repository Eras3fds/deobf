#!/usr/bin/env luajit
-- ============================================================================
-- Prometheus Deobfuscator CLI v3.0-UNSAFE
-- Usage: luajit cli.lua <input.lua> [output.lua] [--verbose]
-- ============================================================================

local PrometheusDeobfuscator = {
    VERSION = "3.0-UNSAFE-CLI",
    config = {
        verbose = false,
        maxIterations = 15,
        removeAntiTamper = true,
        resolveConstantArray = true,
        decryptStrings = true,
        unsplitStrings = true,
        simplifyNumbers = true,
        unwrapProxies = true,
        removeWatermarks = true,
        devirtualize = true,
    },
    stats = {}
}

-- ============================================================================
-- ⚠️ DIRECT EXECUTION (NO SANDBOX)
-- ============================================================================

local UnsafeExecutor = {
    execute = function(code)
        local func, err = loadstring(code)
        if not func then return nil, err end
        local success, result = pcall(func)
        if success then return result, nil end
        return nil, result
    end,
    
    callFunction = function(code, funcName, args)
        local wrapper = string.format("%s\nreturn %s(%s)", code, funcName, table.concat(args, ", "))
        return UnsafeExecutor.execute(wrapper)
    end,
}

-- ============================================================================
-- 🔍 PATTERN DETECTORS
-- ============================================================================

local PatternDetector = {
    wrapper = function(code)
        local patterns = {
            "^%s*%(%s*function%(%.-%)(.-)%s*end%)(%b())$",
            "^%s*return%s*%(%s*function%(%.-%)(.-)%s*end%)(%b())$",
            "^%s*%(function%(%%...%)%s*(.-)%s*end%)%(%)"
        }
        for _, p in ipairs(patterns) do
            local inner = code:match(p)
            if inner then return true, inner end
        end
        return false
    end,
    
    antiTamper = function(code)
        return code:match("debug%.sethook") ~= nil or
               code:match("Tamper Detected!") ~= nil or
               code:match("repeat%s+until%s+valid") ~= nil
    end,
    
    watermark = function(code)
        return code:match("_WATERMARK") ~= nil or
               code:match("Prometheus Obfuscator") ~= nil
    end,
    
    constantArray = function(code)
        local arrName = code:match("local%s+([%w_]+)%s*=%s*%{.-}%s*;")
        if arrName and code:match("function%s+%w+%s*%(%w+%)%.-return%s+" .. arrName .. "%[") then
            return arrName
        end
        return nil
    end,
    
    vmify = function(code)
        return code:match("newproxy") ~= nil and code:match("local%s+V%s*=%s*%b{}") ~= nil
    end,
}

-- ============================================================================
-- 🔄 DEOBFUSCATION STAGES
-- ============================================================================

local Stages = {}

Stages.removeWrappers = function(code)
    local changed = false
    repeat
        changed = false
        local isWrapper, inner = PatternDetector.wrapper(code)
        if isWrapper then
            code = inner
            PrometheusDeobfuscator.stats.wrappersRemoved = (PrometheusDeobfuscator.stats.wrappersRemoved or 0) + 1
            changed = true
        end
    until not changed
    return code
end

Stages.removeAntiTamper = function(code)
    if not PrometheusDeobfuscator.config.removeAntiTamper then return code end
    local patterns = {
        "do%s+local%s+valid%s*=.-repeat%s+until%s+valid;.-end",
        "debug%.sethook%(.-%)%s*.-%s*end",
        "pcall%([^%)]-%).-Tamper Detected!.-end",
    }
    local removed = 0
    for _, p in ipairs(patterns) do
        local newCode, n = code:gsub(p, "")
        if n > 0 then code = newCode; removed = removed + n end
    end
    PrometheusDeobfuscator.stats.antiTamperRemoved = removed
    return code
end

Stages.removeWatermarks = function(code)
    if not PrometheusDeobfuscator.config.removeWatermarks then return code end
    local patterns = {
        "local%s+_%w+%s*=%s*\"[^\"]-Prometheus Obfuscator[^\"]*\"",
        "_WATERMARK[^%w].-[\n;]",
        "Watermark[^%w].-[\n;]",
    }
    for _, p in ipairs(patterns) do
        code = code:gsub(p, "\n")
    end
    return code
end

Stages.devirtualize = function(code)
    if not PrometheusDeobfuscator.config.devirtualize then return code end
    if not PatternDetector.vmify(code) then return code end
    
    -- Direct VM execution to extract original code
    local vmExtractor = string.format([[
        local bytecode = loadstring(%q)
        if not bytecode then return nil end
        
        -- Hook into VM to capture original code
        local originalEnv = getfenv(bytecode)
        local captured = nil
        
        local origNewProxy = originalEnv.newproxy or newproxy
        originalEnv.newproxy = function()
            local proxy = origNewProxy()
            local meta = getmetatable(proxy) or {}
            local origIndex = meta.__index or function() end
            meta.__index = function(t, k)
                local v = origIndex(t, k)
                if type(v) == "string" and #v > 50 then
                    captured = v
                end
                return v
            end
            setmetatable(proxy, meta)
            return proxy
        end
        
        setfenv(bytecode, originalEnv)
        bytecode()
        return captured
    ]], code)
    
    local result, err = UnsafeExecutor.execute(vmExtractor)
    if result and type(result) == "string" then
        print("✅ Extracted original code from VM (" .. #result .. " bytes)")
        PrometheusDeobfuscator.stats.vmInstructions = 1
        return result
    end
    
    print("⚠️  VM extraction failed: " .. (err or "unknown"))
    return code
end

Stages.resolveConstantArray = function(code)
    if not PrometheusDeobfuscator.config.resolveConstantArray then return code end
    
    local arrName = PatternDetector.constantArray(code)
    if not arrName then return code end
    
    -- Extract constants
    local constants = {}
    for val in code:gmatch('%f["\']["\']([^"\']+)["\']%f[^"\']') do
        table.insert(constants, val)
    end
    if #constants == 0 then return code end
    
    -- Find wrapper function
    local wrapperName = code:match("function%s+(%w+)%s*%(%s*%w+%s*%).-return%s+" .. arrName)
    if not wrapperName then return code end
    
    -- Replace wrapper calls
    local resolved = 0
    code = code:gsub(wrapperName .. "%s*%(%s*(%d+)%s*%)", function(idx)
        local index = tonumber(idx)
        if constants[index] then
            resolved = resolved + 1
            return string.format("%q", constants[index])
        end
        return wrapperName .. "(" .. idx .. ")"
    end)
    
    PrometheusDeobfuscator.stats.constantsResolved = resolved
    
    -- Clean up
    code = code:gsub("local%s+" .. arrName .. "%s*=%s*%b{}%s*;%s*", "", 1)
    code = code:gsub("function%s+" .. wrapperName .. "%b().-end", "", 1)
    
    return code
end

Stages.decryptStrings = function(code)
    if not PrometheusDeobfuscator.config.decryptStrings then return code end
    
    -- Extract decryption code
    local decryptStart = code:find("do%s+local%s+floor%s*=")
    local decryptEnd = select(2, code:find("STRINGS%s*=.-__index%s*=.-end", decryptStart))
    if not decryptStart or not decryptEnd then return code end
    
    local decryptCode = code:sub(decryptStart, decryptEnd)
    
    -- Execute once to get decryptor
    local setupSuccess, decryptFunc = UnsafeExecutor.execute(decryptCode .. "\nreturn DECRYPT")
    if not setupSuccess or type(decryptFunc) ~= "function" then return code end
    
    -- Replace encrypted accesses
    local decrypted = 0
    code = code:gsub('(%w+)%s*%[%s*(%w+)%s*%(%s*"([^"]+)"%s*,%s*(%d+)%s*%)%s*%]', function(tbl, func, encStr, seed)
        local result = decryptFunc(encStr, tonumber(seed))
        if result and type(result) == "string" then
            decrypted = decrypted + 1
            return string.format("%q", result)
        end
        return tbl .. "[" .. func .. '("' .. encStr .. '", ' .. seed .. ")]"
    end)
    
    PrometheusDeobfuscator.stats.stringsDecrypted = decrypted
    code = code:gsub("do%s+local%s+floor%s*=.-__index%s*=.-end", "", 1)
    return code
end

Stages.reconstructSplitStrings = function(code)
    if not PrometheusDeobfuscator.config.unsplitStrings then return code end
    
    local fixed = 0
    
    code = code:gsub("table%.concat%s*%(%s*%b{}%s*%)", function(match)
        local parts = {}
        for str in match:gmatch("[\"']([^\"']+)[\"']") do
            table.insert(parts, str)
        end
        if #parts > 1 then
            fixed = fixed + 1
            return string.format("%q", table.concat(parts))
        end
        return match
    end)
    
    code = code:gsub("(\"[^\"]+\")%s*%.%.%s*(\"[^\"]+\")", function(a, b)
        local str1 = a:match("\"([^\"]*)\"")
        local str2 = b:match("\"([^\"]*)\"")
        if str1 and str2 then
            fixed = fixed + 1
            return string.format("%q", str1 .. str2)
        end
        return a .. " .. " .. b
    end)
    
    PrometheusDeobfuscator.stats.stringsRebuilt = fixed
    return code
end

Stages.simplifyNumbers = function(code)
    if not PrometheusDeobfuscator.config.simplifyNumbers then return code end
    
    local function evaluate(expr, depth)
        if depth > 10 then return expr end
        
        local inner = expr:match("^%s*%((.-)%)$")
        if inner then return evaluate(inner, depth + 1) end
        
        local a, b = expr:match("^(.-)%s*%+%s*(.-)$")
        if a and b then
            local valA = tonumber(evaluate(a, depth + 1))
            local valB = tonumber(evaluate(b, depth + 1))
            if valA and valB then return tostring(valA + valB) end
        end
        
        a, b = expr:match("^(.-)%s*%-%s*(.-)$")
        if a and b then
            local valA = tonumber(evaluate(a, depth + 1))
            local valB = tonumber(evaluate(b, depth + 1))
            if valA and valB then return tostring(valA - valB) end
        end
        
        if expr:match("^0[xX][0-9a-fA-F]+$") then
            return tostring(tonumber(expr))
        end
        
        return expr
    end
    
    local simplified = 0
    code = code:gsub("(%b())", function(expr)
        local result = evaluate(expr, 0)
        if tonumber(result) and result ~= expr then
            simplified = simplified + 1
            return result
        end
        return expr
    end)
    
    PrometheusDeobfuscator.stats.numbersSimplified = simplified
    return code
end

Stages.unwrapProxies = function(code)
    if not PrometheusDeobfuscator.config.unwrapProxies then return code end
    
    local removed = 0
    
    code = code:gsub("local%s+setmetatable%s*=%s*setmetatable%s*;%s*", function()
        removed = removed + 1
        return ""
    end)
    
    code = code:gsub("setmetatable%s*%(%s*%b{}%s*,%s*%b{}%s*%)", function(match)
        local value = match:match("%{%s*%[\"?([^\"']+)\"?%]%s*=%s*([^%}]*)%s*%}")
        if value then
            removed = removed + 1
            return value
        end
        return match
    end)
    
    PrometheusDeobfuscator.stats.proxiesUnwrapped = removed
    return code
end

-- ============================================================================
-- 📊 MAIN PIPELINE
-- ============================================================================

local function log(msg)
    if PrometheusDeobfuscator.config.verbose then
        io.stderr:write("[PrometheusDeob] " .. msg .. "\n")
    end
end

function PrometheusDeobfuscator.deobfuscate(code)
    log("=== Starting Prometheus Deobfuscation v" .. PrometheusDeobfuscator.VERSION .. " ===")
    log("⚠️  UNSAFE MODE - Direct code execution ⚠️")
    log("Input size: " .. #code .. " bytes")
    
    local iterations = 0
    local changed = true
    
    while changed and iterations < PrometheusDeobfuscator.config.maxIterations do
        changed = false
        iterations = iterations + 1
        
        log("\n--- Iteration " .. iterations .. " ---")
        
        local stages = {
            Stages.removeWrappers,
            Stages.removeAntiTamper,
            Stages.removeWatermarks,
            Stages.devirtualize,
            Stages.resolveConstantArray,
            Stages.decryptStrings,
            Stages.reconstructSplitStrings,
            Stages.simplifyNumbers,
            Stages.unwrapProxies,
        }
        
        for _, stage in ipairs(stages) do
            local newCode = stage(code)
            if newCode ~= code then
                code = newCode
                changed = true
            end
        end
        
        local clean = code:gsub("\n%s*\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
        if clean ~= code then
            code = clean
            changed = true
        end
    end
    
    log("\n=== Deobfuscation Complete ===")
    log("Iterations: " .. iterations)
    log("Final size: " .. #code .. " bytes")
    
    return code
end

-- ============================================================================
-- 📁 CLI ENTRY POINT
-- ============================================================================

local function printUsage()
    print("Usage: luajit cli.lua <input.lua> [output.lua] [--verbose]")
    print("Options:")
    print("  --verbose    Show detailed logs")
    os.exit(1)
end

local inputFile = arg[1]
local outputFile = arg[2]

if not inputFile then
    printUsage()
end

-- Parse flags
if arg[3] == "--verbose" or (arg[2] and arg[2] == "--verbose") then
    PrometheusDeobfuscator.config.verbose = true
    if arg[2] == "--verbose" then outputFile = nil end
end

-- Read input
local file = io.open(inputFile, "rb")
if not file then
    print("Error: Cannot open " .. inputFile)
    os.exit(1)
end

local code = file:read("*all")
file:close()

-- Deobfuscate
local success, clean = pcall(PrometheusDeobfuscator.deobfuscate, PrometheusDeobfuscator, code)
if not success then
    print("Error during deobfuscation: " .. clean)
    os.exit(1)
end

-- Write output
outputFile = outputFile or inputFile:gsub("%.lua$", "") .. "_deobfuscated.lua"
local out = io.open(outputFile, "wb")
if not out then
    print("Error: Cannot write to " .. outputFile)
    os.exit(1)
end

out:write(clean)
out:close()

print("✅ Deobfuscated: " .. outputFile)
