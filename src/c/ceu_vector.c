#include <stdlib.h>     /* NULL */
#include <string.h>     /* memcpy */

typedef struct {
    usize max;
    usize len;
    usize unit;
    u8    is_dyn:     1;
    u8    is_freezed: 1;
    byte* buf;
} tceu_vector;

#define ceu_vector_buf_len(vec)           ((vec)->len * (vec)->unit)
#define ceu_vector_buf_get(vec,idx)       (&(vec)->buf[(idx)*(vec)->unit])
#define ceu_vector_buf_set(vec,idx,buf,n) {                             \
    ceu_callback_assert_msg_ex(((vec)->len*(vec)->unit) >= ((idx)+(n)), \
                               "ccess out of bounds",                   \
                               __FILE__, __LINE__);                     \
    memcpy(ceu_vector_buf_get((vec),(idx)),(buf),(n));                  \
}

#define ceu_vector_setlen(a,b,c) ceu_vector_setlen_ex(a,b,c,__FILE__,__LINE__)
#define ceu_vector_geti(a,b)     ceu_vector_geti_ex(a,b,__FILE__,__LINE__)

void  ceu_vector_init         (tceu_vector* vector, usize max, bool is_dyn,
                               usize unit, byte* buf);
byte* ceu_vector_setmax       (tceu_vector* vector, usize len, bool freeze);
int   ceu_vector_setlen_could (tceu_vector* vector, usize len, bool grow);
void  ceu_vector_setlen_ex    (tceu_vector* vector, usize len, bool grow,
                               const char* file, u32 line);
byte* ceu_vector_geti_ex      (tceu_vector* vector, usize idx,
                               const char* file, u32 line);

#if 0
char* ceu_vector_tochar (tceu_vector* vector);
#endif

void ceu_vector_init (tceu_vector* vector, usize max, bool is_dyn, usize unit, byte* buf) {
    vector->len        = 0;
    vector->max        = max;
    vector->unit       = unit;
    vector->is_dyn     = is_dyn;
    vector->is_freezed = 0;
    vector->buf        = buf;

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[0] = '\0';
    }
}

byte* ceu_vector_setmax (tceu_vector* vector, usize len, bool freeze) {
    ceu_dbg_assert(vector->is_dyn);

    if (len == 0) {
        /* free */
        if (vector->buf != NULL) {
            vector->max = 0;
            ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, vector->buf, 0);
            vector->buf = NULL;
        }
    } else {
        vector->max = len;
        vector->buf = (byte*) ceu_callback_ptr_size(
                                CEU_CALLBACK_REALLOC,
                                vector->buf,
                                len*vector->unit + 1    /* [STRING] +1 */
                              ).value.ptr;
    }

    if (freeze) {
        vector->is_freezed = 1;
    }

    return vector->buf;
}

int ceu_vector_setlen_could (tceu_vector* vector, usize len, bool grow)
{
    /* must fit w/o growing */
    if (!grow) {
        if (len > vector->len) {
            return 0;
        }
    }

    /* fixed size */
    if (!vector->is_dyn || vector->is_freezed) {
        if (len > vector->max) {
            return 0;
        }

    /* variable size */
    } else {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
        } else {
            /* grow vector */
            if (ceu_vector_setmax(vector,len,0) == NULL) {
                if (len != 0) {
                    return 0;
                }
            }
        }
    }

    return 1;
}

void ceu_vector_setlen_ex (tceu_vector* vector, usize len, bool grow,
                           const char* file, u32 line)
{
    /* must fit w/o growing */
    if (!grow) {
        ceu_callback_assert_msg_ex(len <= vector->len, "access out of bounds",
                             file, line);
    }

    /* fixed size */
    if (!vector->is_dyn || vector->is_freezed) {
        ceu_callback_assert_msg_ex(len <= vector->max, "access out of bounds",
                             file, line);

    /* variable size */
    } else {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
/* TODO: shrink memory */
        } else {
            /* grow vector */
            if (ceu_vector_setmax(vector,len,0) == NULL) {
                ceu_callback_assert_msg_ex(len==0, "access out of bounds",
                                     file, line);
            }
        }
    }

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[len*vector->unit] = '\0';
    }
    vector->len = len;
}

byte* ceu_vector_geti_ex (tceu_vector* vector, usize idx, const char* file, u32 line) {
    ceu_callback_assert_msg_ex(idx < vector->len, "access out of bounds", file, line);
    return ceu_vector_buf_get(vector, idx);
}

#if 0
char* ceu_vector_tochar (tceu_vector* vector) {
    if (vector->buf == NULL) {
        return "";
    } else {
        return (char*)vector->buf;
    }
}
#endif
