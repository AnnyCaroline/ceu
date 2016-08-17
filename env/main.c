#include <stdlib.h>
#include <stdio.h>

tceu_callback_ret ceu_callback (int cmd, tceu_callback_arg p1, tceu_callback_arg p2) {
    tceu_callback_ret ret;

#ifdef ceu_callback_env
    ret = ceu_callback_env(cmd, p1, p2);
    if (ret.is_handled) {
        return ret;
    }
#endif

    ret = ceu_callback_go_all(cmd, p1, p2);
    if (ret.is_handled) {
        return ret;
    }

    switch (cmd) {
        case CEU_CALLBACK_ABORT:
            ret.is_handled = 1;
            abort();
        case CEU_CALLBACK_LOG: {
            ret.is_handled = 1;
            switch (p1.num) {
                case 0:
                    printf("%s", (char*)p2.ptr);
                    break;
                case 1:
                    printf("%p", p2.ptr);
                    break;
                case 2:
                    printf("%d", p2.num);
                    break;
            }
            break;
        }
        case CEU_CALLBACK_REALLOC:
#ifdef CEU_TESTS_REALLOC
        {
            static int ceu_tests_realloc = 0;
            if (p2.size == 0) {
                ceu_tests_realloc--;
            } else {
                if (ceu_tests_realloc >= CEU_TESTS_REALLOC) {
                    ret.is_handled = 1;
                    ret.value.ptr = NULL;
                    return ret;
                }
                ceu_tests_realloc++;
            }
        }
#endif
            ret.is_handled = 1;
            ret.value.ptr = realloc(p1.ptr, p2.size);
        default:
            ret.is_handled = 0;
    }
    return ret;
}

int main (int argc, char *argv[])
{
    int ret = ceu_go_all();
    return ret;
}
