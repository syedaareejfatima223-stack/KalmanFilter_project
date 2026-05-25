#include <stdio.h>
#include <stdlib.h>

// Function prototypes from assembly
extern void ekf_update();
extern void ekf_predict();
extern void matvec_vec(double *out, double *mat, double *vec, int n);

int main() {
    int N = 276;
    size_t align = 64;
    // Section 6: Ensure size is a multiple of alignment
    size_t vec_size = (N * sizeof(double) + 63) & ~63;
    size_t mat_size = (N * N * sizeof(double) + 63) & ~63;

    double *x = (double*)aligned_alloc(align, vec_size);
    double *A = (double*)aligned_alloc(align, mat_size);
    double *y = (double*)aligned_alloc(align, vec_size);

    if (x == NULL || A == NULL || y == NULL) {
        printf("Memory allocation failed!\n");
        return 1;
    }

    printf("=== Milestone 4 Kalman Filter (Vectorized) ===\n");
    
    // Example call to your vectorized math
    matvec_vec(y, A, x, N);
    
    // Call EKF functions
    ekf_predict();
    ekf_update();

    printf("Execution completed successfully.\n");

    free(x); free(A); free(y);
    return 0;
}
