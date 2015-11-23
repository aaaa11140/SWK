#include <iostream>
#include <fstream>
#include <vector>
#include <stdlib.h>
#include <stdio.h>
#include <algorithm>
#include <set>
#include <list>
#include <cuda.h>
#include <cuda_runtime.h>
#include <iomanip>
using namespace std;
__global__ void temp1(int *x,int *y,int *z){
    int thId = threadIdx.x;
    z[thId]=x[thId]+y[thId];
    z[thId]=100;
    __syncthreads();
}
int main()
{
    cudaSetDevice(0);
    cudaDeviceReset();

int *x_d,*y_d,*z_d,*x,*y,*z;
x=(int*)malloc(sizeof(int));
y=(int*)malloc(sizeof(int));
z=(int*)malloc(sizeof(int));
*x=1;
*y=2;
cudaMalloc((void**)&x_d, sizeof(int));
cudaMalloc((void**)&y_d, sizeof(int));
cudaMalloc((void**)&z_d, sizeof(int));
cudaMemcpy(x_d, x, sizeof(int),  cudaMemcpyHostToDevice);
cudaMemcpy(y_d, y, sizeof(int),  cudaMemcpyHostToDevice);
temp1<<<1,1>>>(x_d,y_d,z_d);
cout<<"result="<<*z<<endl;
cudaMemcpy(z, z_d, sizeof(int),  cudaMemcpyDeviceToHost);
cudaDeviceSynchronize();
cout<<"result="<<*z<<endl;
}
