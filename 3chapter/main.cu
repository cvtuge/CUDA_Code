#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define DATA_SIZE 1048576
#define THREAD_NUM 256
#define BLOCK_NUM 2

int data[DATA_SIZE];

static void GenerateNumbers(int *number, int size)
{
    for(int i = 0; i < size; i++) {
        number[i] = rand() % 10;
    }

	return;
}

static void print_device_prop(const cudaDeviceProp &prop)
{
    printf("Device Name : %s.\n", prop.name);
    printf("totalGlobalMem : %d.\n", prop.totalGlobalMem);
    printf("sharedMemPerBlock : %d.\n", prop.sharedMemPerBlock);
    printf("regsPerBlock : %d.\n", prop.regsPerBlock);
    printf("warpSize : %d.\n", prop.warpSize);
    printf("memPitch : %d.\n", prop.memPitch);
    printf("maxThreadsPerBlock : %d.\n", prop.maxThreadsPerBlock);
    printf("maxThreadsDim[0 - 2] : %d %d %d.\n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
    printf("maxGridSize[0 - 2] : %d %d %d.\n", prop.maxGridSize[0], prop.maxGridSize[1], prop.maxGridSize[2]);
    printf("totalConstMem : %d.\n", prop.totalConstMem);
    printf("major.minor : %d.%d.\n", prop.major, prop.minor);
    printf("clockRate : %d.\n", prop.clockRate);
    printf("textureAlignment : %d.\n", prop.textureAlignment);
    printf("deviceOverlap : %d.\n", prop.deviceOverlap);
    printf("multiProcessorCount : %d.\n", prop.multiProcessorCount);
}

bool init_cuda()
{
    int count;

    cudaGetDeviceCount(&count);
    if(0 == count){
        fprintf(stderr,"There is no device\n");
        return false;
    }

    int i;
    for(i = 0; i < count; i++){
        cudaDeviceProp prop;
        if(cudaSuccess == cudaGetDeviceProperties(&prop,i)){
            if(prop.major >= 1){
                break;
            }
        }
    }

    if(i == count){
        fprintf(stderr,"There is no device supporting CUDA 1.x.\n");
        return false;
    }

    cudaSetDevice(i);

    return true;
}

__global__ static void sumOfSquares(int *num, int* result, clock_t* time)
{
	extern __shared__ int shared[];
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
    int i;
	if(0 == tid){
		time[bid] = clock();
	}
	shared[tid] = 0;
	for(i = bid*THREAD_NUM + tid; i <= DATA_SIZE; i += THREAD_NUM * BLOCK_NUM){
		shared[tid] += num[i] * num[i];
	}
	__syncthreads();
	if(0 == tid){
		for(i = 1; i < THREAD_NUM; i++){
			shared[0] += shared[i];
		}
		result[bid] = shared[0];
	}
	if(0 == tid){
		time[bid+BLOCK_NUM] = clock();
	}
}

int main()
{
    if(!init_cuda()){
        return 0;
    }

    printf("CUDA initialize.\n");

    //生成随机数
    GenerateNumbers(data, DATA_SIZE);

	int *gpudata, *result;
	clock_t* time;
	cudaMalloc((void **)&gpudata, sizeof(int)*DATA_SIZE);
	cudaMalloc((void **)&result,sizeof(int)*BLOCK_NUM);
	cudaMalloc((clock_t **)&time,sizeof(clock_t)*BLOCK_NUM*2);
	cudaMemcpy(gpudata,data,sizeof(int)*DATA_SIZE,cudaMemcpyHostToDevice);

	sumOfSquares<<<BLOCK_NUM,THREAD_NUM,THREAD_NUM*sizeof(int)>>>(gpudata,result,time);

	int sum[BLOCK_NUM];
	clock_t time_used[BLOCK_NUM*2];
	cudaMemcpy(&sum,result,sizeof(int)*BLOCK_NUM,cudaMemcpyDeviceToHost);
	cudaMemcpy(&time_used,time,sizeof(clock_t)*BLOCK_NUM*2,cudaMemcpyDeviceToHost);
	cudaFree(gpudata);
	cudaFree(result);
	cudaFree(time);

	int final_sum = 0;
	for(int i = 0; i < BLOCK_NUM; i++){
		final_sum += sum[i];
	}

    clock_t min_start, max_end;
    min_start = time_used[0];
    max_end = time_used[BLOCK_NUM];
    for(int i = 1; i < BLOCK_NUM; i++) {
        if(min_start > time_used[i])
            min_start = time_used[i];
        if(max_end < time_used[i + BLOCK_NUM])
            max_end = time_used[i + BLOCK_NUM];
    }

	printf("sum(GPU):%d, time: %d\n", final_sum, max_end-min_start);

    final_sum = 0;
    for(int i = 0; i < DATA_SIZE; i++) {
        final_sum += data[i] * data[i];
    }
    printf("sum (CPU): %d\n", final_sum);

    return 0;
}






























