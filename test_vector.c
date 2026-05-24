#include <stdio.h>
#include <stdlib.h>

extern void vector_mat_vec_mul(double *out_y, double *mat_A, double *vec_x, int N);

int main() {
    int N = 276;
    // Correctly aligned memory allocation
    size_t size_A = (N * N * sizeof(double) + 63) & ~63;
    size_t size_vec = (N * sizeof(double) + 63) & ~63;

    double *A = (double*)aligned_alloc(64, size_A);
    double *x = (double*)aligned_alloc(64, size_vec);
    double *y = (double*)aligned_alloc(64, size_vec);

    if (A == NULL || x == NULL || y == NULL) {
        printf("Allocation failed!\n");
        return 1;
    }

    for(int i=0; i<N*N; i++) A[i] = 1.0;
    for(int i=0; i<N; i++) x[i] = 2.0;

    printf("Starting Vectorized Matrix-Vector Multiplication...\n");
    
    vector_mat_vec_mul(y, A, x, N);

    printf("Result y[0]: %f (Expected: 552.000000)\n", y[0]);

    free(A); free(x); free(y);
    return 0;
}
