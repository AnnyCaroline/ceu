MEMS = {
    exts = {
        types       = '',
        enum_input  = '',
        enum_output = '',
        defines_input_output = '',
    },
    evts = {
        types = '',
        enum  = '',
    },
    codes = {
        mems     = '',
        wrappers = '',
        args     = '',
--[[
        [1] = {
            mem     = '',
            wrapper = '',
            args    = '',
        }
]]
    },
    datas = {
        id    = 1,
        mems  = '',
        hiers = '',
        bases = {},
    },
    opts = {
        -- avoids duplications
        --[TYPES.tostring(tp)] = true,
    },
}

local EVENT_SUFIX_EXISTS = {}

local function CUR ()
    return (AST.iter'Code'() or AST.iter'Data'() or AST.root).mems
end

F = {
    ROOT__PRE = function (me)
        me.mems = { mem='' }
    end,
    ROOT__POS = function (me)
        me.mems.mem = [[
typedef struct tceu_code_mem_ROOT {
    tceu_code_mem mem;
    tceu_trl      trails[]]..me.trails_n..[[];
    ]]..me.mems.mem..[[
} tceu_code_mem_ROOT;
]]..'\n'
        MEMS.codes[#MEMS.codes+1] = me.mems
    end,

    ---------------------------------------------------------------------------

    Code__PRE = function (me)
        me.mems = { me=me, mem='', watch='' }
    end,
    Code__POS = function (me)
        local mods,id = unpack(me)

        if me.is_dyn_base then
            me.dyns = {}
            me.mems.mem = ''
        else
            if not me.is_impl then
                return
            end
            if mods.dynamic then
                local t = me.dyn_base.dyns
                t[#t+1] = me.id
            end

            me.mems.mem = [[
typedef struct tceu_code_mem_]]..me.id..[[ {
    tceu_code_mem mem;
    tceu_trl      trails[]]..me.trails_n..[[];
    ]]..me.mems.mem..[[
} tceu_code_mem_]]..me.id..[[;
]]
        end

        MEMS.codes[#MEMS.codes+1] = me.mems
    end,

    Code = function (me)
        local mods, _, body = unpack(me)

        if (not me.is_dyn_base) and ((not me.is_impl) or mods.dynamic) then
            me.mems.args = ''
            me.mems.wrapper = ''
            return
        end

        -- args
        me.mems.args = 'typedef struct tceu_code_args_'..me.id..' {\n'

        for i,dcl in ipairs(body.dcls) do
            local alias,Type,id2,dim = unpack(dcl)
            if id2 ~= '_ret' then
                id2 = '_'..i
            end

            local ptr = '' do
                if alias then
                    if (dcl.tag ~= 'Evt') and alias=='&' then
                        ptr = ptr..'*'
                    end
                    if dcl.is_mid_idx then
                        ptr = ptr..'*'  -- extra indirection for mid's
                    end
                end
            end

            -- &?
            if (alias == '&?') and (not (dcl.tag=='Var' and TYPES.is_nat(Type))) then
                    me.mems.args = me.mems.args..[[
tceu_opt_alias]]..ptr..' '..id2..[[;
]]

            -- VAR
            elseif dcl.tag == 'Var' then
                if dcl.id~='_ret' or mods.tight then
                    me.mems.args = me.mems.args..[[
]]..TYPES.toc(Type)..ptr..' '..id2..[[;
]]
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                assert(alias)
-- TODO: per Code evts
                me.mems.args = me.mems.args .. [[
tceu_evt]]..ptr..' '..id2..[[;
]]

            -- VEC
            elseif dcl.tag == 'Vec' then
                assert(alias)
                if TYPES.is_nat(TYPES.get(Type,1)) then
                    me.mems.args = me.mems.args .. [[
]]..TYPES.toc(Type)..' ('..ptr..id2..')['..V(dim)..[[];
]]
                else
                    me.mems.args = me.mems.args .. [[
tceu_vector]]..ptr..' '..id2..[[;
]]
                end

            -- POOL
            elseif dcl.tag == 'Pool' then
                assert(alias)
                me.mems.args = me.mems.args .. [[
tceu_pool_pak]]..ptr..' '..id2..[[;
]]

            else
                error'bug found'
            end
        end

        local multis = {}
        if mods.dynamic then
            local Code_Pars = AST.asr(body,'', 1,'Stmts', 1,'Stmts', 1,'Code_Pars')
            for i, dcl in ipairs(Code_Pars) do
                if dcl.mods.dynamic then
                    local _,Type,id = unpack(dcl)
                    local data = AST.asr(Type,'',1,'ID_abs')
                    assert(data.dcl.hier and (not data.dcl.hier.up))
                    me.mems.args = me.mems.args .. [[
tceu_ndata _data_]]..i..[[;     /* force multimethod arg data id */
]]

                    -- arg "i" is dynamic:
                    multis[#multis+1] = {
                        base = data.dcl,    -- datatype for the argument
                        dyn  = dcl.id_dyn,  -- identifier considering the "base" value
                        id   = id,          -- argument identifier
                        i    = i,           -- position in the parameter list
                    }
                end
            end
            assert(#multis > 0)

            local dims, constr = MULTIS.tostring(me, multis);
            multis.code = [[
static tceu_ndata multis]]..dims..[[ = {
]] .. constr .. [[
};
tceu_nlbl lbl = multis
]]
            for _, t in ipairs(multis) do
                multis.code = multis.code..'[ ps._data_'..t.i..' ]'
            end
            multis.code = multis.code..';\n'
        end

        me.mems.args = me.mems.args..'} tceu_code_args_'..me.id..';\n'

        me.mems.wrapper = ''

        -- CEU_CODE_WATCH_xxx
        if me.mems.watch ~= '' then
            me.mems.wrapper = me.mems.wrapper .. [[
static void CEU_CODE_WATCH_]]..me.id..[[ (tceu_code_mem* _ceu_mem,
                                          tceu_code_args_]]..me.id..[[* args)
{
    ]]..me.mems.watch..[[
}
]]
        end

        -- CEU_CODE_xxx

        local Type = AST.get(body,'Block', 1,'Stmts', 1,'Stmts', 3,'', 2,'Type')
        if mods.tight then
            me.mems.wrapper = me.mems.wrapper .. [[
static ]]..TYPES.toc(assert(Type))..[[ /* space */
CEU_CODE_]]..me.id..[[ (tceu_stk* stk, tceu_ntrl trlK,
                        tceu_code_args_]]..me.id..[[ ps,
                        lua_State* lua)
{
    tceu_code_mem_]]..me.id..[[ mem;
    mem.mem.lua = lua;
]]
            if mods.dynamic then
                me.mems.wrapper = me.mems.wrapper .. multis.code
            else
                me.mems.wrapper = me.mems.wrapper .. [[
    tceu_nlbl lbl = ]]..me.lbl_in.id..[[;
]]
            end
            me.mems.wrapper = me.mems.wrapper .. [[
    ceu_lbl((tceu_evt_occ*)&ps, stk, (tceu_code_mem*)&mem, trlK, lbl);
]]
            if Type and (not TYPES.check(Type,'void')) then
                me.mems.wrapper = me.mems.wrapper..[[
    return ps._ret;
]]
        end
            me.mems.wrapper = me.mems.wrapper..[[
}
]]
        else
            me.mems.wrapper = me.mems.wrapper .. [[
static void CEU_CODE_]]..me.id..[[ (tceu_stk* stk, tceu_ntrl trlK,
                                       tceu_code_args_]]..me.id..[[ ps,
                                       tceu_code_mem* mem)
{
]]
            if mods.dynamic then
                me.mems.wrapper = me.mems.wrapper .. multis.code
            else
                me.mems.wrapper = me.mems.wrapper .. [[
    tceu_nlbl lbl = ]]..me.lbl_in.id..[[;
]]
            end
            me.mems.wrapper = me.mems.wrapper .. [[
    tceu_stk __ceu_stk = { 1, stk, {mem,]]..me.trails[1]..','..me.trails[2]..[[} };
    ceu_lbl((tceu_evt_occ*)&ps, &__ceu_stk, mem, trlK, lbl);
    if (!__ceu_stk.is_alive) {
        return; /* skips WATCH below */
    }
]]
            if me.mems.watch ~= '' then
                me.mems.wrapper = me.mems.wrapper .. [[
    CEU_CODE_WATCH_]]..me.id..[[(mem, &ps);
]]
            end
            me.mems.wrapper = me.mems.wrapper .. [[
}
]]
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        local idx = to.info.dcl.is_mid_idx
        if idx then
            local Code = AST.par(me,'Code')
            if to.info.dcl[1] == '&' then
                Code.mems.watch = Code.mems.watch .. [[
if (args->_]]..idx..[[ != NULL) {
    *(args->_]]..idx..[[) = ]]..V(to, {is_bind=true})..[[;
}
]]
            else
                assert(to.info.dcl[1] == '&?')
                Code.mems.watch = Code.mems.watch .. [[
if (args->_]]..idx..[[ != NULL) {
    tceu_trl* trl = (tceu_trl*) args->_]]..idx..[[->range.mem;
    *(args->_]]..idx..[[) = ]]..V(to, {is_bind=true})..[[;

    /* HACK_4 */
    trl->evt.id    = CEU_INPUT__CLEAR;
    trl->clr_range = args->_]]..idx..[[->range;
}
]]
            end
        end
    end,

    ---------------------------------------------------------------------------

    Data__PRE = function (me)
        me.id_ = TYPES.noc(me.id)
        me.mems = {
            mem  = '',
            hier = nil, -- only for base class
        }
    end,
    Data__POS = function (me)
        local _,num = unpack(me)
        local mem = me.mems.mem
        me.mems.mem = [[
typedef struct tceu_data_]]..me.id_..[[ {
]]
        if me.hier or num then
assert(me.hier)
            me.mems.mem = me.mems.mem..[[
    tceu_ndata _enum;
]]
        end
        me.mems.mem = me.mems.mem..[[
    ]]..mem..[[
} tceu_data_]]..me.id_..[[;
]]..'\n'

        MEMS.datas.mems = MEMS.datas.mems..me.mems.mem

        if me.hier and (not me.hier.up) then
            MEMS.datas.bases[#MEMS.datas.bases+1] = me
        end
    end,

    Var = function (me)
        -- new `?´ type
        local alias,tp = unpack(me)
        if not (alias=='&?' or TYPES.check(tp,'?')) then
            return
        end

        local str = TYPES.tostring(tp)
        if not MEMS.opts[str] then
            MEMS.opts[str] = true
            local cc = TYPES.toc(tp)
            local c = TYPES.toc(TYPES.pop(tp,'?'))
            if alias == '&?' then
                MEMS.datas.mems = MEMS.datas.mems..[[
static ]]..cc..'* CEU_OPTION_'..cc..[[ (]]..cc..[[* alias, char* file, int line) {
    ceu_callback_assert_msg_ex(alias != NULL, "value is not set", file, line);
    return alias;
}
]]
            else
                MEMS.datas.mems = MEMS.datas.mems..[[
typedef struct ]]..cc..[[ {
    bool      is_set;
    ]]..c..[[ value;
} ]]..cc..[[;

static ]]..cc..'* CEU_OPTION_'..cc..' ('..cc..[[* opt, char* file, int line) {
    ceu_callback_assert_msg_ex(opt->is_set, "value is not set", file, line);
    return opt;
}
]]
            end
        end
    end,

    ---------------------------------------------------------------------------

    Block__PRE = function (me)
        local mem = {}

        for _, spw in ipairs(me.spawns) do
            local _,Abs_Cons = unpack(spw)
            mem[#mem+1] = 'tceu_code_mem_'..Abs_Cons.id..' __mem_'..spw.n..';\n'
        end

        for _, dcl in ipairs(me.dcls) do
if dcl.tag ~= 'Prim' then
            local alias, Type = unpack(dcl)

            if dcl.ln then
                if CEU.opts.ceu_line_directives then
                    mem[#mem+1] = [[
#line ]]..dcl.ln[2]..' "'..dcl.ln[1]..[["
]]
                end
            end

            if dcl.tag=='Var' or dcl.tag=='Evt' then
                dcl.id_ = dcl.id
                if not AST.par(me,'Data') then
                    dcl.id_ = dcl.id_..'_'..dcl.n
                end
            end

            -- &?
            if (alias == '&?') and (not (dcl.tag=='Var' and TYPES.is_nat(Type))) then
                mem[#mem+1] = 'tceu_opt_alias '..dcl.id_..';\n'
                if dcl.tag == 'Evt' then
                    MEMS.evts[#MEMS.evts+1] = dcl
                end

            -- VAR
            elseif dcl.tag == 'Var' then
                if dcl.id == '_ret' then
                    dcl.id_ = dcl.id
                else
                    local alias, tp = unpack(dcl)
                    if alias then
                        mem[#mem+1] = TYPES.toc(tp)..'* '..dcl.id_..';\n'
                    else
                        mem[#mem+1] = TYPES.toc(tp)..'  '..dcl.id_..';\n'
                    end
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                if alias then
-- TODO: per Code evts
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id
                    mem[#mem+1] = 'tceu_evt '..dcl.id_..';\n'
                else
                    local data = AST.par(me,'Data')
                    if data then
                        -- same name for all class hierarchy
                        if data.hier then
                            data = DCLS.base(data)
                        end
                        dcl.id_ = string.upper('CEU_EVENT'..'_'..data.id..'_'..dcl.id)
                        if data == AST.par(me,'Data') then
                            -- avoids duplication with super
                            MEMS.evts[#MEMS.evts+1] = dcl
                        end
                    else
                        dcl.id_ = string.upper('CEU_EVENT_'..dcl.id..'_'..dcl.n)
                        MEMS.evts[#MEMS.evts+1] = dcl
                    end
                end

            -- VEC
            elseif dcl.tag == 'Vec' then
                local is_alias, tp, _, dim = unpack(dcl)
                local ptr = (is_alias and '*' or '')
                dcl.id_ = dcl.id
                if not AST.par(me,'Data') then
                    dcl.id_ = dcl.id..'_'..dcl.n
                end
                if TYPES.is_nat(TYPES.get(tp,1)) then
                    mem[#mem+1] = [[
]]..TYPES.toc(tp)..' ('..ptr..dcl.id_..')['..V(dim)..[[];
]]
                else
                    if dim.is_const and (not is_alias) then
                        mem[#mem+1] = [[
]]..TYPES.toc(tp)..' '..dcl.id_..'_buf['..V(dim)..[[];
]]
                    end
                    mem[#mem+1] = [[
tceu_vector]]..ptr..' '..dcl.id_..[[;
]]
                end

            -- POOL
            elseif dcl.tag == 'Pool' then
                local is_alias, tp, _, dim = unpack(dcl)
                local ptr = (is_alias and '*' or '')
                dcl.id_ = dcl.id
                if not AST.par(me,'Data') then
                    dcl.id_ = dcl.id..'_'..dcl.n
                end
                if dim.is_const and (not is_alias) then
                    mem[#mem+1] = [[
tceu_code_mem_dyn* ]]..dcl.id_..'_queue['..V(dim)..[[];
byte ]]..dcl.id_..[[_buf[
    (sizeof(tceu_code_mem_dyn)+sizeof(]]..TYPES.toc(tp)..')) * '..V(dim)..[[
];
]]
                end
                mem[#mem+1] = [[
tceu_pool_pak]]..ptr..' '..dcl.id_..[[;
]]

            -- EXT
            elseif dcl.tag == 'Ext' then
                local inout, _, id = unpack(dcl)
                MEMS.exts[#MEMS.exts+1] = dcl
                dcl.id_ = string.upper('CEU_'..inout..'_'..id)
            end
end
        end
        if AST.par(me,'Data') then
            CUR().mem = CUR().mem..table.concat(mem)
        else
            CUR().mem = CUR().mem..'struct {\n'..table.concat(mem)
        end
    end,
    Block__POS = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'};\n'
        end
    end,

    ---------------------------------------------------------------------------

    Stmts__PRE = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'union {\n'
        end
    end,
    Stmts__POS = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'};\n'
        end
    end,

    Await_Wclock = function (me)
        CUR().mem = CUR().mem..'s32 __wclk_'..me.n..';\n'
    end,

    Abs_Await = function (me)
        local _,Abs_Cons = unpack(me)
        CUR().mem = CUR().mem..'tceu_code_mem_'..Abs_Cons.id..' __mem_'..me.n..';\n'
    end,

    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Par_Or__POS  = 'Par__POS',
    Par_And__POS = 'Par__POS',
    Par__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,

    Par_And = function (me)
        for i=1, #me do
            CUR().mem = CUR().mem..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
    end,

    ---------------------------------------------------------------------------

    Loop__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Loop__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,
    Loop = function (me)
        local max = unpack(me)
        if max then
            CUR().mem = CUR().mem..'int __max_'..me.n..';\n'
        end
    end,

    Loop_Num__PRE = 'Loop__PRE',
    Loop_Num__POS = 'Loop__POS',
    Loop_Num = function (me)
        local max, i, range, body = unpack(me)
        local fr, dir, to, step = unpack(range)
        F.Loop(me)  -- max
        if to.tag ~= 'ID_any' then
            CUR().mem = CUR().mem..'int __lim_'..me.n..';\n'
        end
    end,

    Loop_Pool__PRE = 'Loop__PRE',
    Loop_Pool__POS = 'Loop__POS',
    Loop_Pool = function (me)
        CUR().mem = CUR().mem..'tceu_code_mem_dyn* __cur_'..me.n..';\n'
        if me.yields then
            CUR().mem = CUR().mem..'tceu_code_mem_dyn* __dyn_'..me.n..';\n'
        end
    end,

    ---------------------------------------------------------------------------

    Async_Thread__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Async_Thread = function (me)
        CUR().mem = CUR().mem..'tceu_threads_data* __thread_'..me.n..';\n'
    end,
    Async_Thread__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,

    ---------------------------------------------------------------------------

    Lua_Do__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Lua_Do = function (me)
        CUR().mem = CUR().mem..'lua_State* __lua_'..me.n..';\n'
    end,
    Lua_Do__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,
}

AST.visit(F)

for _, dcl in ipairs(MEMS.exts) do
    local inout, Typelist = unpack(dcl)

    -- enum
    if inout == 'input' then
        MEMS.exts.enum_input  = MEMS.exts.enum_input..dcl.id_..',\n'
    else
        MEMS.exts.enum_output = MEMS.exts.enum_output..dcl.id_..',\n'
    end
    MEMS.exts.defines_input_output = MEMS.exts.defines_input_output..
                                        '#define _'..dcl.id_..'_\n'

    -- type
    local mem = 'typedef struct tceu_'..inout..'_'..dcl.id..' {\n'
    for i,Type in ipairs(Typelist) do
        mem = mem..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    mem = mem..'} tceu_'..inout..'_'..dcl.id..';\n'

    MEMS.exts.types = MEMS.exts.types..mem
end

for _, dcl in ipairs(MEMS.evts) do
    local is_alias,Typelist = unpack(dcl)

    -- enum
    if not is_alias then
        MEMS.evts.enum = MEMS.evts.enum..dcl.id_..',\n'
    end

    -- type
    local sufix = TYPES.noc(TYPES.tostring(Typelist))
    if not EVENT_SUFIX_EXISTS[sufix] then
        EVENT_SUFIX_EXISTS[sufix] = true
        local mem = [[
typedef struct tceu_event_]]..sufix..[[ {
]]
        for i,Type in ipairs(Typelist) do
            mem = mem..'    '..TYPES.toc(Type)..' _'..i..';\n'
        end
        mem = mem..[[
} tceu_event_]]..sufix..[[;
]]
        MEMS.evts.types = MEMS.evts.types..mem
    end
end

for i, code in ipairs(MEMS.codes) do
    local me = code.me
    local mods = me and unpack(me)

    MEMS.codes.mems = MEMS.codes.mems..code.mem
    if i < #MEMS.codes then
        MEMS.codes.args = MEMS.codes.args..code.args
        if code.wrapper then
            MEMS.codes.wrappers = MEMS.codes.wrappers..code.wrapper
        end
    end

    if code.me and code.me.dyn_base and code.me.dyn_base.dyn_last==code.me then
        MEMS.codes.mems = MEMS.codes.mems..[[
typedef union {
    tceu_code_mem mem;
]]
        for i, id2 in ipairs(code.me.dyn_base.dyns) do
            MEMS.codes.mems = MEMS.codes.mems..[[
    struct tceu_code_mem_]]..id2..' _'..i..[[;
]]
        end
        MEMS.codes.mems = MEMS.codes.mems..[[
} tceu_code_mem_]]..code.me.dyn_base.id..[[;
]]
    end
end

local function ids_supers_enums (dcl)
    local _, num = unpack(dcl)
    local t = {
        ids    = '',
        supers = '',
        nums  = '',
    }

    if dcl.hier.up then
        t.ids = t.ids .. [[
    CEU_DATA_]]..dcl.id_..[[,
]]
        t.supers = t.supers .. [[
    CEU_DATA_]]..dcl.hier.up.id_..[[,
]]
    else
        t.ids = t.ids .. [[
    CEU_DATA_]]..dcl.id_..[[ = 0,
]]
        t.supers = t.supers .. [[
    0,
]]
    end

    if num then
        t.nums = t.nums .. [[
    ]]..V(num)..[[,
]]
    end

    for _, sub in ipairs(dcl.hier.down) do
        local tt = ids_supers_enums(sub)
        t.ids    = t.ids    .. tt.ids
        t.supers = t.supers .. tt.supers
        t.nums   = t.nums   .. tt.nums
    end

    return t
end

for _, base in ipairs(MEMS.datas.bases) do
    local t = ids_supers_enums(base)
    MEMS.datas.hiers = MEMS.datas.hiers .. [[
enum {
    ]]..t.ids..[[
};

tceu_ndata CEU_DATA_SUPERS_]]..base.id_..[[ [] = {
    ]]..t.supers..[[
};
]]
    if t.nums ~= '' then
        MEMS.datas.hiers = MEMS.datas.hiers .. [[
tceu_ndata CEU_DATA_NUMS_]]..base.id_..[[ [] = {
    ]]..t.nums..[[
};
]]
    end
end