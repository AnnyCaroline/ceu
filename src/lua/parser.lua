local P, C, V, S, Cc, Ct = m.P, m.C, m.V, m.S, m.Cc, m.Ct

local X = V'__SPACES'

local ERR_msg
local ERR_i
local LST_i

local I2TK

local f = function (s, i, tk)
    if tk == '' then
        tk = '<BOF>'
        LST_i = 1           -- restart parsing
        ERR_i = 0           -- ERR_i < 1st i
        ERR_msg = '?'
        I2TK = { [1]='<BOF>' }
    elseif i > LST_i then
        LST_i = i
        I2TK[i] = tk
    end
    return true
end
local K = function (patt, nox)
    key = P(true)
    if type(patt) == 'string' then
        if string.match(patt,'^[a-zA-Z_0-9]*$') then
            key = -m.R('09','__','az','AZ','\127\255')
        end
    end

    ERR_msg = '?'

    local ret = #P(1) * m.Cmt(patt*key, f)
    if not nox then
        ret = ret * X
    end
    return ret
end
local CK = function (patt)
    return C(K(patt,true)) * X
end
local EK = function (patt)
    return K(patt) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected `'..patt.."´"
            end
            return false
        end) * P(false)
end

local OPT = function (patt)
    return patt + Cc(false)
end

local PARENS = function (patt)
    return K'(' * patt * EK')'
end

local Ccs = function (...)
    local ret = Cc(true)
    for _, v in ipairs(...) do
        ret = ret * Cc(v)
    end
    return ret
end

local _V2NAME = {
-->>> OK
    __do_escape_id = '`escape´ identifier',
    Explist = 'expression',
--<<<

    __Exp = 'expression',
    --__StmtS = 'statement',
    --__StmtB = 'statement',
    --__LstStmt = 'statement',
    --__LstStmtB = 'statement',
    ID_ext = 'event',
    ID_int = 'variable/event',
    __ID_adt  = 'identifier',
    __ID_abs = ' abstraction identifier',
    __ID_nat  = 'identifier',
    __ID_int  = 'identifier',
    __ID_ext  = 'identifier',
    __ID_cls  = 'identifier',
    Type = 'type',
    __ID_field = 'identifier',
    _Vars = 'declaration',
    _Evts = 'declaration',
    __nat  = 'declaration',
    _Nats   = 'declaration',
    Dcl_adt_tag = 'declaration',
    __adt_expitem = 'parameter',
    __adt_expitem = 'parameter',
    __Do = 'block',
}
for i=1, 13 do
    _V2NAME['__'..i] = 'expression'
end
local EV = function (rule)
    assert(rule, rule)
    return V(rule) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected ' .. assert(_V2NAME[rule],rule)
            end
            return false
        end) * P(false)
end

local EM = function (msg,full)
    return m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = (full and '' or 'expected ') .. msg
                return false
            end
            return true
        end)
end

local E = function (patt, msg)
    return patt + EM(msg)
end

-->>> OK
TYPES = P'bool' + 'byte'
      + 'f32' + 'f64' + 'float'
      + 'int'
      + 's16' + 's32' + 's64' + 's8'
      + 'ssize'
      + 'u16' + 'u32' + 'u64' + 'u8'
      + 'uint' + 'usize' + 'void'
--<<<

KEYS = P
'and' +
'async' +
'as' +          -- TODO vs async
'async/isr' +
'async/thread' +
'atomic' +
'await' +
'break' +
'call' +
'call/recursive' +
'class' +
'code' +
'continue' +
'data' +
'deterministic' +
'do' +
'else' +
'else/if' +
'emit' +
'end' +
'escape' +
'event' +
'every' +
'false' +
'finalize' +
'FOREVER' +
'global' +
'if' +
'in' +
'input' +
'input/output' +
'interface' +
'kill' +
'loop' +
'native' +
'native/pre' +
'new' +
'not' +
'nothing' +
'null' +
'or' +
'outer' +
'output' +
'output/input' +
'par' +
'par/and' +
'par/or' +
'pause/if' +
'pool' +
'pre' +
'request' +
'sizeof' +
'spawn' +
'tag' +
'then' +
'this' +
'traverse' +
'true' +
'until' +
'var' +
'vector' +
'watching' +
'with' +
TYPES

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

NUM = CK(m.R'09'^1) / tonumber

-- Rule:    unchanged in the AST
-- _Rule:   changed in the AST as "Rule"
-- __Rule:  container for other rules, not in the AST
-- __rule:  (local) container for other rules

GG = { [1] = CK'' * V'_Stmts' * P(-1)-- + EM'expected EOF')

-->>> OK

    , Nothing = K'nothing'

-- DO, BLOCK

    -- escape/A 10
    -- break/i
    -- continue/i
    , _Escape   = K'escape'   * OPT('/'*EV'__do_escape_id')
                                * OPT(EV'__Exp')
    , _Break    = K'break'    * OPT('/'*EV'ID_int')
    , _Continue = K'continue' * OPT('/'*EV'ID_int')

    , __do_escape_id = CK(Alpha * (Alphanum)^0)

    -- do/A ... end
    , Do = K'do' * OPT('/'*EV'__do_escape_id') *
                V'Block' *
           K'end'

    , __Do  = K'do' * V'Block' * K'end'
    , Block = V'_Stmts'

-- PAR, PAR/AND, PAR/OR

    , Par    = K'par' * EK'do' *
                V'Block' * (EK'with' * V'Block')^1 *
               EK'end'
    , Parand = K'par/and' * EK'do' *
                V'Block' * (EK'with' * V'Block')^1 *
               EK'end'
    , Paror  = K'par/or' * EK'do' *
                V'Block' * (EK'with' * V'Block')^1 *
               EK'end'

-- CODE / EXTS (call, req)

    -- CODE

    , __code   = (CK'code/instantaneous' + CK'code/delayed')
                    * OPT(CK'/recursive')
                    * EV'__ID_abs'
                    * EV'_Typepars' * EK'=>' * EV'Type'
    , _Code_proto = V'__code'
    , _Code_impl  = V'__code' * V'__Do'

    -- EXTS

    -- call
    , __extcall = (CK'input' + CK'output')
                    * OPT(CK'/recursive')
                    * Cc(false)     -- spawn array
                    * V'_Typepars' * K'=>' * EV'Type'
                    * EV'__ID_ext' * (K','*EV'__ID_ext')^0
    , _Extcall_proto = V'__extcall'
    , _Extcall_impl  = V'__extcall' * V'__Do'

    -- req
    , __extreq = (CK'input/output' + CK'output/input')
                   * OPT('[' * (V'__Exp'+Cc(true)) * EK']')
                   * Cc(false)     -- recursive
                   * V'_Typepars' * K'=>' * EV'Type'
                   * EV'__ID_ext' * (K','*EV'__ID_ext')^0
    , _Extreq_proto = V'__extreq'
    , _Extreq_impl  = V'__extreq' * V'__Do'

    -- TYPEPARS

    -- (var& int, var/nohold void&&)
    -- (var& int v, var/nohold void&& ptr)
    , __typepars_pre = K'vector' * K'&' * EV'__Dim'
                     + K'pool'   * K'&' * EV'__Dim'
                     + EK'var'   * OPT(CK'&') * OPT(K'/'*CK'hold')

    , _Typepars_item_id   = V'__typepars_pre' * EV'Type' * EV'__ID_int'
    , _Typepars_item_anon = V'__typepars_pre' * EV'Type' * Cc(false)
    , _Typepars = #EK'(' * (
                    PARENS(P'void') +
                    PARENS(EV'_Typepars_item_anon' * (EK','*V'_Typepars_item_anon')^0) +
                    PARENS(EV'_Typepars_item_id'   * (EK','*V'_Typepars_item_id')^0)
                  )


-- NATIVE

    , _Nats = K'native' *
                OPT(K'/'*(CK'pure'+CK'const'+CK'nohold'+CK'plain')) *
                EV'__nat' * (K',' * EV'__nat')^0
    , __nat = Cc'type' * V'__ID_nat' * K'=' * NUM
                + Cc'func' * V'__ID_nat' * '()' * Cc(false)
                + Cc'unk'  * V'__ID_nat'        * Cc(false)

    , Host = OPT(CK'pre') * K'native' * (#EK'do')*'do' *
                ( C(V'_C') + C((P(1)-(S'\t\n\r '*'end'*P';'^0*'\n'))^0) ) *
             X* EK'end'

-- VARS, VECTORS, POOLS, EVTS, EXTS

    -- DECLARATIONS

    , __vars_set  = EV'__ID_int' * OPT(V'__Sets_one')

    , _Vars_set  = CK'var' * OPT(CK'&') * EV'Type' *
                    EV'__vars_set' * (K','*EV'__vars_set')^0
    , _Vars      = CK'var' * OPT(CK'&') * EV'Type' *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

    , _Vecs_set  = CK'vector' * OPT(CK'&') * EV'__Dim' * EV'Type' *
                    EV'__vars_set' * (K','*EV'__vars_set')^0
                        -- TODO: only vec constr
    , _Vecs      = CK'vector' * OPT(CK'&') * EV'__Dim' * EV'Type' *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

    , _Pools_set = CK'pool' * OPT(CK'&') * EV'__Dim' * EV'Type' *
                    EV'__vars_set' * (K','*EV'__vars_set')^0
    , _Pools     = CK'pool' * OPT(CK'&') * EV'__Dim' * EV'Type' *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

    , _Evts_set  = CK'event' * OPT(CK'&') * (PARENS(V'_Typelist')+EV'Type') *
                    EV'__vars_set' * (K','*EV'__vars_set')^0
    , _Evts      = CK'event' * OPT(CK'&') * (PARENS(V'_Typelist')+EV'Type') *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

    , _Exts      = (CK'input'+CK'output') * (PARENS(V'_Typelist')+EV'Type') *
                    EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- USES

    , __evts_ps = EV'__Exp' + PARENS(OPT(V'Explist'))
    , Extemit  = K'emit' * (
                    (V'WCLOCKK'+V'WCLOCKE') * OPT(K'=>' * EV'__Exp') +
                    EV'ID_ext' * OPT(K'=>' * EV'__evts_ps')
                 )
    , Extcall  = (K'call/recursive'+K'call') *
                    EV'ID_ext' * OPT(K'=>' * EV'__evts_ps')
    , Extreq   = K'request' *
                    EV'ID_ext' * OPT(K'=>' * EV'__evts_ps')

    , Intemit  = K'emit' * -#(V'WCLOCKK'+V'WCLOCKE') *
                    EV'__Exp' * OPT(K'=>' * EV'__evts_ps')

-- DETERMINISTIC

    , __det_id = V'ID_ext' + V'ID_int' + V'ID_abs' + V'__ID_nat'
    , Deterministic = K'deterministic' * EV'__det_id' * (
                        EK'with' * EV'__det_id' * (K',' * EV'__det_id')^0
                      )^-1

-- SETS

    -- after `=´
    , _Set_Do       = #(K'do'*EK'/')    * V'Do'
    , _Set_Await    = #K'await'         * V'Await'
    , _Set_Watching = #K'watching'      * V'_Watching'
    , _Set_Spawn    = #K'spawn'         * V'Spawn'
    , _Set_Thread   = #K'async/thread'  * V'_Thread'
    , _Set_Lua      = #V'__lua_pre'     * V'_Lua'
    , _Set_Vec      = #V'__vec_pre'     * V'_Vecnew'
    , _Set_Exp      =                     V'__Exp'

    , _Set_Extemit  = #K'emit'          * V'Extemit'
    , _Set_Extreq   = #K'request'       * V'Extreq'
    , _Set_Extcall  = #V'__extcall_pre' * V'Extcall'

    , __extcall_pre = (K'call/recursive'+K'call') * V'ID_ext'
    , __lua_pre     = K'[' * (P'='^0) * '['
    , __vec_pre     = K'[' - V'__lua_pre'

    -- vector constructor
    , Vectup  = V'__vec_pre' * OPT(V'Explist') * EK']'
    , _Vecnew = V'Vectup' * (K'..' * (V'__Exp' + #EK'['*V'Vectup'))^0


-- IDS

    , ID_ext  = V'__ID_ext'
    , ID_int  = V'__ID_int'
    , ID_abs  = V'__ID_abs'
    , ID_nat  = V'__ID_nat'
    , ID_none = V'__ID_none'

    , __ID_ext  = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_int  = -KEYS * CK(m.R'az'*Alphanum^0)
    , __ID_abs  = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_nat  = CK(P'_' * Alphanum^1)
    , __ID_none = CK(P'_' * -Alphanum)

-- MODS

    , __Dim = EK'[' * (V'__Exp'+Cc('[]')) * K']'

-- LISTS

    , Varlist   = V'ID_int' * (K',' * EV'ID_int')^0
    , Explist   = V'__Exp'  * (K',' * EV'__Exp')^0
    , _Typelist = V'Type'   * (K',' * EV'Type')^0

 --<<<

-- Declarations

    -- variables, organisms
    , __Org = CK'var' * OPT(CK'&') * EV'Type' * Cc(true)  * (EV'__ID_int'+V'ID_none') *
                        ( Cc(false) * EK'with' * V'Dcl_constr' * EK'end'
                        + K'=' * V'_Var_constr' * (
                            EK'with' * V'Dcl_constr' * EK'end' +
                            Cc(false)
                          ) )
            + CK'vector' * OPT(CK'&') * EV'__Dim' * EV'Type' * Cc(true)  * (EV'__ID_int'+V'ID_none') *
                        ( Cc(false) * EK'with' * V'Dcl_constr' * EK'end'
                        + K'=' * V'_Var_constr' * (
                            EK'with' * V'Dcl_constr' * EK'end' +
                            Cc(false)
                          ) )
    , _Var_constr = V'__ID_cls' * (EK'.'-'..') * EV'__ID_int' *
                        PARENS(OPT(V'Explist'))

    -- auxiliary
    , Dcl_constr = V'Block'

    -- classes / interfaces
    , Dcl_cls  = K'class'     * Cc(false)
               * EV'__ID_cls'
               * EK'with' * V'_BlockI' * V'__Do'
    , _Dcl_ifc = K'interface' * Cc(true)
               * EV'__ID_cls'
               * EK'with' * V'_BlockI' * EK'end'
    , _BlockI = ( (V'__Org'
                  + V'_Vars_set'  + EV'_Vars'
                  + V'_Vecs_set'  + V'_Vecs'
                  + V'_Pools_set' + V'_Pools'
                  + V'_Evts_set'  + V'_Evts'
                  + V'_Code_proto' + V'_Dcl_imp')
                    * (EK';'*K';'^0)
                + V'Dcl_mode' * K':'
                )^0
    , _Dcl_imp = K'interface' * EV'__ID_cls' * (K',' * EV'__ID_cls')^0
    , Dcl_mode = CK'input/output'+CK'output/input'+CK'input'+CK'output'

    -- ddd types
    , _DDD = K'ddd' * EV'__ID_abs' * EK'with' * (
                (V'_Vars'+V'_Vecs'+V'_Pools'+V'_Evts') *
                    (EK';'*K';'^0)
             )^1 * EK'end'

    -- ddd-constr
    , DDD_constr_root = K'@' * OPT(CK'new') * V'DDD_constr_one'
    , DDD_constr_one  = V'__ID_abs' * PARENS(EV'_DDD_explist')
    , _DDD_explist    = ( V'__ddd_expitem'*(K','*EV'__ddd_expitem')^0 )^-1
    , __ddd_expitem   = (V'DDD_constr_one' + V'__Exp')

    -- data types
    , Dcl_adt = K'data' * EV'__ID_adt' * EK'with'
               *    (V'__Dcl_adt_struct' + V'__Dcl_adt_union')
               * EK'end'
    , __Dcl_adt_struct = Cc'struct' * (
                            (V'_Vars'+V'_Evts'+V'_Vecs') * (EK';'*K';'^0)
                         )^1
    , __Dcl_adt_union  = Cc'union'  * V'Dcl_adt_tag' * (EK'or' * EV'Dcl_adt_tag')^0
    , Dcl_adt_tag    = K'tag' * EV'__ID_tag' * EK'with'
                      *   ((V'_Vars'+V'_Vecs') * (EK';'*K';'^0))^0
                      * EK'end'
                      + K'tag' * EV'__ID_tag' * (EK';'*K';'^0)

-- Assignments

    , _Set_one   = V'__Exp'           * V'__Sets_one'
    , _Set_many  = PARENS(V'Varlist') * V'__Sets_many'

    , __Sets_one  = (CK'='+CK':=') * (V'__sets_one'  + PARENS(V'__sets_one'))
    , __Sets_many = (CK'='+CK':=') *
                        E((V'__sets_many' + PARENS(V'__sets_many')), '`await´')

    , __sets_one =
                --Cc'emit-ext'   * (V'EmitExt' + K'('*V'EmitExt'*EK')')
              Cc'adt-constr' * V'Adt_constr_root'
              + Cc'ddd-constr' * V'DDD_constr_root'
              + Cc'__trav_loop' * V'_TraverseLoop'  -- before Rec
              + Cc'__trav_rec'  * V'_TraverseRec'   -- after Loop
        + V'_Set_Extemit' + V'_Set_Extcall' + V'_Set_Extreq'
        + V'_Set_Do'
        + V'_Set_Await'
        + V'_Set_Watching'
        + V'_Set_Spawn'
        + V'_Set_Thread'
        + V'_Set_Lua'
        + V'_Set_Vec'
        + V'_Set_Exp'
              + Cc'do-org'     * V'_DoOrg'
              + EM'expression'

    , __sets_many = V'_Set_Extreq' + V'_Set_Await' + V'_Set_Watching'

    -- adt-constr
    , Adt_constr_root = OPT(CK'new') * V'Adt_constr_one'
    , Adt_constr_one  = V'Adt' * #EK'('*PARENS(EV'_Adt_explist')
    , Adt             = V'__ID_adt' * OPT((K'.'-'..')*V'__ID_tag')
    , __adt_expitem   = (V'Adt_constr_one' + V'_Vecnew' + V'__Exp')
    , _Adt_explist    = ( V'__adt_expitem'*(K','*EV'__adt_expitem')^0 )^-1

-- Function calls

    , CallStmt = V'__Exp'

-- Event handling

    -- internal/external await
    , Await    = K'await' * V'__awaits'
                    * OPT(K'until'*EV'__Exp')
    , AwaitN   = K'await' * K'FOREVER'
    , __awaits = Cc(false) * (V'WCLOCKK'+V'WCLOCKE')  -- false,   wclock
               + (EV'ID_ext'+EV'__Exp') * Cc(false)      -- ext/int/org, false

    -- internal/external emit/call/request
    -- TODO: emit/await, move from "false"=>"_WCLOCK"

-- Organism instantiation

    -- do organism
    , _DoOrg = K'do' * (EV'__ID_cls' + K'@'*EV'__Exp')
             * OPT(V'_Spawn_constr')
             * OPT(EK'with'*V'Dcl_constr'* EK'end')

    -- spawn / kill
    , _SpawnAnon = K'spawn' * EV'__Do'
    , Spawn = K'spawn' * EV'__ID_cls'
            * OPT(V'_Spawn_constr')
            * OPT(K'in'*EV'__Exp')
            * OPT(EK'with'*V'Dcl_constr'* EK'end')
    , _Spawn_constr = (K'.'-'..') * EV'__ID_int' * PARENS(OPT(V'Explist'))

    , Kill  = K'kill' * EV'__Exp' * OPT(EK'=>'*EV'__Exp')

-- Flow control

    -- global (top level) execution
    , _DoPre = K'pre' * V'__Do'

    -- conditional
    , If = K'if' * EV'__Exp' * EK'then' *
            V'Block' *
           (K'else/if' * EV'__Exp' * EK'then' * V'Block')^0 *
           OPT(K'else' * V'Block') *
           EK'end'-- - V'_Continue'

    -- loops
    , _Loop   = K'loop' * OPT('/'*EV'__Exp') *
                    ((V'ID_int'+V'ID_none') * OPT(EK'in'*EV'__Exp')
                    + Cc(false,false)) *
                V'__Do'
    , _Every  = K'every' * ( (EV'ID_int'+PARENS(V'Varlist')) * EK'in'
                            + Cc(false) )
              * V'__awaits'
              * V'__Do'

    -- traverse
    , _TraverseLoop = K'traverse' * (V'ID_int'+V'ID_none') * EK'in' * (
                        Cc'number' * (K'['*(V'__Exp'+Cc'[]')*EK']')
                      +
                        Cc'adt'    * EV'__Exp'
                    )
                    * OPT(K'with'*V'_BlockI')
                    * V'__Do'
    , _TraverseRec  = K'traverse' * OPT('/'*V'NUMBER') * EV'__Exp'
                    * OPT(K'with'*V'Block'*EK'end')

        --[[
        loop/N i in <e-num> do
            ...
        end
        loop (T*)i in <e-pool-org> do
            ...
        end
        loop i in <e-rec-data> do
            ...
        end
        loop (a,b,c) in <e-evt> do
            ...
        end
            , _Iter   = K'loop' * K'('*EV'Type'*EK')'
                      *     V'__ID_int' * K'in' * EV'__Exp'
                      * V'__Do'
        ]]

    -- finalization
    , Finalize = K'finalize' * OPT(V'_Set_one'*EK';'*K';'^0)
               * EK'with' * EV'Finally' * EK'end'
    , Finally  = V'Block'

    , _Watching = K'watching' * V'__awaits' * V'__Do'

    -- pause
    , _Pause   = K'pause/if' * EV'__Exp' * V'__Do'

    -- asynchronous execution
    , Async   = K'async' * (-P'/thread'-'/isr') * OPT(PARENS(V'Varlist')) *
                V'__Do'
    , _Thread = K'async/thread' * OPT(PARENS(V'Varlist')) * V'__Do'
    , _Isr    = K'async/isr'    *
                    EK'[' * EV'Explist' * EK']' *
                    OPT(PARENS(V'Varlist')) *
                V'__Do'
    , Atomic  = K'atomic' * V'__Do'

    -- C integration
    , RawStmt = K'{' * C(V'__raw') * EK'}'
    , RawExp  = K'{' * C(V'__raw') * EK'}'
    , __raw   = ((1-S'{}') + '{'*V'__raw'*'}')^0

    -- Lua integration
    -- Stmt/Exp differ only by the "return" and are re-unified in "adj.lua"
    , _Lua    = K'[' * m.Cg(P'='^0,'lua') * '[' *
                ( V'__luaext' + C((P(1)-V'__luaext'-V'__luacmp')^1) )^0
                 * (V'__luacl'/function()end) *X
    , __luaext = K'@' * V'__Exp'
    , __luacl  = ']' * C(P'='^0) * EK']'
    , __luacmp = m.Cmt(V'__luacl' * m.Cb'lua',
                    function (s,i,a,b) return a == b end)

    , __ID_cls   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_adt   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_tag   = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_field = CK(Alpha * (Alphanum)^0)


-- Types

    , __type = CK(TYPES) + V'__ID_abs' + V'__ID_cls' + V'__ID_adt'
    , __type_ptr = CK'&&' -(P'&'^3)
    , __type_vec = K'[' * V'__Exp' * K']'
    , Type = V'__type'   * (V'__type_ptr'              )^0 * CK'?'^-1
           + V'__ID_nat' * (V'__type_ptr'+V'__type_vec')^0 * CK'?'^-1

-- Wall-clock values

    , WCLOCKK = #NUM *
                (NUM * P'h'   *X + Cc(0)) *
                (NUM * P'min' *X + Cc(0)) *
                (NUM * P's'   *X + Cc(0)) *
                (NUM * P'ms'  *X + Cc(0)) *
                (NUM * P'us'  *X + Cc(0)) *
                (NUM * EM'<h,min,s,ms,us>')^-1 * OPT(CK'/')
    , WCLOCKE = PARENS(V'__Exp') * (
                    CK'h' + CK'min' + CK's' + CK'ms' + CK'us'
                  + EM'<h,min,s,ms,us>'
              ) * OPT(CK'/')

-- Expressions

    , __Exp  = V'__0'
    , __0    = V'__1' * K'..' * EM('invalid constructor syntax',true) * -1
             + V'__1'
    , __1    = V'__2'  * (CK'or'  * EV'__2')^0
    , __2    = V'__3'  * (CK'and' * EV'__3')^0
    , __3    = V'__4'  * ( ( (CK'!='-'!==')+CK'=='+CK'<='+CK'>='
                           + (CK'<'-'<<')+(CK'>'-'>>')
                           ) * EV'__4'
                         + CK'as' * EV'__Cast'
                         )^0
    , __4    = V'__5'  * ((CK'|'-'||') * EV'__5')^0
    , __5    = V'__6'  * (CK'^' * EV'__6')^0
    , __6    = V'__7'  * (CK'&' * EV'__7')^0
    , __7    = V'__8'  * ((CK'>>'+CK'<<') * EV'__8')^0
    , __8    = V'__9'  * ((CK'+'+CK'-') * EV'__9')^0
    , __9    = V'__10' * ((CK'*'+(CK'/'-'//'-'/*')+CK'%') * EV'__10')^0
    , __10   = ( Cc(false) * ( CK'not'+CK'-'+CK'+'+CK'~'+CK'*'+
                               (CK'&&'-P'&'^3) + (CK'&'-'&&') +
                               CK'$$' + (CK'$'-'$$') )
               )^0 * V'__11'
    , __11   = V'__12' *
                  (
                      PARENS(Cc'call' * OPT(EV'Explist')) *
                          OPT(K'finalize' * EK'with' * V'Finally' * EK'end')
                  +
                      K'[' * Cc'idx'  * EV'__Exp'    * EK']' +
                      (CK':' + (CK'.'-'..')) * EV'__ID_field' +
                      CK'?' + (CK'!'-'!=')
                  )^0
    , __12   = V'__Prim'

    , __Prim = PARENS(V'__Exp')
             + V'SIZEOF'
-- Field
             + K'@'*V'ID_abs'
             + V'ID_int'     + V'ID_nat'
             + V'NULL'    + V'NUMBER' + V'STRING'
             + V'Global'  + V'This'   + V'Outer'
             + V'RawExp'  --+ V'Vector_constr'
             + CK'call'     * V'__Exp'
             + CK'call/recursive' * V'__Exp'

-->>> OK
    , __Cast = V'Type' + K'/'*(CK'nohold'+CK'plain'+CK'pure')
--<<<

    , SIZEOF = K'sizeof' * PARENS((V'Type' + V'__Exp'))
    , NULL   = CK'null'     -- TODO: the idea is to get rid of this
    , STRING = CK( CK'"' * (P(1)-'"'-'\n')^0 * EK'"' )

    , NUMBER = CK( #m.R'09' * (m.R'09'+S'xX'+m.R'AF'+m.R'af'+(P'.'-'..')
                                      +(S'Ee'*'-')+S'Ee')^1 )
             + CK( "'" * (P(1)-"'")^0 * "'" )
             + K'false' / function() return 0 end
             + K'true'  / function() return 1 end

    , Global  = K'global'
    , This    = K'this' * Cc(false)
    , Outer   = K'outer'

---------
                -- "Ct" as a special case to avoid "too many captures" (HACK_1)
    , _Stmts  = Ct (( V'__StmtS' * (EK';'*K';'^0) +
                      V'__StmtB' * (K';'^0)
                   )^0
                 * ( V'__LstStmt' * (EK';'*K';'^0) +
                     V'__LstStmtB' * (K';'^0)
                   )^-1
                 * (V'Host'+V'_Code_impl')^0 )

    , __LstStmt  = V'_Escape' + V'_Break' + V'_Continue' + V'AwaitN'
    , __LstStmtB = V'Par'
    , __StmtS    = V'Nothing'
                 + V'__Org'
                 + V'_Vars_set'  + V'_Vars'
                 + V'_Vecs_set'  + V'_Vecs'
                 + V'_Pools_set' + V'_Pools'
                 + V'_Evts_set'  + V'_Evts'
                 + V'_Exts'
                 + V'_Code_proto' + V'_Extcall_proto' + V'_Extreq_proto'
                 + V'_Nats'  + V'Deterministic'
                 + V'_Set_one' + V'_Set_many'
                 + V'Await' + V'Intemit'
                 + V'Extemit' + V'Extcall' + V'Extreq'
                 + V'Spawn' + V'Kill'
                 + V'_TraverseRec'
                 + V'_DoOrg'
                 + V'RawStmt'

             + V'CallStmt' -- last
             --+ EM'statement'-- (missing `_´?)'
             + EM'statement (usually a missing `var´ or C prefix `_´)'

    , __StmtB = V'_Code_impl' + V'_Extcall_impl' + V'_Extreq_impl'
              + V'_Dcl_ifc'  + V'Dcl_cls' + V'Dcl_adt' + V'_DDD'
              + V'Host'
              + V'Do'    + V'If'
              + V'_Loop' + V'_Every' + V'_TraverseLoop'
              + V'_SpawnAnon'
              + V'Finalize'
              + V'Paror' + V'Parand' + V'_Watching'
              + V'_Pause'
              + V'Async' + V'_Thread' + V'_Isr' + V'Atomic'
              + V'_DoPre'
              + V'_Lua'

    --, _C = '/******/' * (P(1)-'/******/')^0 * '/******/'
    , _C      = m.Cg(V'_CSEP','mark') *
                    (P(1)-V'_CEND')^0 *
                V'_CEND'
    , _CSEP = '/***' * (1-P'***/')^0 * '***/'
    , _CEND = m.Cmt(C(V'_CSEP') * m.Cb'mark',
                    function (s,i,a,b) return a == b end)

    , __SPACES = (('\n' * (V'__comm'+S'\t\n\r ')^0 *
                    '#' * (P(1)-'\n')^0)
                + ('//' * (P(1)-'\n')^0)
                + S'\t\n\r '
                + V'__comm'
                )^0

    , __comm    = '/' * m.Cg(P'*'^1,'comm') * (P(1)-V'__commcmp')^0 * 
                    V'__commcl'
                    / function () end
    , __commcl  = C(P'*'^1) * '/'
    , __commcmp = m.Cmt(V'__commcl' * m.Cb'comm',
                    function (s,i,a,b) return a == b end)

}

function err ()
    local x = (ERR_i<LST_i) and 'before' or 'after'
--DBG(LST_i, ERR_i, ERR_msg, _I2L[LST_i], I2TK[LST_i])
    local file, line = unpack(LINES.i2l[LST_i])
    return 'ERR : '..file..
              ' : line '..line..
              ' : '..x..' `'..(I2TK[LST_i] or '?').."´"..
              ' : '..ERR_msg
end

if RUNTESTS then
    assert(m.P(GG):match(OPTS.source), err())
else
    if not m.P(GG):match(OPTS.source) then
             -- TODO: match only in ast.lua?
        DBG(err())
        os.exit(1)
    end
end
