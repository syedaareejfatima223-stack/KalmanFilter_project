/* --- memory_helper.c --- */
#include <stdio.h>
#include <stdlib.h>

// Use posix_memalign for 64-byte (Cache-line) alignment
void* aligned_alloc_64(size_t size) {
    void* ptr;
    if (posix_memalign(&ptr, 64, size) != 0) {
        return NULL;
    }
    return ptr;
}

// Example check required by Section 6
void check_alignment(void* ptr, const char* name) {
    if (((uintptr_t)ptr % 8) == 0) {
        printf("[OK] %s is 8-byte aligned.\n", name);
    } else {
        printf("[ERROR] %s is NOT 8-byte aligned!\n", name);
    }
}

/* 
   In your main() function:
   double *F = aligned_alloc_64(276 * 276 * sizeof(double));
   check_alignment(F, "Matrix F");
   vector_mat_vec_mul(y, F, x, 276); 
*/
