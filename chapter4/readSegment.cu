#include <cuda_runtime.h>
#include <stdio.h>
#include <sys/time.h>

double seconds(){
    struct timeval tp;
    struct timezone tzp;
    int i = gettimeofday(&tp,&tzp);
    return ((double)tp.tv_sec+(double)tp.tv_usec*1.e-6);
    }

void initialData(float *ip, int size){
    for (int i = 0; i < size; i ++){
        ip[i] =  (float)(rand() & 0xFF)/100.0f;
        }
    return;
    }

void checkResult(float *hostRef, float *gpuRef, const int N){
    double epsilon = 1.0e-8;
    for (int i=0; i < N; i++){
        if(abs(hostRef[i]-gpuRef[i])>epsilon){
            printf("Arrays do not match!\n");
            printf("host %5.2f gpu %5.2f at current %d\n",hostRef[i],gpuRef[i],i);
            break;
            }
        }
    return;
    }

__global__ void readOffset(float *A,float *B,float *C,const int n,int offset){
    // assigned offset value
    unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int k = i + offset;
    if (k<n) C[i] = A[k] + B[k];
    }

void sumArraysOnHost(float *A, float *B, float *C, const int n, int offset){
    for (int idx = offset,k=0; idx < n; idx++, k++){
        C[k] = A[idx] + B[idx];
        }
    }


int main(int argc, char **argv){
    // set up device
    int dev = 0;
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp,dev);
    printf("%s starting reduction at ",argv[0]);
    printf("device %d: %s ",dev,deviceProp.name);
    cudaSetDevice(dev);

    // set up array size
    int nElem = 1 << 20; // total number of elements to reduce
    printf(" with array size %d \n",nElem);
    size_t nBytes = nElem * sizeof(float);

    // set up offset for summary
    int blocksize = 512;
    int offset = 0;

    if (argc > 1) offset = atoi(argv[1]);
    if (argc > 2) offset = atoi(argv[2]);

    // execution configuration
    dim3 block(blocksize,1);
    dim3 grid((nElem+block.x-1)/block.x,1);

    // allocate host mem
    float *h_A = (float *)malloc(nBytes);
    float *h_B = (float *)malloc(nBytes);
    float *hostRef = (float *)malloc(nBytes);
    float *gpuRef = (float *)malloc(nBytes);

    // initialize host array
    initialData(h_A,nElem);
    memcpy(h_B,h_A,nBytes);

    // summary at host side
    sumArraysOnHost(h_A,h_B,hostRef,nElem,offset);

    // allocate device memory
    float *d_A, *d_B, *d_C;
    cudaMalloc((float **)&d_A,nBytes);
    cudaMalloc((float **)&d_B,nBytes);
    cudaMalloc((float **)&d_C,nBytes);

    // copy data from host to device
    cudaMemcpy(d_A,h_A,nBytes,cudaMemcpyHostToDevice);
    cudaMemcpy(d_B,h_A,nBytes,cudaMemcpyHostToDevice);

   
    double iStart = seconds();
    readOffset<<<grid,block>>>(d_A,d_B,d_C,nElem,offset);
    cudaDeviceSynchronize();
    double iElaps = seconds() - iStart;
    printf("readoffset <<<%4d,%4d>>> offset %4d elapsed %f sec\n",grid.x,block.x,offset,iElaps);
    cudaGetLastError();

    // copy kernel result back to host side and check results
    cudaMemcpy(gpuRef,d_C,nBytes,cudaMemcpyDeviceToHost);
    checkResult(hostRef,gpuRef,nElem-offset);

    // free host and device mem
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    free(h_A);
    free(h_B);

    // reset device
    cudaDeviceReset();
    return EXIT_SUCCESS;
    }


