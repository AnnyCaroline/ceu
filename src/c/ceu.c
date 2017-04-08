#define CEU_FEATURES_LONGJMP

=== FEATURES ===        /* CEU_FEATURES */

#include <stddef.h>     /* offsetof */
#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset, strlen */
#ifdef CEU_TESTS
#include <stdio.h>
#endif

#ifdef CEU_FEATURES_LONGJMP
#include <setjmp.h>
#endif

#ifdef CEU_FEATURES_LUA
#include <lua5.3/lua.h>
#include <lua5.3/lauxlib.h>
#include <lua5.3/lualib.h>
#endif

#define S8_MIN   -127
#define S8_MAX    127
#define U8_MAX    255

#define S16_MIN  -32767
#define S16_MAX   32767
#define U16_MAX   65535

#define S32_MIN  -2147483647
#define S32_MAX   2147483647
#define U32_MAX   4294967295

#define S64_MIN  -9223372036854775807
#define S64_MAX   9223372036854775807
#define U64_MAX   18446744073709551615

#define CEU_SEQ_MAX U16_MAX
/* TODO */

typedef u16 tceu_nevt;   /* TODO */
typedef u16 tceu_nseq;   /* TODO */
typedef === TCEU_NTRL === tceu_ntrl;
typedef === TCEU_NLBL === tceu_nlbl;

#define CEU_API
CEU_API void ceu_start (void);
CEU_API void ceu_stop  (void);
CEU_API void ceu_input (tceu_nevt evt_id, void* evt_params);
CEU_API int  ceu_loop  (void);

struct tceu_stk;
struct tceu_code_mem;
struct tceu_pool_pak;
struct tceu_evt_occ;

typedef struct tceu_evt {
    tceu_nevt id;
    union {
        void* mem;                   /* CEU_INPUT__PROPAGATE_CODE, CEU_EVENT__MIN */
        struct tceu_pool_pak* pak;   /* CEU_INPUT__PROPAGATE_POOL */
    };
} tceu_evt;

typedef struct tceu_evt_range {
    struct tceu_code_mem* mem;
    tceu_ntrl             trl0;
    tceu_ntrl             trlF;
} tceu_evt_range;

typedef struct tceu_evt_occ {
    tceu_evt       evt;
    tceu_nseq      seq;
    void*          params;
    tceu_evt_range range;
} tceu_evt_occ;

typedef struct tceu_trl {
    struct {
        tceu_evt evt;
        union {
            /* NORMAL, CEU_EVENT__MIN */
            struct {
                tceu_nlbl lbl;
                union {
                    tceu_nseq seq;              /* NORMAL */
                    tceu_evt_range clr_range;   /* CEU_INPUT__CLEAR */
                };
            };

            /* CEU_INPUT__PAUSE_BLOCK */
            struct {
                tceu_evt  pse_evt;
                tceu_ntrl pse_skip;
                u8        pse_paused;
            };
        };
    };
} tceu_trl;

typedef struct tceu_code_mem {
    struct tceu_pool_pak* pak;
    struct tceu_code_mem* up_mem;
    tceu_ntrl  up_trl;
    u8         depth;
#ifdef CEU_FEATURES_LUA
    lua_State* lua;
#endif
    tceu_ntrl  trails_n;
    tceu_trl   _trails[0];
} tceu_code_mem;

typedef struct tceu_code_mem_dyn {
    struct tceu_code_mem_dyn* prv;
    struct tceu_code_mem_dyn* nxt;
    u8 is_alive: 1;
    tceu_code_mem mem[0];   /* actual tceu_code_mem is in sequence */
} tceu_code_mem_dyn;

typedef struct tceu_pool_pak {
    tceu_pool         pool;
    tceu_code_mem_dyn first;
    tceu_code_mem*    up_mem;
    tceu_ntrl         up_trl;
    u8                n_traversing;
} tceu_pool_pak;

static tceu_evt* CEU_OPTION_EVT (tceu_evt* alias, const char* file, int line) {
    ceu_callback_assert_msg_ex(alias != NULL, "value is not set", file, line);
    return alias;
}

#ifdef CEU_FEATURES_THREAD
typedef struct tceu_threads_data {
    CEU_THREADS_T id;
    u8 has_started:    1;
    u8 has_terminated: 1;
    u8 has_aborted:    1;
    u8 has_notified:   1;
    struct tceu_threads_data* nxt;
} tceu_threads_data;

typedef struct {
    tceu_code_mem*     mem;
    tceu_threads_data* thread;
} tceu_threads_param;
#endif

#ifdef CEU_FEATURES_ISR
typedef struct tceu_evt_id_params {
    tceu_nevt id;
    void*     params;
} tceu_evt_id_params;

typedef struct tceu_isr {
    void (*fun)(tceu_code_mem*);
    tceu_code_mem*     mem;
    tceu_evt_id_params evt;
} tceu_isr;

#endif

/*****************************************************************************/

/* NATIVE_PRE */
=== NATIVE_PRE ===

/* EVENTS_ENUM */

enum {
    /* non-emitable */
    CEU_INPUT__NONE = 0,
    CEU_INPUT__FINALIZE,
    CEU_INPUT__PAUSE_BLOCK,
    CEU_INPUT__PROPAGATE_CODE,
    CEU_INPUT__PROPAGATE_POOL,

    /* emitable */
    CEU_INPUT__CLEAR,           /* 5 */
    CEU_INPUT__CODE_TERMINATED,
    CEU_INPUT__PAUSE,
    CEU_INPUT__RESUME,
CEU_INPUT__SEQ,
    CEU_INPUT__ASYNC,
    CEU_INPUT__THREAD,
    CEU_INPUT__WCLOCK,
    === EXTS_ENUM_INPUT ===

CEU_EVENT__MIN,
    === EVTS_ENUM ===
};

enum {
    CEU_OUTPUT__NONE = 0,
    === EXTS_ENUM_OUTPUT ===
};

/* ISRS_DEFINES */

=== ISRS_DEFINES ===

/* EVENTS_DEFINES */

=== EXTS_DEFINES_INPUT_OUTPUT ===

/* DATAS_HIERS */

typedef s16 tceu_ndata;  /* TODO */

=== DATAS_HIERS ===

static int ceu_data_is (tceu_ndata* supers, tceu_ndata me, tceu_ndata cmp) {
    return (me==cmp || (me!=0 && ceu_data_is(supers,supers[me],cmp)));
}

static void* ceu_data_as (tceu_ndata* supers, tceu_ndata* me, tceu_ndata cmp,
                          const char* file, int line) {
    ceu_callback_assert_msg_ex(ceu_data_is(supers, *me, cmp),
                               "invalid cast `as´", file, line);
    return me;
}

/* DATAS_MEMS */

=== DATAS_MEMS ===
=== DATAS_MEMS_CASTS ===

/*****************************************************************************/

=== CODES_MEMS ===
#if 0
=== CODES_ARGS ===
#endif

=== EXTS_TYPES ===
=== EVTS_TYPES ===

enum {
    CEU_LABEL_NONE = 0,
    === LABELS ===
};

typedef struct tceu_stk {
    u8               is_alive : 1;
    u8               is_base  : 1;
    struct tceu_stk* down;
    tceu_evt_range   range;
} tceu_stk;

typedef struct tceu_jmp {
    tceu_nlbl      lbl;
    tceu_code_mem* mem;
    tceu_ntrl      trl;
} tceu_jmp;

typedef struct tceu_app {
    bool end_ok;
    int  end_val;

    /* LONGJMP */
#ifdef CEU_FEATURES_LONGJMP
    tceu_jmp jmp;
#endif

    /* SEQ */
    tceu_nseq seq;
    tceu_nseq seq_base;

    /* ASYNC */
    bool async_pending;

    /* WCLOCK */
    s32 wclk_late;
    s32 wclk_min_set;
    s32 wclk_min_cmp;

#ifdef CEU_FEATURES_THREAD
    CEU_THREADS_MUTEX_T threads_mutex;
    tceu_threads_data*  threads_head;   /* linked list of threads alive */
    tceu_threads_data** cur_;           /* TODO: HACK_6 "gc" mutable iterator */
#endif

    tceu_code_mem_ROOT root;
} tceu_app;

static tceu_app CEU_APP;

#ifdef CEU_FEATURES_LONGJMP
#define CEU_LONGJMP_SET(me,_lbl)                            \
        /*fprintf(stderr, "set?\n");*/                      \
    if (!(me)->is_alive) {                                  \
        /*fprintf(stderr, "set %d\n", __LINE__);*/          \
        ceu_dbg_assert(CEU_APP.jmp.lbl==CEU_LABEL_NONE);    \
        CEU_APP.jmp.lbl = _lbl;                             \
        CEU_APP.jmp.mem = _ceu_mem;                         \
        CEU_APP.jmp.trl = _ceu_trlK;                        \
        return;                                             \
case _lbl:;                                                 \
        /*fprintf(stderr, "cnt\n");*/                       \
        /* continue from here */                            \
    }

#define CEU_LONGJMP_JMP(me)                                 \
        /*fprintf(stderr, "jmp? %d\n", __LINE__);*/         \
    if (!(me)->is_alive) {                                  \
        /*fprintf(stderr, "dead %d\n", __LINE__);*/         \
        if (CEU_APP.jmp.lbl == CEU_LABEL_NONE) {            \
            return;                                         \
        }                                                   \
        if (!(me)->down->is_alive) {                        \
            /*fprintf(stderr, "<<<\n");*/                   \
            return;                                         \
        } else {                                            \
            tceu_nlbl __ceu_lbl = CEU_APP.jmp.lbl;          \
            /*fprintf(stderr, "jmp\n");*/                   \
            CEU_APP.jmp.lbl = CEU_LABEL_NONE;               \
            RETURN_CEU_LBL(NULL,(me)->down,CEU_APP.jmp.mem,CEU_APP.jmp.trl,__ceu_lbl); \
        }                                                   \
    } else {                                                \
        /* continue */                                      \
    }

#define CEU_LONGJMP_JMP_(me)                                \
        /*fprintf(stderr, "jmp? %d\n", __LINE__);*/         \
    if (!(me)->is_alive) {                                  \
        /*fprintf(stderr, "dead %d\n", __LINE__);*/         \
        if (CEU_APP.jmp.lbl == CEU_LABEL_NONE) {            \
            return;                                         \
        }                                                   \
        if (!(me)->down->is_alive) {                        \
            /*fprintf(stderr, "<<<\n");*/                   \
            return;                                         \
        } else {                                            \
            tceu_nlbl __ceu_lbl = CEU_APP.jmp.lbl;          \
            /*fprintf(stderr, "jmp\n");*/                   \
            CEU_APP.jmp.lbl = CEU_LABEL_NONE;               \
            return ceu_lbl(NULL,(me)->down,CEU_APP.jmp.mem,CEU_APP.jmp.trl,__ceu_lbl); \
        }                                                   \
    } else {                                                \
        /* continue */                                      \
    }
#endif

/*****************************************************************************/

static tceu_code_mem* ceu_outer (tceu_code_mem* mem, u8 n) {
    for (; mem->depth!=n; mem=mem->up_mem);
    return mem;
}

static int ceu_mem_is_child (tceu_code_mem* me, tceu_code_mem* par_mem,
                             tceu_ntrl par_trl1, tceu_ntrl par_trl2)
{
    if (me == par_mem) {
        return (par_trl1==0 && par_trl2==me->trails_n-1) ? 1 : 0;
    }

    tceu_code_mem* cur_mem;
    for (cur_mem=me; cur_mem!=NULL; cur_mem=cur_mem->up_mem) {
        if (cur_mem->up_mem == par_mem) {
            if (cur_mem->up_trl>=par_trl1 && cur_mem->up_trl<=par_trl2) {
                return 2;
            }
        }
    }
    return 0;
}

static void ceu_stack_clear (tceu_stk* stk, tceu_code_mem* mem,
                             tceu_ntrl trl0, tceu_ntrl trlF) {
    for (; stk!=NULL; stk=stk->down) {
        if (!stk->is_alive || stk->is_base) {
            continue;
        }
        if (stk->range.mem != mem) {
            /* check if "stk->range.mem" is child of "mem" in between "[trl0,trlF]" */
            if (ceu_mem_is_child(stk->range.mem, mem, trl0, trlF)) {
                stk->is_alive = 0;
            }
        } else if (trl0<=stk->range.trl0 && stk->range.trlF<=trlF) {  /* [trl0,trlF] */
            stk->is_alive = 0;
        }
    }
}

#if 0
static void ceu_stack_dump (tceu_stk* stk) {
    for (; stk!=&CEU_STK_BASE; stk=stk->down) {
        printf("stk=%p mem=%p\n", stk, stk->mem);
    }
}
#endif

/*****************************************************************************/

#define CEU_WCLOCK_INACTIVE INT32_MAX

static int ceu_wclock (s32 dt, s32* set, s32* sub)
{
    s32 t;          /* expiring time of track to calculate */
    int ret = 0;    /* if track expired (only for "sub") */

    /* SET */
    if (set != NULL) {
        t = dt - CEU_APP.wclk_late;
        *set = t;

    /* SUB */
    } else {
        t = *sub;
        if ((t > CEU_APP.wclk_min_cmp) || (t > dt)) {
            *sub -= dt;    /* don't expire yet */
            t = *sub;
        } else {
            ret = 1;    /* single "true" return */
        }
    }

    /* didn't awake, but can be the smallest wclk */
    if ( (!ret) && (CEU_APP.wclk_min_set > t) ) {
        CEU_APP.wclk_min_set = t;
        ceu_callback_num_ptr(CEU_CALLBACK_WCLOCK_MIN, t, NULL);
    }

    return ret;
}

/*****************************************************************************/

void ceu_code_mem_dyn_free (tceu_pool* pool, tceu_code_mem_dyn* cur) {
    cur->nxt->prv = cur->prv;
    cur->prv->nxt = cur->nxt;

    if (pool->queue == NULL) {
        /* dynamic pool */
        ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, cur, 0);
    } else {
        /* static pool */
        ceu_pool_free(pool, (byte*)cur);
    }
}

void ceu_code_mem_dyn_remove (tceu_pool* pool, tceu_code_mem_dyn* cur) {
    cur->is_alive = 0;

    if (cur->mem[0].pak->n_traversing == 0) {
        ceu_code_mem_dyn_free(pool, cur);
    }
}

void ceu_code_mem_dyn_gc (tceu_pool_pak* pak) {
    if (pak->n_traversing == 0) {
        /* TODO-OPT: one element killing another is unlikely:
                     set bit in pool when this happens and only
                     traverses in this case */
        tceu_code_mem_dyn* cur = pak->first.nxt;
        while (cur != &pak->first) {
            tceu_code_mem_dyn* nxt = cur->nxt;
            if (!cur->is_alive) {
                ceu_code_mem_dyn_free(&pak->pool, cur);
            }
            cur = nxt;
        }
    }
}

/*****************************************************************************/

#ifdef CEU_FEATURES_LUA
int ceu_lua_atpanic (lua_State* lua) {
    const char* msg = lua_tostring(lua,-1);
    ceu_dbg_assert(msg != NULL);
    ceu_callback_assert_msg(0, msg);
    return 0;
}
#endif

/*****************************************************************************/

static void ceu_bcast (tceu_evt_occ* occ, tceu_stk* stk, bool is_prim);
static void ceu_lbl (tceu_evt_occ* _ceu_occ, tceu_stk* _ceu_stk,
                     tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl);

=== NATIVE_POS ===

=== CODES_WRAPPERS ===

=== ISRS ===

=== THREADS ===

/*****************************************************************************/

#ifdef CEU_FEATURES_THREAD
int ceu_threads_gc (int force_join) {
    int n_alive = 0;
    CEU_APP.cur_ = &CEU_APP.threads_head;
    tceu_threads_data*  head  = *CEU_APP.cur_;
    while (head != NULL) {
        tceu_threads_data** nxt_ = &head->nxt;
        if (head->has_terminated || head->has_aborted)
        {
            if (!head->has_notified) {
                ceu_input(CEU_INPUT__THREAD, &head->id);
                head->has_notified = 1;
            }

            /* remove from list if rejoined */
            {
                int has_joined;
                if (force_join || head->has_terminated) {
                    CEU_THREADS_JOIN(head->id);
                    has_joined = 1;
                } else {
                    /* possible with "CANCEL" which prevents setting "has_terminated" */
                    has_joined = CEU_THREADS_JOIN_TRY(head->id);
                }
                if (has_joined) {
                    *CEU_APP.cur_ = head->nxt;
                    nxt_ = CEU_APP.cur_;
                    ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, head, 0);
                }
            }
        }
        else
        {
            n_alive++;
        }
        CEU_APP.cur_ = nxt_;
        head  = *CEU_APP.cur_;
    }
    return n_alive;
}
#endif

/*****************************************************************************/

void ceu_input_one (tceu_nevt evt_id, void* evt_params, tceu_stk* stk);

#define RETURN_CEU_LBL(_1,_2,_3,_4,_5)  \
    _ceu_occ  = _1;                     \
    _ceu_stk  = _2;                     \
    _ceu_mem  = _3;                     \
    _ceu_trlK = _4;                     \
    _ceu_lbl  = _5;                     \
    goto _CEU_LBL_;

static void ceu_lbl (tceu_evt_occ* _ceu_occ, tceu_stk* _ceu_stk,
                     tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl)
{
_CEU_LBL_:
    switch (_ceu_lbl) {
        CEU_LABEL_NONE:
            break;
        === CODES ===
    }
}

#if defined(_CEU_DEBUG)
#define _CEU_DEBUG
static int xxx = 0;
#endif

static void ceu_bcast (tceu_evt_occ* occ, tceu_stk* stk, bool is_prim)
{
    tceu_ntrl trlK;
    tceu_trl* trl;
    tceu_evt_range range = occ->range;

    if (is_prim && occ->evt.id>CEU_INPUT__SEQ) {
        ceu_callback_assert_msg(((tceu_nseq)(CEU_APP.seq+1)) != CEU_APP.seq_base,
                                "too many internal reactions");
        CEU_APP.seq++;
    }

    tceu_stk _stk = { 1, 0, stk, range }; /* maybe nested bcast aborts it */

    /* MARK TRAILS TO EXECUTE */

#ifdef _CEU_DEBUG
for (int i=0; i<xxx; i++) {
    fprintf(stderr, " ");
}
fprintf(stderr, ">>> %d/%p, SEQ=%d [%p] %d->%d\n", occ->evt.id, occ->evt.mem, occ->seq,
                                           range.mem, range.trl0, range.trlF);
xxx += 4;
#endif

    /* CLEAR: inverse execution order */
    tceu_ntrl trl0 = range.trl0;
    tceu_ntrl trlF = range.trlF;
    if (occ->evt.id == CEU_INPUT__CLEAR) {
        tceu_ntrl tmp = trl0;
        trl0 = trlF;
        trlF = tmp;
    }

#ifdef CEU_TESTS
    _ceu_tests_bcasts_++;
#endif

    for (trlK=trl0, trl=&range.mem->_trails[trlK]; ;)
    {
#ifdef CEU_TESTS
        _ceu_tests_trails_visited_++;
#endif

#ifdef _CEU_DEBUG
for (int i=0; i<xxx; i++) {
    fprintf(stderr, " ");
}
fprintf(stderr, "??? trlK=%d, evt=%d, seq=%d\n", trlK, trl->evt.id, trl->seq);
#endif

        /* special trails: propagate, skip paused */

        switch (trl->evt.id)
        {
            /* propagate "occ" to nested "code/pool" */
            case CEU_INPUT__PROPAGATE_CODE: {
#if 0
                // TODO: simple optimization that could be done
                //          - do it also for POOL?
                if (occ->evt.id==CEU_INPUT__CODE_TERMINATED && occ->params==trl->evt.mem ) {
                    // dont propagate when I am terminating
                } else
#endif
                {
                    tceu_evt_range _range = {
                        (tceu_code_mem*)trl->evt.mem,
                        0,
                        (tceu_ntrl)(((tceu_code_mem*)trl->evt.mem)->trails_n-1)
                    };
                    occ->range = _range;
                    ceu_bcast(occ, &_stk, 0);
#ifdef CEU_FEATURES_LONGJMP
                    CEU_LONGJMP_JMP_((&_stk));
#else
                    if (!_stk.is_alive) {
ceu_dbg_assert(0);
                        goto _CEU_BREAK_;
                    }
#endif
                }
                break;
            }
            case CEU_INPUT__PROPAGATE_POOL: {
                ceu_dbg_assert(trl->evt.pak->n_traversing < 255);
                trl->evt.pak->n_traversing++;
                tceu_code_mem_dyn* cur = trl->evt.pak->first.nxt;
#if 0
printf(">>> BCAST[%p]:\n", trl->pool_first);
printf(">>> BCAST[%p]: %p / %p\n", trl->pool_first, cur, &cur->mem[0]);
#endif
                while (cur != &trl->evt.pak->first) {
                    if (cur->is_alive) {
                        tceu_evt_range _range = { &cur->mem[0],
                                                  0, (tceu_ntrl)((&cur->mem[0])->trails_n-1) };
                        occ->range = _range;
                        tceu_stk _stk = { 1, 0, stk,
                                          {cur->mem[0].up_mem,cur->mem[0].up_trl,cur->mem[0].up_trl} };
                        ceu_bcast(occ, &_stk, 0);
#ifdef CEU_FEATURES_LONGJMP
                        CEU_LONGJMP_JMP_((&_stk));
#else
                        if (!_stk.is_alive) {
ceu_dbg_assert(0);
                            goto _CEU_BREAK_;
                        }
#endif
                    }
                    cur = cur->nxt;
                }
                trl->evt.pak->n_traversing--;
                ceu_code_mem_dyn_gc(trl->evt.pak);
                break;
            }

            /* skip "paused" blocks || set "paused" block */
            case CEU_INPUT__PAUSE_BLOCK: {
                u8 was_paused = trl->pse_paused;
                if (occ->evt.id==trl->pse_evt.id &&
                    (occ->evt.id<CEU_EVENT__MIN || occ->evt.mem==trl->pse_evt.mem))
                {
                    if (*((u8*)occ->params) != trl->pse_paused) {
                        trl->pse_paused = *((u8*)occ->params);

                        if (trl->pse_paused) {
                            tceu_evt_occ occ2 = { {CEU_INPUT__PAUSE,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        } else {
                            tceu_evt_occ occ2 = { {CEU_INPUT__RESUME,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        }
                        ceu_dbg_assert(_stk.is_alive);
                    }
                }
                /* don't skip if pausing now */
                if (was_paused && occ->evt.id!=CEU_INPUT__CLEAR) {
                                  /* also don't skip on CLEAR (going reverse) */
                    trlK += trl->pse_skip;
                    trl  += trl->pse_skip;
                    goto _CEU_AWAKE_NO_;
                }
                break;
            }
        }

        /* normal trails: check if awakes */

        if (occ->evt.id == CEU_INPUT__CLEAR) {
            tceu_nevt trl_evt_id = trl->evt.id;
            trl->evt.id = CEU_INPUT__NONE;
            if (trl_evt_id == CEU_INPUT__FINALIZE) {
                /* FINALIZE awakes now on "mark" */
                ceu_lbl(occ, &_stk, range.mem, trlK, trl->lbl);
            }
        } else if (occ->evt.id==CEU_INPUT__CODE_TERMINATED &&
            (trl->evt.id==CEU_INPUT__CODE_TERMINATED || trl->evt.id==CEU_INPUT__PROPAGATE_CODE))
        {
            if (trl->evt.mem == occ->evt.mem) {
                goto _CEU_AWAKE_YES_;
            }
        } else if (trl->evt.id == occ->evt.id) {
            if (occ->evt.id==CEU_INPUT__PAUSE || occ->evt.id==CEU_INPUT__RESUME) {
                goto _CEU_AWAKE_YES_;
            }
            if (((tceu_nseq)(trl->seq-CEU_APP.seq_base)) >
                ((tceu_nseq)(occ->seq-CEU_APP.seq_base))) {
                goto _CEU_AWAKE_NO_;
            }
            if (trl->evt.id>CEU_EVENT__MIN) {
                if (trl->evt.mem == occ->evt.mem) {
                    goto _CEU_AWAKE_YES_;   /* internal event matches "mem" */
                }
            } else {
                if (occ->evt.id != CEU_INPUT__NONE) {
                    goto _CEU_AWAKE_YES_;       /* external event matches */
                }
            }
        }

        goto _CEU_AWAKE_NO_;

_CEU_AWAKE_YES_:
#ifdef _CEU_DEBUG
for (int i=0; i<xxx+4; i++) {
    fprintf(stderr, " ");
}
fprintf(stderr, "+++ %d\n", trl->lbl);
#endif

        trl->evt.id = CEU_INPUT__NONE;
        ceu_lbl(occ, &_stk, range.mem, trlK, trl->lbl);
#ifdef CEU_FEATURES_LONGJMP
        CEU_LONGJMP_JMP_((&_stk));
#else
        if (!_stk.is_alive) {
ceu_dbg_assert(0);
#ifdef _CEU_DEBUG
fprintf(stderr, "break\n");
#endif
            goto _CEU_BREAK_;
        }
#endif

_CEU_AWAKE_NO_:
        if ((trl->evt.id > CEU_INPUT__SEQ) && (occ->seq == ((tceu_nseq)(CEU_APP.seq_base+0)))) {
            trl->seq = CEU_APP.seq_base;
        }

        if (trlK == trlF) {
            break;
        } else if (occ->evt.id == CEU_INPUT__CLEAR) {
            trlK--; trl--;
        } else {
            trlK++; trl++;
        }
    }
_CEU_BREAK_:;

    /*occ->range = range;*/

#ifdef _CEU_DEBUG
xxx -= 4;
for (int i=0; i<xxx; i++) {
    fprintf(stderr, " ");
}
fprintf(stderr, "<<< %d [%p] %d->%d\n", occ->evt.id, range.mem, range.trl0, range.trlF);
#endif
}

void ceu_input_one (tceu_nevt evt_id, void* evt_params, tceu_stk* stk)
{
    CEU_APP.seq_base = CEU_APP.seq;

    if (evt_id == CEU_INPUT__WCLOCK) {
        CEU_APP.wclk_min_cmp = CEU_APP.wclk_min_set;    /* swap "cmp" to last "set" */
        CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;     /* new "set" resets to inactive */
        if (CEU_APP.wclk_min_cmp <= *((s32*)evt_params)) {
            CEU_APP.wclk_late = *((s32*)evt_params) - CEU_APP.wclk_min_cmp;
        }
    }

/* TODO: remove this extra bcast to reset seqs */
#if 1
{
    tceu_stk _stk = { 1, 1, stk,
                     { (tceu_code_mem*)&CEU_APP.root,
                       0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1) } };
    tceu_evt_occ occ = { {CEU_INPUT__NONE,{NULL}}, CEU_APP.seq, evt_params,
                         {(tceu_code_mem*)&CEU_APP.root,
                          0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1)}
                       };
    ceu_bcast(&occ, &_stk, 1);
}
#endif

    tceu_stk _stk = { 1, 1, stk,
                     { (tceu_code_mem*)&CEU_APP.root,
                       0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1) } };
    tceu_evt_occ occ = { {evt_id,{NULL}}, (tceu_nseq)(CEU_APP.seq+1), evt_params,
                         {(tceu_code_mem*)&CEU_APP.root,
                          0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1)}
                       };
    ceu_bcast(&occ, &_stk, 1);
}

CEU_API void ceu_input (tceu_nevt evt_id, void* evt_params)
{
    s32 dt = ceu_callback_void_void(CEU_CALLBACK_WCLOCK_DT).value.num;
    if (dt != CEU_WCLOCK_INACTIVE) {
        ceu_input_one(CEU_INPUT__WCLOCK, &dt, NULL);
    }
    if (evt_id != CEU_INPUT__NONE) {
        ceu_input_one(evt_id, evt_params, NULL);
    }
}

CEU_API void ceu_start (void) {
    ceu_callback_void_void(CEU_CALLBACK_START);

    CEU_APP.end_ok   = 0;

#ifdef CEU_FEATURES_LONGJMP
    CEU_APP.jmp.lbl = CEU_LABEL_NONE;
#endif

    CEU_APP.seq      = 0;
    CEU_APP.seq_base = 0;

    CEU_APP.async_pending = 0;

    CEU_APP.wclk_late = 0;
    CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;
    CEU_APP.wclk_min_cmp = CEU_WCLOCK_INACTIVE;

#ifdef CEU_FEATURES_THREAD
    pthread_mutex_init(&CEU_APP.threads_mutex, NULL);
    CEU_APP.threads_head = NULL;

    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     */
    CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
#endif

    tceu_stk stk = { 1, 1, NULL,
                     { (tceu_code_mem*)&CEU_APP.root,
                       0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1) } };
    ceu_lbl(NULL, &stk, (tceu_code_mem*)&CEU_APP.root, 0, CEU_LABEL_ROOT);
}

CEU_API void ceu_stop (void) {
#ifdef CEU_FEATURES_THREAD
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
    ceu_dbg_assert(ceu_threads_gc(1) == 0); /* wait all terminate/free */
#endif
    ceu_callback_void_void(CEU_CALLBACK_STOP);
}

/*****************************************************************************/

CEU_API int ceu_loop (void)
{
    ceu_start();

    while (!CEU_APP.end_ok) {
        ceu_callback_void_void(CEU_CALLBACK_STEP);
#ifdef CEU_FEATURES_THREAD
        if (CEU_APP.threads_head != NULL) {
            CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
/* TODO: remove this!!! */
            CEU_THREADS_SLEEP(100); /* allow threads to do "atomic" and "terminate" */
            CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
            ceu_threads_gc(0);
        }
#endif
        ceu_input(CEU_INPUT__ASYNC, NULL);
    }

    ceu_stop();

#ifdef CEU_TESTS
    printf("_ceu_tests_bcasts_ = %d\n", _ceu_tests_bcasts_);
    printf("_ceu_tests_trails_visited_ = %d\n", _ceu_tests_trails_visited_);
#endif

    return CEU_APP.end_val;
}
