CODES = {
    native = { pre='', pos='' }
}

local function LINE (me, line)
    me.code = me.code..'\n'..[[
/* ]]..me.tag..' (n='..me.n..', ln='..me.ln[2]..[[) */
]]
    if CEU.opts.ceu_line_directives then
        me.code = me.code..'\n'..[[
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]]
    end
    me.code = me.code..line
end

local function CONC (me, sub)
    me.code = me.code..sub.code
end

local function CONC_ALL (me)
    for _, sub in ipairs(me) do
        if AST.is_node(sub) then
            CONC(me, sub)
        end
    end
end

local function CASE (me, lbl)
    LINE(me, 'case '..lbl.id..':;')
end

local function CLEAR (me)
    if me.trails_n > 1 then
        LINE(me, [[
{
    CEU_STK_BCAST_ABORT(CEU_INPUT__CLEAR, NULL, _ceu_stk, _ceu_trlK,
                        _ceu_mem, ]]..me.trails[1]..', '..me.trails[2]..[[);
/* TODO */
    ceu_stack_clear(_ceu_stk->down, _ceu_mem,
                    ]]..me.trails[1]..[[, ]]..me.trails[2]..[[);
}
]])
    end
end

local function HALT (me, T)
    T = T or {}
    for _, t in ipairs(T) do
        local id, val = next(t)
        LINE(me, [[
_ceu_trl->]]..id..' = '..val..[[;
]])
    end
    if T.exec then
        LINE(me, [[
]]..T.exec..[[
]])
    end
    LINE(me, [[
return;
]])
    if T.lbl then
        LINE(me, [[
case ]]..T.lbl..[[:;
]])
    end
end

F = {
    ROOT = CONC_ALL,
    Block = CONC_ALL,
    Stmts = CONC_ALL,
    Await_Until = CONC_ALL,

    Node__PRE = function (me)
        me.code = ''
--[=[
        LINE(me, [[
/* PRE */
ceu_dbg_assert(_ceu_trl == &CEU_APP.trails[]]..me.trails[1]..[[], "bug found : unexpected trail");
]])
]=]
    end,
--[=[
    Node__POS = function (me)
        local trl = me.trails[1]
        if me.tag == 'Finalize' then
            trl = trl + 1
        end
        LINE(me, [[
/* POS */
ceu_dbg_assert(_ceu_trl == &CEU_APP.trails[]]..trl..[[], "bug found : unexpected trail");
]])
    end,
]=]

    ROOT__PRE = function (me)
        CASE(me, me.lbl_in)
        LINE(me, [[
_ceu_mem->up_mem = NULL;
_ceu_mem->trails_n = ]]..AST.root.trails_n..[[;
memset(&_ceu_mem->trails, 0, ]]..AST.root.trails_n..[[*sizeof(tceu_trl));
]])
    end,

    Nat_Block = function (me)
        local pre_pos, code = unpack(me)
        pre_pos = string.sub(pre_pos,2)

        -- unescape `##´ => `#´
        code = string.gsub(code, '^%s*##',  '#')
        code = string.gsub(code, '\n%s*##', '\n#')

        CODES.native[pre_pos] = CODES.native[pre_pos]..code
    end,
    Nat_Stmt = function (me)
        LINE(me, unpack(me))
    end,

    If = function (me)
        local c, t, f = unpack(me)
        LINE(me, [[
if (]]..V(c)..[[) {
    ]]..t.code..[[
} else {
    ]]..f.code..[[
}
]])
    end,

    ---------------------------------------------------------------------------

    Code = function (me)
        local mod,_,id,Typepars_ids,_,body = unpack(me)
        if not body then return end

LINE(me, [[
/* do not enter from outside */
if (0)
{
]])
        CASE(me, me.lbl_in)

        -- CODE/DELAYED
        if mod == 'code/delayed' then
            LINE(me, [[
    _ceu_mem->trails_n = ]]..me.trails_n..[[;
    memset(&_ceu_mem->trails, 0, ]]..me.trails_n..[[*sizeof(tceu_trl));
    int __ceu_ret_]]..me.n..[[;
]])
        -- CODE/INSTANTANEOUS
        else
            LINE(me, [[
    tceu_code_mem_]]..id..[[ _ceu_data;
]])
        end

        local vars = AST.get(me,'', 6,'Block', 1,'Stmts', 2,'Do', 2,'Block',
                                    1,'Stmts', 2,'Stmts')
        for i,Typepars_ids_item in ipairs(Typepars_ids) do
            local a,_,c,Type,id2 = unpack(Typepars_ids_item)
            assert(a=='var' and c==false)
            LINE(me, [[
]]..V(vars[i],{is_bind=true})..[[ = ((tceu_code_args_]]..id..[[*)_ceu_evt)->]]..id2..[[;
]])
        end

        CONC(me, body)

        -- CODE/DELAYED
        if mod == 'code/delayed' then
            LINE(me, [[
    {
        /* _ceu_evt holds __ceu_ret (see Escape) */
        tceu_evt_params_code ps = { _ceu_mem, _ceu_evt };
        CEU_STK_BCAST_ABORT(CEU_INPUT__CODE, &ps, _ceu_stk, _ceu_trlK,
                            (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
    }
]])
        end

        HALT(me)
        LINE(me, [[
}
]])
    end,

    Abs_Await = function (me)
        local Abs_Cons = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)
        HALT(me, {
            { evt = 'CEU_INPUT__CODE' },
            { lbl = me.lbl_out.id },
            { code_mem = '&'..CUR('__mem_'..me.n) },
            lbl = me.lbl_out.id,
            exec = [[
{
    tceu_code_args_]]..ID_abs.dcl.id..[[ __ceu_ps =
        {]]..table.concat(V(Abslist),',')..[[ };
    ]]..CUR(' __mem_'..me.n)..[[.mem.up_mem = _ceu_mem;
    ]]..CUR(' __mem_'..me.n)..[[.mem.up_trl = _ceu_trlK;
    CEU_STK_LBL((tceu_evt*)&__ceu_ps, _ceu_stk,
                (tceu_code_mem*)&]]..CUR(' __mem_'..me.n)..', 0, '..ID_abs.dcl.lbl_in.id..[[);
}
]],
        })
    end,

    ---------------------------------------------------------------------------

    Finalize = function (me)
        local now,_,later = unpack(me)
        LINE(me, [[
_ceu_mem->trails[]]..later.trails[1]..[[].evt = CEU_INPUT__CLEAR;
_ceu_mem->trails[]]..later.trails[1]..[[].lbl = ]]..me.lbl_in.id..[[;
_ceu_mem->trails[]]..later.trails[1]..[[].stk = NULL;
if (0) {
]])
        CASE(me, me.lbl_in)
        CONC(me, later)
        HALT(me)
        LINE(me, [[
}
]])
        if now then
            CONC(me, now)
        end
        LINE(me, [[
_ceu_trl++;
]])
    end,

    Pause_If = function (me)
        local e, body = unpack(me)
        LINE(me, [[
_ceu_mem->trails[]]..me.trails[1]..[[].evt        = CEU_INPUT__PAUSE;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_evt    = ]]..V(e)..[[;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_skip   = ]]..body.trails_n..[[;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_paused = 0;
_ceu_trl++;
]])
        CONC(me, body)
    end,

    ---------------------------------------------------------------------------

    Do = function (me)
        CONC_ALL(me)

        local _,_,set = unpack(me)
        if set then
            LINE(me, [[
ceu_cb_assert_msg(0, "reached end of `do´");
]])
        end
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Escape = function (me)
        local code = AST.par(me, 'Code')
        local evt do
            if code and code[1]=='code/delayed' then
                evt = '(tceu_evt*) &__ceu_ret_'..code.n
            else
                evt = 'NULL'
            end
        end
        LINE(me, [[
CEU_STK_LBL(]]..evt..[[, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
        HALT(me)
    end,

    ---------------------------------------------------------------------------

    __loop_max = function (me)
        local max = unpack(me)
        if max then
            return {
                -- ensures that max is constant
                ini = [[
{ char __]]..me.n..'['..V(max)..'/'..V(max)..[[ ] = {0}; }
]]..CUR('__max_'..me.n)..[[ = 0;
]],
                chk = [[
ceu_cb_assert_msg(]]..CUR('__max_'..me.n)..' < '..V(max)..[[, "`loop´ overflow");
]],
                inc = [[
]]..CUR('__max_'..me.n)..[[++;
]],
            }
        else
            return {
                ini = '',
                chk = '',
                inc = '',
            }
        end
    end,

    Every = function (me)
        local body = unpack(me)
        LINE(me, [[
while (1) {
    ]]..body.code..[[
}
]])
    end,

    __loop_async = function (me)
        local async = AST.par(me, 'Async')
        if async then
            LINE(me, [[
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
]])
            HALT(me, {
                { evt = 'CEU_INPUT__ASYNC' },
                { lbl = me.lbl_asy.id },
                { stk = 'NULL'} ,
                lbl = me.lbl_asy.id,
            })
        end
    end,

    Loop = function (me)
        local _, body = unpack(me)
        local max = F.__loop_max(me)

        LINE(me, [[
]]..max.ini..[[
while (1) {
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(body)
        F.__loop_async(me)
        LINE(me, [[
    ]]..max.inc..[[
}
]])
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Loop_Num = function (me)
        local _, i, fr, dir, to, step, body = unpack(me)
        local max = F.__loop_max(me)
        local op = (dir=='->' and '>' or '<')

        -- check if step is positive (static)
        if step then
            local f = load('return '..V(step))
            if f then
                local ok, num = pcall(f)
                num = tonumber(num)
                if ok and num then
                    if dir == '->' then
                        ASR(num>0, me,
                            'invalid `loop´ step : expected positive number : got "'..num..'"')
                    else
                        ASR(num<0, me,
                            'invalid `loop´ step : expected positive number : got "-'..num..'"')
                    end
                end
            end
        end


        if to.tag ~= 'ID_any' then
            LINE(me, [[
]]..CUR('__lim_'..me.n)..' = '..V(to)..[[;
]])
        end

        LINE(me, [[
]]..max.ini..[[
ceu_cb_assert_msg(]]..V(step)..' '..op..[[ 0, "invalid `loop´ step : expected positive number");
]]..V(i)..' = '..V(fr)..[[;
while (1) {
]])
        if to.tag ~= 'ID_any' then
            LINE(me, [[
    if (]]..V(i)..' '..op..' '..CUR('__lim_'..me.n)..[[) {
        break;
    }
]])
        end
        LINE(me, [[
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(body)
        F.__loop_async(me)
        LINE(me, [[
    ]]..V(i)..' = '..V(i)..' + '..V(step)..[[;
    ]]..max.inc..[[
}
]])
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Break = function (me)
        LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
        HALT(me)
    end,
    Continue = function (me)
        LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_cnt.id..[[);
]])
        HALT(me)
    end,

    Stmt_Call = function (me)
        local call = unpack(me)
        LINE(me, [[
]]..V(call)..[[;
]])
    end,

    ---------------------------------------------------------------------------

    __par_and = function (me, i)
        return CUR('__and_'..me.n..'_'..i)
    end,
    Par_Or  = 'Par',
    Par_And = 'Par',
    Par = function (me)
        -- Par_And: close gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
]]..CUR('__and_'..me.n..'_'..i)..[[ = 0;
]])
            end
        end

        -- call each branch
        for i, sub in ipairs(me) do
            if i < #me then
                LINE(me, [[
CEU_STK_LBL_ABORT(NULL, _ceu_stk,
                  ]]..me[i+1].trails[1]..[[,
                  _ceu_mem, ]]..sub.trails[1]..[[, ]]..me.lbls_in[i].id..[[);
]])
            else
                -- no need to abort since there's a "return" below
                LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..sub.trails[1]..','..me.lbls_in[i].id..[[);
]])
            end
        end
        HALT(me)

        -- code for each branch
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)

            if me.tag == 'Par' then
                HALT(me)
            else
                -- Par_And: open gates
                if me.tag == 'Par_And' then
                    LINE(me, [[
]]..CUR('__and_'..me.n..'_'..i)..[[ = 1;
]])
                end
                LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.trails[1]..','..me.lbl_out.id..[[);
]])
                HALT(me)
            end
        end

        -- rejoin
        if me.lbl_out then
            CASE(me, me.lbl_out)
        end

        -- Par_And: test gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
if (! ]]..CUR('__and_'..me.n..'_'..i)..[[) {
]])
                HALT(me)
                LINE(me, [[
}
]])
            end

        -- Par_Or: clear trails
        elseif me.tag == 'Par_Or' then
            CLEAR(me)
        end
    end,

    ---------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)

        if to.info.dcl.id == '_ret' then
            local code = AST.par(me, 'Code')
            if code then
                local mod = unpack(code)
                if mod == 'code/instantaneous' then
                    LINE(me, [[
((tceu_code_args_]]..code.id..[[*) _ceu_evt)->_ret = ]]..V(fr)..[[;
]])
                else
                    LINE(me, [[
__ceu_ret_]]..code.n..' = '..V(fr)..[[;
]])
                end
            else
                LINE(me, [[
{   int __ceu_ret = ]]..V(fr)..[[;
    ceu_callback_num_ptr(CEU_CALLBACK_TERMINATING, __ceu_ret, NULL);
}
]])
            end
        else
            -- var Ee.Xx ex = ...;
            -- var&& Ee = &&ex;
            local cast = ''
            if not TYPES.is_nat(TYPES.get(to.info.tp,1)) then
                cast = '('..TYPES.toc(to.info.tp)..')'
            end
            LINE(me, [[
]]..V(to)..' = '..cast..V(fr)..[[;
]])
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        -- var Ee.Xx ex = ...;
        -- var& Ee = &ex;
        local cast = ''
        if to.info.dcl.tag ~= 'Evt' then
            cast = '('..TYPES.toc(to.info.tp)..'*)'
        end

        LINE(me, [[
]]..V(to, {is_bind=true})..' = '..cast..V(fr)..[[;
]])
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        CONC_ALL(me)
        if fr.tag == 'Await_Wclock' then
            LINE(me, [[
]]..V(to)..[[ = CEU_APP.wclk_late;
]])
        else
            assert(fr.tag == 'Abs_Await')
            -- see "Set_Exp: _ret"
            LINE(me, [[
]]..V(to)..[[ = *((int*) ((tceu_evt_params_code*)_ceu_evt->params)->ret);
]])
        end
    end,
    Set_Await_many = function (me)
        local Await_Until, Namelist = unpack(me)
        local id do
            local ID_ext = AST.get(Await_Until,'', 1,'Await_Ext', 1,'ID_ext')
            if ID_ext then
                id = 'tceu_input_'..ID_ext.dcl.id
            else
                local Exp_Name = AST.asr(Await_Until,'', 1,'Await_Int', 1,'Exp_Name')
                id = 'tceu_event_'..Exp_Name.info.dcl.id..'_'..Exp_Name.info.dcl.n
            end
        end
        CONC(me, Await_Until)
        for i, name in ipairs(Namelist) do
            local ps = '(('..id..'*)(_ceu_evt->params))'
            LINE(me, [[
]]..V(name)..' = '..ps..'->_'..i..[[;
]])
        end
    end,

    Set_Emit_Ext_emit = CONC_ALL,   -- see Emit_Ext_emit

    Set_Abs_Val = function (me)
        local fr, to = unpack(me)
        local _,Abs_Cons = unpack(fr)
        LINE(me, [[
]]..V(to)..' = '..V(Abs_Cons)..[[;
]])
    end,

    ---------------------------------------------------------------------------

    Await_Forever = function (me)
        HALT(me)
    end,

    ---------------------------------------------------------------------------

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        HALT(me, {
            { evt = V(ID_ext) },
            { lbl = me.lbl_out.id },
            { stk = 'NULL'} ,
            lbl = me.lbl_out.id,
        })
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, Explist = unpack(me)
        local Typelist, inout = unpack(ID_ext.dcl)
        LINE(me, [[
{
]])
        local ps = 'NULL'
        if #Explist > 0 then
            LINE(me, [[
tceu_]]..inout..'_'..ID_ext.dcl.id..' __ceu_ps = { '..table.concat(V(Explist),',')..[[ };
]])
            ps = '&__ceu_ps'
        end

        if inout == 'output' then
            local set = AST.par(me,'Set_Emit_Ext_emit')
            if set then
                local _, to = unpack(set)
                LINE(me, [[
]]..V(to)..[[ =
]])
            end
            LINE(me, [[
    ceu_callback_num_ptr(CEU_CALLBACK_OUTPUT, ]]..V(ID_ext)..', '..ps..[[).num;
]])
        else
            LINE(me, [[
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
_ceu_trl->evt = CEU_INPUT__ASYNC;
_ceu_trl->lbl = ]]..me.lbl_out.id..[[;
_ceu_trl->stk = NULL;
]])
            LINE(me, [[
    ceu_go_ext(]]..V(ID_ext)..', '..ps..[[);
]])
            HALT(me, {
                lbl = me.lbl_out.id,
            })
        end

        LINE(me, [[
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Int = function (me)
        local Exp_Name = unpack(me)
        HALT(me, {
            { evt = V(Exp_Name) },
            { lbl = me.lbl_out.id },
            { stk = 'NULL'} ,
            lbl = me.lbl_out.id,
        })
    end,

    Emit_Evt = function (me)
        local Exp_Name, Explist = unpack(me)
        local Typelist = unpack(Exp_Name.info.dcl)

        LINE(me, [[
{
]])

        local ps = 'NULL'
        if Explist then
            LINE(me, [[
    tceu_event_]]..Exp_Name.info.dcl.id..'_'..Exp_Name.info.dcl.n..[[
        __ceu_ps = { ]]..table.concat(V(Explist),',')..[[ };
]])
            ps = '&__ceu_ps'
        end
        LINE(me, [[
    CEU_STK_BCAST_ABORT(]]..V(Exp_Name)..[[, &__ceu_ps, _ceu_stk, _ceu_trlK,
                        (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Wclock = function (me)
        local e = unpack(me)

        local wclk = CUR('__wclk_'..me.n)

        LINE(me, [[
ceu_wclock(]]..V(e)..', &'..wclk..[[, NULL);

_CEU_HALT_]]..me.n..[[_:
]])
        HALT(me, {
            { evt = 'CEU_INPUT__WCLOCK' },
            { lbl = me.lbl_out.id },
            { stk = 'NULL'} ,
            lbl = me.lbl_out.id,
        })
        LINE(me, [[
/* subtract time and check if I have to awake */
{
    s32* dt = (s32*)_ceu_evt->params;
    if (!ceu_wclock(*dt, NULL, &]]..wclk..[[) ) {
        goto _CEU_HALT_]]..me.n..[[_;
    }
}
]])
    end,

    Emit_Wclock = function (me)
        local e = unpack(me)
        HALT(me, {
            { evt = 'CEU_INPUT__ASYNC' },
            { lbl = me.lbl_out.id },
            { stk = 'NULL' },
            lbl = me.lbl_out.id,
            exec = [[
{
    ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
    s32 __ceu_dt = ]]..V(e)..[[;
    do {
        ceu_go_ext(CEU_INPUT__WCLOCK, &__ceu_dt);
        if (!_ceu_stk->is_alive) {
            return;
        }
        __ceu_dt = 0;
    } while (CEU_APP.wclk_min_set <= 0);
}
]],
        })
    end,

    ---------------------------------------------------------------------------

    Async = function (me)
        local _,blk = unpack(me)
        LINE(me, [[
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
]])
        HALT(me, {
            { evt = 'CEU_INPUT__ASYNC' },
            { lbl = me.lbl_in.id },
            { stk = 'NULL'} ,
            lbl = me.lbl_in.id,
        })
        CONC(me, blk)
    end,
}

-------------------------------------------------------------------------------

local function SUB (str, from, to)
    assert(to, from)
    local i,e = string.find(str, from, 1, true)
    if i then
        return SUB(string.sub(str,1,i-1) .. to .. string.sub(str,e+1),
                   from, to)
    else
        return str
    end
end

local H = ASR(io.open(CEU.opts.ceu_output_h,'w'))
local C = ASR(io.open(CEU.opts.ceu_output_c,'w'))

AST.visit(F)

local labels do
    labels = ''
    for _, lbl in ipairs(LABELS.list) do
        labels = labels..lbl.id..',\n'
    end
end

-- CEU.C
local c = PAK.files.ceu_c
local c = SUB(c, '=== NATIVE_PRE ===',       CODES.native.pre)
local c = SUB(c, '=== DATAS_ENUM ===',       MEMS.datas.enum)
local c = SUB(c, '=== DATAS_MEMS ===',       MEMS.datas.mems)
local c = SUB(c, '=== DATAS_SUPERS ===',     MEMS.datas.supers)
local c = SUB(c, '=== CODES_MEMS ===',       MEMS.codes.mems)
local c = SUB(c, '=== CODES_ARGS ===',       MEMS.codes.args)
local c = SUB(c, '=== EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== EVTS_TYPES ===',       MEMS.evts.types)
local c = SUB(c, '=== EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== EVTS_ENUM ===',        MEMS.evts.enum)
local c = SUB(c, '=== TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',           labels)
local c = SUB(c, '=== NATIVE_POS ===',       CODES.native.pos)
local c = SUB(c, '=== CODES_WRAPPERS ===',   MEMS.codes.wrappers)
local c = SUB(c, '=== CODES ===',            AST.root.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
