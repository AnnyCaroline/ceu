LABELS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
}

local function new (lbl)
    if lbl[2] then
        lbl.id = 'CEU_LABEL_'..lbl[1]
    else
        local Code = AST.iter'Code'()
        Code = (Code and Code.id..'_') or ''
        lbl.id = 'CEU_LABEL_'..Code..lbl[1]..'_'..(#LABELS.list+1)
    end
    if not LABELS.list[lbl.id] then
        LABELS.list[lbl.id] = true
        LABELS.list[#LABELS.list+1] = lbl
        lbl.n = #LABELS.list+1                   -- starts from 2
    end

    return lbl
end

F = {
    ROOT__PRE = function (me)
        me.lbl_in = new{'ROOT', true}
    end,

    Block = function (me)
        me.lbl_clr = new{'Block__CLR'}
    end,

    Do = function (me)
        local _,_,set = unpack(me)
        me.lbl_out = new{'Do__OUT'}
        me.lbl_clr = new{'Do__CLR'}
    end,

    Finalize_Case = function (me)
        me.lbl_in = new{'Finalize_Case__IN'}
    end,

    Var = function (me)
        if me.__dcls_code_alias then
            me.lbl = new{'Alias__CLR'}
        end
    end,

    Loop_Pool = function (me)
        F.Loop(me)
        me.lbl_clr  = new{'Loop_Pool__CLR'}
        me.lbl_fin  = new{'Loop_Pool__FIN'}
        me.lbl_null = new{'Loop_Pool__NULL'}
    end,
    Loop = function (me)
        me.lbl_clr = new{'Loop__CLR'}
        me.lbl_cnt = new{'Loop_Continue__CNT'}
        me.lbl_out = new{'Loop_Break__OUT'}
        if AST.par(me,'Async') then
            me.lbl_asy = new{'Loop_Async__CNT'}
        end
    end,
    Loop_Num = 'Loop',

    Code = function (me)
        local mods = unpack(me)
        me.lbl_in = new{'Code_'..me.id_, true}
        if mods.await then
            me.lbl_clr = new{'Code__CLR'}
        end
    end,

    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        me.lbls_in = {}
        for i, sub in ipairs(me) do
            me.lbls_in[i] = new{me.tag..'_sub_'..i..'_IN'}
        end
        if me.tag ~= 'Par' then
            me.lbl_out = new{me.tag..'__OUT'}
        end
        if me.tag == 'Par_Or' then
            me.lbl_clr = new{me.tag..'__CLR'}
        end
    end,

    ---------------------------------------------------------------------------

    Abs_Spawn = function (me)
        me.lbl_out = new{'Await_Spawn__OUT'}
    end,
    Await_Wclock = function (me)
        me.lbl_out = new{'Await_Wclock__OUT'}
    end,
    Await_Pause = function (me)
        me.lbl_out = new{'Await_Pause__OUT'}
    end,
    Await_Resume = function (me)
        me.lbl_out = new{'Await_Resume__OUT'}
    end,
    Await_Ext = function (me)
        local ID_ext = unpack(me)
        me.lbl_out = new{'Await_'..ID_ext.dcl.id..'__OUT'}
    end,
    Await_Int = function (me)
        local Loc = unpack(me)
        me.lbl_out = new{'Await_'..Loc.info.dcl.id..'__OUT'}
    end,

    Emit_Wclock = function (me)
        me.lbl_out = new{'Emit_Wclock__OUT'}
    end,
    Emit_Ext_emit = function (me)
        local ID_ext = unpack(me)
        local inout = unpack(ID_ext.dcl)
        if inout=='input' and AST.par(me,'Async_Isr') then
            return
        end
        me.lbl_out = new{'Emit_Ext_emit__'..ID_ext.dcl.id..'__OUT'}
    end,

    Async = function (me)
        me.lbl_in = new{'Async__IN'}
    end,

    Async_Thread = function (me)
        me.lbl_fin = new{'Async_Thread__FIN'}
        me.lbl_abt = new{'Async_Thread__ABT'}
        me.lbl_out = new{'Async_Thread__OUT'}
    end,

    Async_Isr = function (me)
        me.lbl_fin = new{'Async_Isr__FIN'}
    end,
}

AST.visit(F)
