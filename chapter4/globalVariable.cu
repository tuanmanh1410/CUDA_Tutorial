#include <cuda_runtime.h>
#include <stdio.h>

// define the global variable devData
__device__ float devData;

__global__ void checkGlobalVariable(){
    // display the original value
    printf("Device: the value of the global variable is %f\n",devData);
    // alter the value
    devData += 2.0f;
    }

int main(void){
    // initialize the global variable
    float value = 3.14f;
    /*
    Attention: You cannot use 
        cudaMemcpy(&devData,&value,sizeof(float),cudaMemcpyHostToDevice)
    To copy value from host to device on devData.
    */
    cudaMemcpyToSymbol(devData,&value,sizeof(float));
    printf("Host: copied %f to the global variable\n",value);

    // invoke the kernel
    checkGlobalVariable<<<1,1>>>();

    // copy the global variable back to the host
    cudaMemcpyFromSymbol(&value,devData,sizeof(float));
    printf("Host: the value changed by the kernel to %f\n",value);

    cudaDeviceReset();
    return EXIT_SUCCESS;
    }

