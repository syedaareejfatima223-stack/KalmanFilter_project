#include <stdio.h>
#include <stdlib.h>

// Declare the functions from your assembly files
extern void vector_mat_vec_mul(double *out_y, double *mat_A, double *vec_x, int N);

int main() {
    int N = 276;
    // Section 6: Ensure 64-byte alignment for performance
    double *A = (double*)aligned_alloc(64, N * N * sizeof(double));
    double *x = (double*)aligned_alloc(64, N * sizeof(double));
    double *y = (double*)aligned_alloc(64, N * sizeof(double));

    // Initialize with dummy data
    for(int i=0; i<N*N; i++) A[i] = 1.0;
    for(int i=0; i<N; i++) x[i] = 2.0;

    printf("Starting Vectorized Matrix-Vector Multiplication...\n");
    
    // Call the Assembly Function
    vector_mat_vec_mul(y, A, x, N);

    printf("Result y[0]: %f (Expected: 552.000000)\n", y[0]);

    free(A); free(x); free(y);
    return 0;
}
