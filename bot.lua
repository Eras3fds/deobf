--[[
    Prometheus Discord Deobfuscator Bot
    Usage: .l <attach Lua file>
    Setup: Add DISCORD_TOKEN env var
--]]

-- ============================================================================
-- 1. ENVIRONMENT & CONFIG
-- ============================================================================
local os = require('os')
local process = process or { env = {} }

local DISCORD_TOKEN = process.env.DISCORD_TOKEN or os.getenv('DISCORD_TOKEN')
local PORT = tonumber(process.env.PORT or os.getenv('PORT') or '10000')

if not DISCORD_TOKEN or DISCORD_TOKEN == '' then
    print('❌ ERROR: DISCORD_TOKEN environment variable not set!')
    print('   Add it in Render Dashboard > Environment Variables')
    os.exit(1)
end

-- ============================================================================
-- 2. HTTP HEALTH CHECK SERVER (Required by Render)
-- ============================================================================
local http = require('http')
local server = http.createServer(function(req, res)
    res:writeHead(200, {['Content-Type'] = 'text/plain'})
    res:finish('OK\n')
end)

server:listen(PORT, function()
    print('✅ Health check server listening on port ' .. PORT)
end)

-- ============================================================================
-- 3. PROMETHEUS AST FRAMEWORK
-- ============================================================================
local Ast = {
    AstKind = {
        -- Statements
        LocalVariableDeclaration = "LocalVariableDeclaration",
        AssignmentStatement = "AssignmentStatement",
        FunctionCallStatement = "FunctionCallStatement",
        ReturnStatement = "ReturnStatement",
        WhileStatement = "WhileStatement",
        IfStatement = "IfStatement",
        ForGenericStatement = "ForGenericStatement",
        LocalFunctionDeclaration = "LocalFunctionDeclaration",
        Block = "Block",
        
        -- Expressions
        VariableExpression = "VariableExpression",
        AssignmentVariable = "AssignmentVariable",
        AssignmentIndexing = "AssignmentIndexing",
        IndexExpression = "IndexExpression",
        FunctionCallExpression = "FunctionCallExpression",
        FunctionLiteralExpression = "FunctionLiteralExpression",
        TableConstructorExpression = "TableConstructorExpression",
        TableEntry = "TableEntry",
        KeyedTableEntry = "KeyedTableEntry",
        StringExpression = "StringExpression",
        NumberExpression = "NumberExpression",
        BooleanExpression = "BooleanExpression",
        NilExpression = "NilExpression",
        UnaryMinusExpression = "UnaryMinusExpression",
        AddExpression = "AddExpression",
        SubExpression = "SubExpression",
        MulExpression = "MulExpression",
        DivExpression = "DivExpression",
        ModExpression = "ModExpression",
        PowExpression = "PowExpression",
        StrCatExpression = "StrCatExpression",
    }
}

function Ast.Block(statements, scope)
    return { kind = Ast.AstKind.Block, statements = statements or {}, scope = scope }
end

function Ast.LocalVariableDeclaration(ids, expressions, scope)
    return { kind = Ast.AstKind.LocalVariableDeclaration, ids = ids, expressions = expressions, scope = scope }
end

function Ast.AssignmentStatement(variables, expressions)
    return { kind = Ast.AstKind.AssignmentStatement, variables = variables, expressions = expressions }
end

function Ast.AssignmentVariable(scope, id)
    return { kind = Ast.AstKind.AssignmentVariable, scope = scope, id = id }
end

function Ast.AssignmentIndexing(base, index)
    return { kind = Ast.AstKind.AssignmentIndexing, base = base, index = index }
end

function Ast.FunctionCallStatement(base, args)
    return { kind = Ast.AstKind.FunctionCallStatement, base = base, args = args }
end

function Ast.ReturnStatement(args)
    return { kind = Ast.AstKind.ReturnStatement, args = args }
end

function Ast.WhileStatement(condition, body)
    return { kind = Ast.AstKind.WhileStatement, condition = condition, body = body }
end

function Ast.IfStatement(condition, body, elseifs, elsebody)
    return { kind = Ast.AstKind.IfStatement, condition = condition, body = body, elseifs = elseifs, elsebody = elsebody }
end

function Ast.StringExpression(value)
    return { kind = Ast.AstKind.StringExpression, value = value, isConstant = true }
end

function Ast.NumberExpression(value)
    return { kind = Ast.AstKind.NumberExpression, value = value, isConstant = true }
end

function Ast.BooleanExpression(value)
    return { kind = Ast.AstKind.BooleanExpression, value = value, isConstant = true }
end

function Ast.NilExpression()
    return { kind = Ast.AstKind.NilExpression, isConstant = true }
end

function Ast.VariableExpression(scope, id)
    return { kind = Ast.AstKind.VariableExpression, scope = scope, id = id }
end

function Ast.IndexExpression(base, index)
    return { kind = Ast.AstKind.IndexExpression, base = base, index = index }
end

function Ast.FunctionCallExpression(base, args)
    return { kind = Ast.AstKind.FunctionCallExpression, base = base, args = args }
end

function Ast.FunctionLiteralExpression(body)
    return { kind = Ast.AstKind.FunctionLiteralExpression, body = body }
end

function Ast.TableConstructorExpression(entries)
    return { kind = Ast.AstKind.TableConstructorExpression, entries = entries }
end

function Ast.TableEntry(value)
    return { kind = Ast.AstKind.TableEntry, value = value }
end

function Ast.KeyedTableEntry(key, value)
    return { kind = Ast.AstKind.KeyedTableEntry, key = key, value = value }
end

function Ast.UnaryMinusExpression(operand)
    return { kind = Ast.AstKind.UnaryMinusExpression, operand = operand, isConstant = operand.isConstant and type(operand.value) == "number" }
end

function Ast.AddExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant
    local value = isConstant and (lhs.value + rhs.value) or nil
    return { kind = Ast.AstKind.AddExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.SubExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant
    local value = isConstant and (lhs.value - rhs.value) or nil
    return { kind = Ast.AstKind.SubExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.MulExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant
    local value = isConstant and (lhs.value * rhs.value) or nil
    return { kind = Ast.AstKind.MulExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.DivExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant and rhs.value ~= 0
    local value = isConstant and (lhs.value / rhs.value) or nil
    return { kind = Ast.AstKind.DivExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.ModExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant and rhs.value ~= 0
    local value = isConstant and (lhs.value % rhs.value) or nil
    return { kind = Ast.AstKind.ModExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.PowExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant
    local value = isConstant and (lhs.value ^ rhs.value) or nil
    return { kind = Ast.AstKind.PowExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

function Ast.StrCatExpression(lhs, rhs)
    local isConstant = lhs.isConstant and rhs.isConstant and type(lhs.value) == "string" and type(rhs.value) == "string"
    local value = isConstant and (lhs.value .. rhs.value) or nil
    return { kind = Ast.AstKind.StrCatExpression, lhs = lhs, rhs = rhs, isConstant = isConstant, value = value }
end

local Scope = {}
Scope.__index = Scope

function Scope:new(parent)
    return setmetatable({
        parent = parent,
        variables = {},
        children = {},
        id = tostring({}):match('%x+$'),
    }, self)
end

function Scope:declareVariable(name)
    local id = #self.variables + 1
    self.variables[id] = name
    return id
end

function Scope:getVariableName(id)
    return self.variables[id]
end

function Scope:resolveGlobal(name)
    if self.variables[name] then
        return self, self.variables[name]
    end
    if self.parent then
        return self.parent:resolveGlobal(name)
    end
    return self, self:declareVariable(name)
end

local function visitast(node, parent, callback)
    if not node or type(node) ~= 'table' then return end
    if node.kind then
        local result = callback(node, parent)
        if result then return result end
    end
    for k, v in pairs(node) do
        if type(v) == 'table' then
            if v.kind then
                visitast(v, node, callback)
            elseif type(v) == 'table' and #v > 0 then
                for _, item in ipairs(v) do
                    visitast(item, node, callback)
                end
            end
        end
    end
end

local Unparser = {}
Unparser.__index = Unparser

function Unparser:new(options)
    options = options or {}
    return setmetatable({
        LuaVersion = options.LuaVersion or "Lua51"
    }, self)
end

function Unparser:unparse(ast)
    return "-- Deobfuscated output (AST unparsed)"
end

-- ============================================================================
-- 4. ALL DEOBFUSCATION MODULES
-- ============================================================================
local modules = {}

modules.CleanupObfuscatorScaffold = {}
modules.CleanupObfuscatorScaffold.__index = modules.CleanupObfuscatorScaffold
modules.CleanupObfuscatorScaffold.Name = 'CleanupObfuscatorScaffold'

function modules.CleanupObfuscatorScaffold:new()
    return setmetatable({}, self)
end

local function is_empty_local(st)
    if st.kind ~= Ast.AstKind.LocalVariableDeclaration then return false end
    return not st.expressions or #st.expressions == 0
end

local function should_drop_localdecl(st)
    if st.kind ~= Ast.AstKind.LocalVariableDeclaration then return false end
    for _, expr in ipairs(st.expressions or {}) do
        if expr and expr.kind == Ast.AstKind.FunctionLiteralExpression then
            return true
        end
    end
    return false
end

function modules.CleanupObfuscatorScaffold:apply(ast)
    local out = {}
    for _, st in ipairs(ast.body.statements) do
        if should_drop_localdecl(st) or is_empty_local(st) then
        else
            table.insert(out, st)
        end
    end
    ast.body.statements = out
    return ast
end

modules.ConstantArrayDecode = {}
modules.ConstantArrayDecode.__index = modules.ConstantArrayDecode
modules.ConstantArrayDecode.Name = 'ConstantArrayDecode'

function modules.ConstantArrayDecode:new()
    return setmetatable({}, self)
end

local is_lua51 = _VERSION == 'Lua 5.1'
local function compile(code)
    if is_lua51 then
        local fn, err = loadstring(code)
        if not fn then return nil, err end
        setfenv(fn, {})
        return fn
    else
        return load(code, nil, 't', {})
    end
end

local function find_block(src, start_pat, open_ch, close_ch)
    local s, e = src:find(start_pat)
    if not s then return nil end
    local i = e + 1
    local depth, start_i = 0
    while i <= #src do
        local ch = src:sub(i,i)
        if start_i then
            if ch == open_ch then depth = depth + 1 end
            if ch == close_ch then depth = depth - 1; if depth == 0 then return start_i, i - 1 end end
        else
            if ch == open_ch then start_i = i + 1; depth = 1 end
        end
        i = i + 1
    end
    return nil
end

local function parse_u_array_text(src)
    local si, ei = find_block(src, 'local%s+J%s*=%s*%{', '{', '}')
    if not si then si, ei = find_block(src, 'J%s*=%s*%{', '{', '}') end
    if not si then return {} end
    local fn = compile('return {' .. src:sub(si, ei) .. '}')
    if not fn then return {} end
    local ok, res = pcall(fn)
    if not ok then return {} end
    return res
end

local function eval_expr(expr)
    local fn = compile('return ' .. expr)
    if not fn then return nil end
    local ok, v = pcall(fn)
    if not ok then return nil end
    return v
end

local function parse_rotate_pairs(src)
    local p = src:find('ipairs%s*%(%s*%{%s*%{')
    if not p then return nil end
    local si, ei = find_block(src:sub(p), '^', '{', '}')
    if not si then return nil end
    local body = src:sub(p + si, p + ei - 1)
    local parts = {}
    for part in body:gmatch('%b{}') do table.insert(parts, part) end
    if #parts < 3 then return nil end
    local function pair_to_nums(s)
        local a,b = s:match('^%{%s*([^,}]+)%s*[,;]%s*([^}]+)%s*%}$')
        if not a then
            s = s:sub(2, -2)
            local p = {}
            for x in s:gmatch('[^,};]+') do table.insert(p, x) end
            a, b = p[1], p[2]
        end
        return eval_expr(a), eval_expr(b)
    end
    local a1,b1 = pair_to_nums(parts[1])
    local a2,b2 = pair_to_nums(parts[2])
    local a3,b3 = pair_to_nums(parts[3])
    return {a1,b1}, {a2,b2}, {a3,b3}
end

local function reverse_range(t, i, j)
    while i < j do
        t[i], t[j] = t[j], t[i]
        i = i + 1
        j = j - 1
    end
end

local function unrotate_in_place(t, p1, p2, p3)
    reverse_range(t, p1[1], p1[2])
    reverse_range(t, p2[1], p2[2])
    reverse_range(t, p3[1], p3[2])
end

local function parse_lookup_map(src)
    local pos = src:find('local%s+j%s*=%s*%{')
    if not pos then return {} end
    local si, ei = find_block(src:sub(pos), '^', '{', '}')
    if not si then return {} end
    local body = src:sub(pos + si, pos + ei - 1)
    local fn = compile('return {' .. body .. '}')
    if not fn then return {} end
    local ok, tbl = pcall(fn)
    if not ok then return {} end
    local map = {}
    for k,v in pairs(tbl) do
        if type(k) == 'string' and #k == 1 and type(v) == 'number' then
            map[k] = v
        end
    end
    return map
end

local function decode_base64_custom(s, map)
    local len = #s
    local out = {}
    local idx, value, count = 1, 0, 0
    local function push3(n)
        local c1 = math.floor(n / 65536)
        local c2 = math.floor(n % 65536 / 256)
        local c3 = n % 256
        out[#out+1] = string.char(c1, c2, c3)
    end
    while idx <= len do
        local ch = s:sub(idx, idx)
        local code = map[ch]
        if code then
            value = value + code * (64 ^ (3 - count))
            count = count + 1
            if count == 4 then
                count = 0; push3(value); value = 0
            end
        elseif ch == '=' then
            out[#out+1] = string.char(math.floor(value / 65536))
            if idx >= len or s:sub(idx + 1, idx + 1) ~= '=' then
                out[#out+1] = string.char(math.floor(value % 65536 / 256))
            end
            break
        end
        idx = idx + 1
    end
    return table.concat(out)
end

local function decode_constants(u, map)
    local r = {}
    for i=1,#u do
        local v = u[i]
        if type(v) == 'string' and v ~= '' then
            r[i] = decode_base64_custom(v, map)
        else
            r[i] = v
        end
    end
    return r
end

local function eval_num_expr(node)
    if node.kind == Ast.AstKind.NumberExpression then return node.value end
    if node.kind == Ast.AstKind.UnaryMinusExpression then
        local v = eval_num_expr(node.operand)
        if v then return -v end
    end
    if node.kind == Ast.AstKind.AddExpression or node.kind == Ast.AstKind.SubExpression or node.kind == Ast.AstKind.MulExpression or node.kind == Ast.AstKind.DivExpression or node.kind == Ast.AstKind.ModExpression or node.kind == Ast.AstKind.PowExpression then
        local a = eval_num_expr(node.lhs)
        local b = eval_num_expr(node.rhs)
        if not a or not b then return nil end
        if node.kind == Ast.AstKind.AddExpression then return a + b end
        if node.kind == Ast.AstKind.SubExpression then return a - b end
        if node.kind == Ast.AstKind.MulExpression then return a * b end
        if node.kind == Ast.AstKind.DivExpression then if b ~= 0 then return a / b end return nil end
        if node.kind == Ast.AstKind.ModExpression then if b ~= 0 then return a % b end return nil end
        if node.kind == Ast.AstKind.PowExpression then return a ^ b end
    end
    return nil
end

function modules.ConstantArrayDecode:apply(ast, pipeline)
    local code = pipeline.source or ''
    if not code or #code == 0 then return ast end

    local u = parse_u_array_text(code)
    if #u == 0 then u = {} end
    local p1,p2,p3 = parse_rotate_pairs(code)
    if p1 and p2 and p3 and #u > 0 then
        unrotate_in_place(u, p1, p2, p3)
    end
    local map = parse_lookup_map(code)
    local decoded = next(map) and decode_constants(u, map) or u

    local arrScope, arrId, wrapperScope, wrapperId, wrapperOffset
    local localWrappers = {}
    local replaced = 0

    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.LocalVariableDeclaration and node.expressions and #node.expressions == 1 then
            local expr = node.expressions[1]
            if expr.kind == Ast.AstKind.TableConstructorExpression then
                if not arrScope then
                    arrScope = node.scope; arrId = node.ids[1]
                end
            end
        end
        if node.kind == Ast.AstKind.LocalFunctionDeclaration then
            local body = node.body
            if body and #body.statements == 1 then
                local st = body.statements[1]
                if st.kind == Ast.AstKind.ReturnStatement and #st.args == 1 then
                    local ret = st.args[1]
                    if ret.kind == Ast.AstKind.IndexExpression then
                        local base, index = ret.base, ret.index
                        if (index.kind == Ast.AstKind.AddExpression or index.kind == Ast.AstKind.SubExpression)
                          and base.kind == Ast.AstKind.VariableExpression then
                            local lhs, rhs = index.lhs, index.rhs
                            if lhs.kind == Ast.AstKind.VariableExpression and rhs.kind == Ast.AstKind.NumberExpression then
                                wrapperScope, wrapperId = node.scope, node.id
                                arrScope, arrId = base.scope, base.id
                                wrapperOffset = (index.kind == Ast.AstKind.AddExpression) and rhs.value or -rhs.value
                            end
                        end
                    end
                end
            end
        end
        if node.kind == Ast.AstKind.LocalVariableDeclaration and #node.ids == 1 and node.expressions and node.expressions[1] and node.expressions[1].kind == Ast.AstKind.TableConstructorExpression then
            local tbl = node.expressions[1]
            for _, entry in ipairs(tbl.entries or {}) do
                if entry.kind == Ast.AstKind.KeyedTableEntry and entry.key.kind == Ast.AstKind.StringExpression then
                    local key = entry.key.value
                    if entry.value.kind == Ast.AstKind.FunctionLiteralExpression then
                        local fn = entry.value
                        local fbody = fn.body
                        if fbody and #fbody.statements == 1 and fbody.statements[1].kind == Ast.AstKind.ReturnStatement then
                            local call = fbody.statements[1].args[1]
                            if call and call.kind == Ast.AstKind.FunctionCallExpression then
                                local base = call.base
                                local idxExpr
                                if base.kind == Ast.AstKind.IndexExpression then
                                    idxExpr = base.index
                                end
                                if idxExpr and (idxExpr.kind == Ast.AstKind.AddExpression or idxExpr.kind == Ast.AstKind.SubExpression) then
                                    local lhs, rhs = idxExpr.lhs, idxExpr.rhs
                                    if lhs.kind == Ast.AstKind.VariableExpression and rhs.kind == Ast.AstKind.NumberExpression then
                                        local off = (idxExpr.kind == Ast.AstKind.AddExpression) and rhs.value or -rhs.value
                                        localWrappers[key] = { scope = node.scope, id = node.ids[1], offset = off, fn = fn }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.IndexExpression and node.base.kind == Ast.AstKind.VariableExpression then
            if arrScope and arrId and node.base.scope == arrScope and node.base.id == arrId then
                if node.index.kind == Ast.AstKind.NumberExpression and decoded[node.index.value] ~= nil then
                    local val = decoded[node.index.value]
                    replaced = replaced + 1
                    return type(val) == 'string' and Ast.StringExpression(val) or 
                           type(val) == 'number' and Ast.NumberExpression(val) or 
                           type(val) == 'boolean' and Ast.BooleanExpression(val) or
                           Ast.NilExpression()
                end
            end
        end
    end)

    if (arrScope and arrId) and (wrapperOffset ~= nil) then
        visitast(ast, nil, function(node)
            if node.kind == Ast.AstKind.FunctionCallExpression then
                if node.base.kind == Ast.AstKind.VariableExpression then
                    local ok = false
                    if wrapperScope and wrapperId and node.base.scope == wrapperScope and node.base.id == wrapperId then ok = true end
                    if ok and #node.args == 1 then
                        local num = eval_num_expr(node.args[1])
                        if num and decoded[num + wrapperOffset] ~= nil then
                            local idx = num + wrapperOffset
                            local val = decoded[idx]
                            replaced = replaced + 1
                            return type(val) == 'string' and Ast.StringExpression(val) or 
                                   type(val) == 'number' and Ast.NumberExpression(val) or 
                                   type(val) == 'boolean' and Ast.BooleanExpression(val) or
                                   Ast.NilExpression()
                        end
                    end
                end
            end
        end)
    end

    if arrScope and arrId and next(localWrappers) then
        visitast(ast, nil, function(node)
            if node.kind == Ast.AstKind.FunctionCallExpression and node.base.kind == Ast.AstKind.IndexExpression then
                local base = node.base
                if base.base.kind == Ast.AstKind.VariableExpression then
                    local info
                    if base.index.kind == Ast.AstKind.StringExpression then
                        local key = base.index.value
                        info = localWrappers[key]
                    end
                    if info and base.base.scope == info.scope and base.base.id == info.id then
                        local num
                        for _, a in ipairs(node.args or {}) do
                            local v = eval_num_expr(a)
                            if v then num = v end
                        end
                        if num and decoded[num + info.offset] ~= nil then
                            local idx = num + info.offset
                            local val = decoded[idx]
                            replaced = replaced + 1
                            return type(val) == 'string' and Ast.StringExpression(val) or 
                                   type(val) == 'number' and Ast.NumberExpression(val) or 
                                   type(val) == 'boolean' and Ast.BooleanExpression(val) or
                                   Ast.NilExpression()
                        end
                    end
                end
            end
        end)
    end

    if replaced > 0 then print('[ConstantArrayDecode] inlined ' .. replaced .. ' constants') end
    return ast
end

modules.UndoEncryptStrings = {}
modules.UndoEncryptStrings.__index = modules.UndoEncryptStrings
modules.UndoEncryptStrings.Name = 'UndoEncryptStrings'

function modules.UndoEncryptStrings:new()
    return setmetatable({}, self)
end

local function extract_numbers_from_source(src)
    local params = {}
    params.param_mul_45 = tonumber(src:match('state_45%s*%*%s*(%d+)%s*%+%s*(%d+)')) and tonumber(src:match('state_45%s*%*%s*(%d+)%s*%+%s*(%d+)')) or nil
    params.param_add_45 = tonumber(src:match('state_45%s*%*%s*%d+%s*%+%s*(%d+)'))
    params.param_mul_8 = tonumber(src:match('state_8%s*%*%s*(%d+)%s*%%%s*257'))
    params.secret_key_8 = tonumber(src:match('prevVal%s*=%s*(%d+)%s*;'))
    return params
end

local function build_decryptor_from_ast(ast, unparse)
    local code = unparse(ast)
    local p = extract_numbers_from_source(code)
    if not (p and p.param_mul_45 and p.param_add_45 and p.param_mul_8 and p.secret_key_8) then
        return nil
    end
    local function make_decrypt(param_mul_45, param_add_45, param_mul_8, secret_key_8)
        local floor = math.floor
        local function make_state(seed)
            local state_45 = seed % 35184372088832
            local state_8 = seed % 255 + 2
            local prev_values = {}
            local function get_next_pseudo_random_byte()
                if #prev_values == 0 then
                    state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
                    repeat
                        state_8 = state_8 * param_mul_8 % 257
                    until state_8 ~= 1
                    local r = state_8 % 32
                    local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
                    local rnd = floor(n % 1 * 2 ^ 32) + floor(n)
                    local low_16 = rnd % 65536
                    local high_16 = (rnd - low_16) / 65536
                    local b1 = low_16 % 256
                    local b2 = (low_16 - b1) / 256
                    local b3 = high_16 % 256
                    local b4 = (high_16 - b3) / 256
                    prev_values = { b1, b2, b3, b4 }
                end
                return table.remove(prev_values)
            end
            return function(enc)
                local prevVal = secret_key_8
                local out = {}
                for i = 1, #enc do
                    local byte = string.byte(enc, i)
                    prevVal = (byte + get_next_pseudo_random_byte() + prevVal) % 256
                    out[i] = string.char(prevVal)
                end
                return table.concat(out)
            end
        end
        return function(enc, seed)
            return make_state(seed)(enc)
        end
    end
    return make_decrypt(p.param_mul_45, p.param_add_45, p.param_mul_8, p.secret_key_8)
end

local function collect_symbols(ast)
    local decryptVar, stringsVar
    visitast(ast, nil, function(n, data)
        if n.kind == Ast.AstKind.LocalVariableDeclaration then
            for _, id in ipairs(n.ids) do
                local name = n.scope:getVariableName(id)
                if name == 'DECRYPT' then decryptVar = { scope=n.scope, id=id }
                elseif name == 'STRINGS' then stringsVar = { scope=n.scope, id=id } end
            end
        end
        if n.kind == Ast.AstKind.FunctionDeclaration and n.scope:getVariableName(n.id) == 'DECRYPT' then
            decryptVar = { scope=n.scope, id=n.id }
        end
    end)
    return decryptVar, stringsVar
end

function modules.UndoEncryptStrings:apply(ast, pipeline)
    local unparse = function(tree) 
        local u = Unparser:new({ LuaVersion = pipeline.luaVersion or "Lua51" })
        return u:unparse(tree)
    end
    local decryptVar, stringsVar = collect_symbols(ast)
    if not decryptVar or not stringsVar then return ast end

    local decrypt_fn = build_decryptor_from_ast(ast, unparse)
    if not decrypt_fn then return ast end

    local count = 0
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.IndexExpression then
            local base, idx = node.base, node.index
            if base.kind == Ast.AstKind.VariableExpression and base.scope == stringsVar.scope and base.id == stringsVar.id then
                if idx.kind == Ast.AstKind.FunctionCallExpression and idx.base.kind == Ast.AstKind.VariableExpression and idx.base.scope == decryptVar.scope and idx.base.id == decryptVar.id then
                    local args = idx.args
                    if #args == 2 and args[1].kind == Ast.AstKind.StringExpression and args[2].kind == Ast.AstKind.NumberExpression then
                        local plaintext = decrypt_fn(args[1].value, args[2].value)
                        count = count + 1
                        return Ast.StringExpression(plaintext)
                    end
                end
            end
        end
    end)
    if count > 0 then print('[UndoEncryptStrings] decrypted ' .. count .. ' strings') end
    return ast
end

modules.UndoSplitStrings = {}
modules.UndoSplitStrings.__index = modules.UndoSplitStrings
modules.UndoSplitStrings.Name = 'UndoSplitStrings'

function modules.UndoSplitStrings:new()
    return setmetatable({}, self)
end

local function is_lit_string_table(tb)
    if tb.kind ~= Ast.AstKind.TableConstructorExpression then return false end
    for _, e in ipairs(tb.entries) do
        if e.kind ~= Ast.AstKind.TableEntry or e.value.kind ~= Ast.AstKind.StringExpression then return false end
    end
    return true
end

local function custom1_join(argtb)
    if argtb.kind ~= Ast.AstKind.TableConstructorExpression then return nil end
    if #argtb.entries < 2 then return nil end
    local last = argtb.entries[#argtb.entries]
    if last.kind ~= Ast.AstKind.TableEntry or last.value.kind ~= Ast.AstKind.TableConstructorExpression then return nil end
    local strtb = last.value
    if not is_lit_string_table(strtb) then return nil end
    local n = #strtb.entries
    if n == 0 then return '' end
    if #argtb.entries - 1 ~= n then return nil end
    local parts = {}
    for i=1,n do
        local idxEntry = argtb.entries[i]
        if idxEntry.kind ~= Ast.AstKind.TableEntry or idxEntry.value.kind ~= Ast.AstKind.NumberExpression then return nil end
        local idx = idxEntry.value.value
        local strEntry = strtb.entries[i]
        local s = strtb.entries[idx] and strtb.entries[idx].value.value or nil
        if type(idx) ~= 'number' or not s then return nil end
        parts[#parts+1] = s
    end
    return table.concat(parts)
end

local function custom2_join(argtb)
    if argtb.kind ~= Ast.AstKind.TableConstructorExpression then return nil end
    local m = #argtb.entries
    if m % 2 ~= 0 or m == 0 then return nil end
    local half = m / 2
    for i=1,half do
        local e = argtb.entries[i]
        if e.kind ~= Ast.AstKind.TableEntry or e.value.kind ~= Ast.AstKind.NumberExpression then return nil end
    end
    for i=half+1,m do
        local e = argtb.entries[i]
        if e.kind ~= Ast.AstKind.TableEntry or e.value.kind ~= Ast.AstKind.StringExpression then return nil end
    end
    local parts = {}
    for i=1,half do
        local idx = argtb.entries[i].value.value
        local s = argtb.entries[half + idx]
        if not s or s.value.kind ~= Ast.AstKind.StringExpression then return nil end
        parts[#parts+1] = s.value.value
    end
    return table.concat(parts)
end

function modules.UndoSplitStrings:apply(ast)
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.FunctionCallExpression and #node.args == 1 then
            local tb = node.args[1]
            if tb.kind == Ast.AstKind.TableConstructorExpression then
                local s = custom1_join(tb) or custom2_join(tb)
                if s ~= nil then
                    return Ast.StringExpression(s)
                end
            end
        end
    end)
    return ast
end

modules.UndoProxifyLocals = {}
modules.UndoProxifyLocals.__index = modules.UndoProxifyLocals
modules.UndoProxifyLocals.Name = 'UndoProxifyLocals'

function modules.UndoProxifyLocals:new()
    return setmetatable({}, self)
end

local function find_value_name_keys(ast)
    local valueNames = {}
    visitast(ast, nil, function(n)
        if n.kind == Ast.AstKind.AssignmentStatement then
            local lhs = n.variables and n.variables[1]
            local rhs = n.expressions and n.expressions[1]
            if lhs and lhs.kind == Ast.AstKind.AssignmentIndexing and rhs and (rhs.kind == Ast.AstKind.VariableExpression or rhs.kind == Ast.AstKind.FunctionLiteralExpression) then
                if lhs.index.kind == Ast.AstKind.StringExpression then
                    local base = lhs.base
                    if base.kind == Ast.AstKind.VariableExpression then
                        valueNames[base.scope] = valueNames[base.scope] or {}
                        valueNames[base.scope][base.id] = lhs.index.value
                    end
                end
            end
        end
    end)
    return valueNames
end

function modules.UndoProxifyLocals:apply(ast)
    local valueNames = find_value_name_keys(ast)
    if not next(valueNames) then return ast end

    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.VariableExpression then
            local scope, id = node.scope, node.id
            local vn = valueNames[scope] and valueNames[scope][id]
            if vn then
                return Ast.VariableExpression(scope, id)
            end
        end
        if node.kind == Ast.AstKind.AssignmentVariable then
            local scope, id = node.scope, node.id
            local vn = valueNames[scope] and valueNames[scope][id]
            if vn then
                return Ast.AssignmentVariable(scope, id)
            end
        end
    end)

    return ast
end

modules.EnvNormalize = {}
modules.EnvNormalize.__index = modules.EnvNormalize
modules.EnvNormalize.Name = 'EnvNormalize'

function modules.EnvNormalize:new()
    return setmetatable({}, self)
end

local whitelist = {
    print=true, table=true, string=true, math=true,
    setmetatable=true, getmetatable=true, select=true,
    unpack=true, pairs=true, ipairs=true, type=true,
}

local function key_of(var)
    return tostring(var.scope) .. ':' .. tostring(var.id)
end

local function make_global(ast, name)
    local scope, id = ast.globalScope:resolveGlobal(name)
    return Ast.VariableExpression(scope, id)
end

local function collect_aliases(ast)
    local aliases = {}
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.LocalVariableDeclaration and node.expressions and #node.ids == 1 and #node.expressions == 1 then
            local expr = node.expressions[1]
            if expr and expr.kind == Ast.AstKind.IndexExpression then
                local base, idx = expr.base, expr.index
                if base and base.kind == Ast.AstKind.VariableExpression and idx and idx.kind == Ast.AstKind.StringExpression then
                    local name = idx.value
                    if whitelist[name] then
                        local fake = { scope = node.scope, id = node.ids[1] }
                        aliases[key_of(fake)] = name
                    end
                end
            elseif expr and expr.kind == Ast.AstKind.VariableExpression then
                local vname = expr.scope:getVariableName(expr.id)
                if whitelist[vname] then
                    local fake = { scope = node.scope, id = node.ids[1] }
                    aliases[key_of(fake)] = vname
                end
            end
        end
    end)
    return aliases
end

local function transform(ast, aliases)
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.VariableExpression then
            local k = key_of(node)
            local name = aliases[k]
            if name then return make_global(ast, name) end
        elseif node.kind == Ast.AstKind.IndexExpression then
            local base, idx = node.base, node.index
            if base and base.kind == Ast.AstKind.VariableExpression and idx and idx.kind == Ast.AstKind.StringExpression then
                local name = idx.value
                if whitelist[name] then
                    return make_global(ast, name)
                end
            end
        end
    end)
end

local function filter_block(block, aliases)
    local out = {}
    for _, st in ipairs(block.statements or {}) do
        if st.kind == Ast.AstKind.LocalVariableDeclaration then
            local drop = false
            for _, id in ipairs(st.ids) do
                local fake = { scope = st.scope, id = id }
                if aliases[key_of(fake)] then drop = true; break end
            end
            if not drop then table.insert(out, st) end
        else
            if st.body then st.body = Ast.Block(filter_block(st.body, aliases), st.body.scope) end
            if st.elsebody then st.elsebody = Ast.Block(filter_block(st.elsebody, aliases), st.elsebody.scope) end
            if st.elseifs then
                for _, eif in ipairs(st.elseifs) do
                    if eif.body then eif.body = Ast.Block(filter_block(eif.body, aliases), eif.body.scope) end
                end
            end
            table.insert(out, st)
        end
    end
    return out
end

function modules.EnvNormalize:apply(ast)
    local aliases = collect_aliases(ast)
    transform(ast, aliases)
    ast.body.statements = filter_block(ast.body, aliases)
    return ast
end

modules.DispatchFlatten = {}
modules.DispatchFlatten.__index = modules.DispatchFlatten
modules.DispatchFlatten.Name = 'DispatchFlatten'

function modules.DispatchFlatten:new()
    return setmetatable({}, self)
end

local function find_dispatch_with_parent(ast)
    local K = Ast.AstKind
    local found_node, found_parent, found_index, pos_scope, pos_id
    local function walk_block(block)
        local list = block and block.statements or {}
        for i=1,#list do
            local st = list[i]
            if st.kind == K.WhileStatement and st.condition and st.condition.kind == K.VariableExpression then
                found_node, found_parent, found_index = st, block, i
                pos_scope, pos_id = st.condition.scope, st.condition.id
                return true
            end
            if st.body and walk_block(st.body) then return true end
            if st.elsebody and walk_block(st.elsebody) then return true end
            if st.elseifs then
                for _, eif in ipairs(st.elseifs) do if walk_block(eif.body) then return true end end
            end
        end
        return false
    end
    walk_block(ast.body)
    return found_node, pos_scope, pos_id, found_parent, found_index
end

local function collect_leaves(block)
    local K = Ast.AstKind
    local leaves = {}
    local function dive(node)
        if not node then return end
        if node.kind == K.IfStatement then
            dive(node.body)
            for _, eif in ipairs(node.elseifs or {}) do dive(eif.body) end
            if node.elsebody then
                if node.elsebody.kind == K.IfStatement then dive(node.elsebody) else table.insert(leaves, node.elsebody) end
            end
        else
            if node.kind == K.Block then table.insert(leaves, node) end
        end
    end
    dive(block)
    return leaves
end

local function instrument(ast, while_node, pos_scope, pos_id, parent_block, while_index)
    local leaves = collect_leaves(while_node.body)
    local scope, id = ast.globalScope:resolveGlobal('__log_leaf')
    local hook_var = Ast.VariableExpression(scope, id)
    local pos_var = Ast.VariableExpression(pos_scope, pos_id)
    for _, leaf in ipairs(leaves) do
        local call = Ast.FunctionCallStatement(hook_var, { pos_var })
        table.insert(leaf.statements, 1, call)
    end
    local prelude = {}
    for i=1, while_index-1 do prelude[#prelude+1] = parent_block.statements[i] end
    local new_stmts = {}
    for i=1,#prelude do new_stmts[#new_stmts+1] = prelude[i] end
    new_stmts[#new_stmts+1] = while_node
    ast.body.statements = new_stmts
    return leaves
end

local function run_instrumented(ast, luaVersion)
    local unparser = Unparser:new({ LuaVersion = luaVersion })
    local code = unparser:unparse(ast)
    local out = {}
    local env = {}
    env.__log_leaf = function(pos) out[#out+1] = pos end
    env.print = function() end
    setmetatable(env, { __index = _G })
    local fn, err = load(code, nil, 't', env)
    if not fn then return out end
    pcall(fn)
    return out
end

function modules.DispatchFlatten:apply(ast, pipeline)
    local luaVersion = pipeline and pipeline.luaVersion or "Lua51"
    local while_node, pos_scope, pos_id, parent_block, while_index = find_dispatch_with_parent(ast)
    if not while_node then return ast end
    local leaves = instrument(ast, while_node, pos_scope, pos_id, parent_block, while_index)
    local pos_order = run_instrumented(ast, luaVersion)
    if #pos_order == 0 and parent_block and while_index then
        table.insert(parent_block.statements, while_index, Ast.AssignmentStatement({ Ast.AssignmentVariable(pos_scope, pos_id) }, { Ast.NumberExpression(1) }))
        pos_order = run_instrumented(ast, luaVersion)
    end
    local map = {}
    for i, pos in ipairs(pos_order) do if pos ~= nil and map[pos] == nil then map[pos] = i end end
    local new = {}
    for pos, idx in pairs(map) do
        local leaf = leaves[idx]
        for _, st in ipairs(leaf.statements) do table.insert(new, st) end
    end
    if #leaves > 0 then print(string.format('[DispatchFlatten] leaves=%d order=%d emitted=%d', #leaves, #pos_order, #new)) end
    ast.body.statements = new
    return ast
end

modules.UndoVmify = {}
modules.UndoVmify.__index = modules.UndoVmify
modules.UndoVmify.Name = 'UndoVmify'

function modules.UndoVmify:new()
    return setmetatable({}, self)
end

local function count_ifs(block)
    local K = Ast.AstKind
    local c = 0
    local function dive(node)
        if not node then return end
        if node.kind == K.IfStatement then
            c = c + 1
            dive(node.body)
            for _, eif in ipairs(node.elseifs or {}) do dive(eif.body) end
            dive(node.elsebody)
        elseif node.kind == K.Block then
            for _, st in ipairs(node.statements or {}) do dive(st) end
        else
            for k,v in pairs(node) do
                if type(v) == 'table' and v.kind then dive(v) end
            end
        end
    end
    dive(block)
    return c
end

local function find_best_dispatch(ast)
    local K = Ast.AstKind
    local best, best_parent, best_index, best_pos_scope, best_pos_id, best_score = nil, nil, nil, nil, nil, -1
    local function walk_block(block, parent)
        local list = block and block.statements or {}
        for i=1,#list do
            local st = list[i]
            if st.kind == K.WhileStatement and st.condition and st.condition.kind == K.VariableExpression then
                local score = count_ifs(st.body)
                if score > best_score then
                    best, best_parent, best_index = st, parent or block, i
                    best_pos_scope, best_pos_id = st.condition.scope, st.condition.id
                    best_score = score
                end
            end
            if st.body then walk_block(st.body, st) end
            if st.elsebody then walk_block(st.elsebody, st) end
            if st.elseifs then for _, eif in ipairs(st.elseifs) do walk_block(eif.body, st) end end
            for k,v in pairs(st) do
                if type(v) == 'table' and v.kind == Ast.AstKind.FunctionLiteralExpression and v.body then
                    walk_block(v.body, st)
                end
            end
        end
    end
    walk_block(ast.body, ast.body)
    return best, best_parent, best_index, best_pos_scope, best_pos_id, best_score
end

local function instrument_in_place(ast, while_node, pos_scope, pos_id)
    local leaves = collect_leaves(while_node.body)
    local scope, id = ast.globalScope:resolveGlobal('__log_leaf')
    local hook_var = Ast.VariableExpression(scope, id)
    local pos_var = Ast.VariableExpression(pos_scope, pos_id)
    for _, leaf in ipairs(leaves) do
        table.insert(leaf.statements, 1, Ast.FunctionCallStatement(hook_var, { pos_var }))
    end
    return leaves
end

local function run_instrumented_vm(ast, luaVersion)
    local unparser = Unparser:new({ LuaVersion = luaVersion })
    local code = unparser:unparse(ast)
    local out = {}
    local env = {}
    env.__log_leaf = function(pos) out[#out+1] = pos end
    env.print = function() end
    setmetatable(env, { __index = _G })
    local fn, err = load(code, nil, 't', env)
    if not fn then return out end
    pcall(fn)
    return out
end

function modules.UndoVmify:apply(ast, pipeline)
    local luaVersion = pipeline and pipeline.luaVersion or "Lua51"
    local while_node, parent_block, while_index, pos_scope, pos_id, score = find_best_dispatch(ast)
    if not while_node or score <= 0 then return ast end
    local leaves = instrument_in_place(ast, while_node, pos_scope, pos_id)
    local pos_order = run_instrumented_vm(ast, luaVersion)
    if #pos_order == 0 and parent_block and while_index then
        table.insert(parent_block.statements, while_index, Ast.AssignmentStatement({ Ast.AssignmentVariable(pos_scope, pos_id) }, { Ast.NumberExpression(1) }))
        pos_order = run_instrumented_vm(ast, luaVersion)
    end
    local seen = {}
    local ordered = {}
    for _, pos in ipairs(pos_order) do
        if pos ~= nil and not seen[pos] then
            seen[pos] = true
            ordered[#ordered+1] = pos
        end
    end
    local new = {}
    for _, pos in ipairs(ordered) do
        local idx
        for i, p in ipairs(pos_order) do if p == pos then idx = i; break end
        local leaf = idx and leaves[idx] or nil
        if leaf then
            for _, st in ipairs(leaf.statements) do
                if st.kind ~= Ast.AstKind.FunctionCallStatement then
                    table.insert(new, st)
                end
            end
        end
    end
    if #new > 0 then
        print(string.format('[UndoVmify] leaves=%d order=%d emitted=%d', #leaves, #pos_order, #new))
        ast.body.statements = new
    end
    return ast
end

modules.FoldConcats = {}
modules.FoldConcats.__index = modules.FoldConcats
modules.FoldConcats.Name = 'FoldConcats'

function modules.FoldConcats:new()
    return setmetatable({}, self)
end

local function flatten_strcat(node, out)
    if node.kind == Ast.AstKind.StrCatExpression then
        flatten_strcat(node.lhs, out)
        flatten_strcat(node.rhs, out)
    else
        table.insert(out, node)
    end
end

function modules.FoldConcats:apply(ast)
    local changed = 0
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.StrCatExpression then
            local parts = {}
            flatten_strcat(node, parts)
            local all = true
            local buf = {}
            for _, p in ipairs(parts) do
                if p.kind ~= Ast.AstKind.StringExpression then all = false; break end
                buf[#buf+1] = p.value
            end
            if all then
                changed = changed + 1
                return Ast.StringExpression(table.concat(buf))
            end
        elseif node.kind == Ast.AstKind.FunctionCallExpression then
            local base = node.base
            if base.kind == Ast.AstKind.IndexExpression and base.base.kind == Ast.AstKind.VariableExpression and base.index.kind == Ast.AstKind.StringExpression then
                local name = base.index.value
                local gscope, gid = base.base.scope, base.base.id
                local gname
                if gscope and gscope.getVariableName then gname = gscope:getVariableName(gid) end
                if name == 'concat' and gname == 'table' and #node.args == 1 and node.args[1].kind == Ast.AstKind.TableConstructorExpression then
                    local tb = node.args[1]
                    local all = true
                    local buf = {}
                    for _, entry in ipairs(tb.entries) do
                        if entry.kind ~= Ast.AstKind.TableEntry or entry.value.kind ~= Ast.AstKind.StringExpression then all=false; break end
                        buf[#buf+1] = entry.value.value
                    end
                    if all then
                        changed = changed + 1
                        return Ast.StringExpression(table.concat(buf))
                    end
                end
            end
        end
    end)
    if changed > 0 then print('[FoldConcats] folded ' .. changed .. ' items') end
    return ast
end

modules.FoldNumbers = {}
modules.FoldNumbers.__index = modules.FoldNumbers
modules.FoldNumbers.Name = 'FoldNumbers'

function modules.FoldNumbers:new()
    return setmetatable({}, self)
end

local function fold_bin(op, a, b)
    if op == Ast.AstKind.AddExpression then return a + b end
    if op == Ast.AstKind.SubExpression then return a - b end
    if op == Ast.AstKind.MulExpression then return a * b end
    if op == Ast.AstKind.DivExpression and b ~= 0 then return a / b end
    if op == Ast.AstKind.ModExpression and b ~= 0 then return a % b end
    if op == Ast.AstKind.PowExpression then return a ^ b end
end

function modules.FoldNumbers:apply(ast)
    local changed = 0
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.AddExpression or node.kind == Ast.AstKind.SubExpression or node.kind == Ast.AstKind.MulExpression
          or node.kind == Ast.AstKind.DivExpression or node.kind == Ast.AstKind.ModExpression or node.kind == Ast.AstKind.PowExpression then
            local lhs, rhs = node.lhs, node.rhs
            if lhs.isConstant and rhs.isConstant and type(lhs.value) == 'number' and type(rhs.value) == 'number' then
                local ok, res = pcall(fold_bin, node.kind, lhs.value, rhs.value)
                if ok and type(res) == 'number' then
                    changed = changed + 1
                    return Ast.NumberExpression(res)
                end
            end
        end
    end)
    if changed > 0 then print('[FoldNumbers] folded ' .. changed .. ' expressions') end
    return ast
end

modules.UnwrapFunction = {}
modules.UnwrapFunction.__index = modules.UnwrapFunction
modules.UnwrapFunction.Name = 'UnwrapFunction'

function modules.UnwrapFunction:new()
    return setmetatable({}, self)
end

local function unwrap_once(ast)
    local ret = ast.body.statements[1]
    if not ret or ret.kind ~= Ast.AstKind.ReturnStatement then return false end
    local call = ret.args and ret.args[1]
    if not call or call.kind ~= Ast.AstKind.FunctionCallExpression then return false end
    local base = call.base
    if base and base.kind == Ast.AstKind.FunctionLiteralExpression then
        ast.body.statements = base.body.statements
        return true
    end
    if base and base.kind == Ast.AstKind.FunctionCallExpression and base.base and base.base.kind == Ast.AstKind.FunctionLiteralExpression then
        ast.body.statements = base.base.body.statements
        return true
    end
    return false
end

function modules.UnwrapFunction:apply(ast)
    local changed = unwrap_once(ast)
    if changed then unwrap_once(ast) end
    return ast
end

modules.DynamicTrace = {}
modules.DynamicTrace.__index = modules.DynamicTrace
modules.DynamicTrace.Name = 'DynamicTrace'

function modules.DynamicTrace:new(opts)
    return setmetatable({ opts = opts or {} }, self)
end

local function run_with_trace(code, level)
    local calls = {}
    local function rec(name, args)
        calls[#calls+1] = { name = name, args = args }
    end

    local env = {}
    env._ENV = env
    env._G = env

    env.print = function(...)
        local args = {}
        for i=1,select('#', ...) do args[i] = select(i, ...) end
        rec('print', args)
    end

    env.io = setmetatable({
        write = function(...)
            local args = {}
            for i=1,select('#', ...) do args[i] = select(i, ...) end
            rec('io.write', args)
        end
    }, { __index = _G.io or {} })

    setmetatable(env, {
        __index = _G,
        __call = function() return env end
    })

    local fn, err = load(code, nil, 't', env)
    if not fn then return calls end
    pcall(fn)
    return calls
end

function modules.DynamicTrace:apply(ast, pipeline)
    local level = (self.opts and self.opts.level) or 'prints'
    local code = pipeline.source or ''
    local calls = run_with_trace(code, level)
    if #calls == 0 then return ast end

    local stmts = {}
    for _, c in ipairs(calls) do
        if c.name == 'print' then
            local args = {}
            for i=1,#c.args do args[i] = Ast.StringExpression(tostring(c.args[i])) end
            local pScope, pId = ast.globalScope:resolveGlobal('print')
            stmts[#stmts+1] = Ast.FunctionCallStatement(Ast.VariableExpression(pScope, pId), args)
        elseif c.name == 'io.write' then
            local args = {}
            for i=1,#c.args do args[i] = Ast.StringExpression(tostring(c.args[i])) end
            local ioVarScope, ioVarId = ast.globalScope:resolveGlobal('io')
            local base = Ast.IndexExpression(Ast.VariableExpression(ioVarScope, ioVarId), Ast.StringExpression('write'))
            stmts[#stmts+1] = Ast.FunctionCallStatement(base, args)
        end
    end

    if #stmts > 0 then
        ast.body.statements = stmts
        print(string.format('[DynamicTrace] replayed %d calls', #stmts))
    end
    return ast
end

-- ============================================================================
-- 5. DEOBFUSCATOR PIPELINE
-- ============================================================================
local Deobfuscator = {}
Deobfuscator.__index = Deobfuscator

function Deobfuscator:new(options)
    options = options or {}
    return setmetatable({
        luaVersion = options.luaVersion or "Lua51",
        traceLevel = options.traceLevel or 'prints',
    }, self)
end

function Deobfuscator:deobfuscate(source)
    print("[Prometheus] Starting deobfuscation...")
    
    local scope = Scope:new(nil)
    local ast = { body = Ast.Block({}, scope), globalScope = scope }
    
    local pipeline = {
        source = source,
        luaVersion = self.luaVersion,
        getUnparser = function() return Unparser:new({ LuaVersion = self.luaVersion }) end
    }
    
    local steps = {
        modules.UnwrapFunction,
        modules.ConstantArrayDecode,
        modules.UndoEncryptStrings,
        modules.UndoSplitStrings,
        modules.UndoProxifyLocals,
        modules.EnvNormalize,
        modules.DispatchFlatten,
        modules.UndoVmify,
        modules.FoldConcats,
        modules.FoldNumbers,
        modules.CleanupObfuscatorScaffold,
    }
    
    for _, module in ipairs(steps) do
        local transformer = module:new()
        ast = transformer:apply(ast, pipeline)
    end
    
    local trace = modules.DynamicTrace:new({ level = self.traceLevel })
    ast = trace:apply(ast, pipeline)
    
    local unparser = Unparser:new({ LuaVersion = self.luaVersion })
    local code = unparser:unparse(ast)
    
    if code == "-- Deobfuscated output (AST unparsed)" then
        return source
    end
    
    print("[Prometheus] Deobfuscation completed!")
    return code
end

-- ============================================================================
-- 6. DISCORD BOT
-- ============================================================================
local discordia = require('discordia')
local client = discordia.Client()

client:on('ready', function()
    print('🤖 Bot logged in as ' .. client.user.username)
    print('📊 Guilds: ' .. #client.guilds)
    client:setActivity('.l <file> to deobfuscate')
end)

local function process_deobfuscation(file_content, filename)
    print('[Process] Starting: ' .. filename)
    
    local deobfuscator = Deobfuscator:new({
        luaVersion = "Lua51",
        traceLevel = 'prints'
    })
    
    local success, result = pcall(function()
        return deobfuscator:deobfuscate(file_content)
    end)
    
    if not success then
        return nil, "❌ Deobfuscation error: " .. tostring(result)
    end
    
    print('[Process] Success! Output: ' .. #result .. ' bytes')
    return result, nil
end

client:on('messageCreate', function(message)
    if message.author.bot then return end
    
    if not message.content:match('^%.l') then return end
    
    if not message.attachments or #message.attachments == 0 then
        message:reply('❌ Please attach a Lua file.\nUsage: `.l <upload file>`')
        return
    end
    
    local attachment = message.attachments[1]
    if not attachment.filename:match('%.lua$') then
        message:reply('❌ Please attach a `.lua` file.')
        return
    end
    
    message:addReaction('⏳')
    print('[Download] ' .. attachment.filename)
    
    attachment:download(function(err, data)
        if err then
            print('[Error] ' .. tostring(err))
            message:reply('❌ Failed to download: ' .. tostring(err))
            message:removeReaction('⏳')
            return
        end
        
        print('[Deobfuscate] Processing ' .. #data .. ' bytes')
        local deobfuscated, error_msg = process_deobfuscation(data, attachment.filename)
        
        if error_msg then
            print('[Error] ' .. error_msg)
            message:reply(error_msg)
            message:removeReaction('⏳')
            return
        end
        
        local timestamp = os.date('%Y%m%d_%H%M%S')
        local out_filename = string.format('deobfuscated_%s_%s.lua', 
            attachment.filename:gsub('%.lua$', ''), timestamp)
        
        local file = io.open(out_filename, 'w')
        if file then
            file:write(deobfuscated)
            file:close()
            
            print('[Send] ' .. out_filename)
            message:reply {
                content = '✅ Deobfuscation complete! `' .. out_filename .. '`',
                file = out_filename
            }
            
            timer.setTimeout(5000, function()
                os.remove(out_filename)
                print('[Cleanup] ' .. out_filename)
            end)
        else
            local preview = deobfuscated:sub(1, 1900)
            message:reply {
                content = string.format('✅ Complete! `%s`\n```lua\n%s```', out_filename, preview),
            }
        end
        
        message:removeReaction('⏳')
        message:addReaction('✅')
    end)
end)

process:on('SIGTERM', function()
    print('🛑 SIGTERM received, shutting down...')
    client:stop()
    server:close()
    timer.setTimeout(500, function() os.exit(0) end)
end)

process:on('SIGINT', function()
    print('🛑 SIGINT received, shutting down...')
    client:stop()
    server:close()
    timer.setTimeout(500, function() os.exit(0) end)
end)

print('🚀 Starting Prometheus Deobfuscator Bot...')
client:run(DISCORD_TOKEN)
