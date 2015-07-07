#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

#define NUM_THREADS 1000
#define BLOCK_WIDTH 1000
#define N_VERTEX 1024  //gives N_VERTEX*(N_VERTEX-1) edges in case of non-directed graph
#define INF INT_MAX
#define N_R 800

__global__ void bfs_kernel(int* d_V, int* d_E, int* d_F, int* d_X, int* d_C) {

	int i = 0;
	int currentIndex = 0;
	int myId = threadIdx.x + blockDim.x * blockIdx.x;

	int firstIndex = myId * N_VERTEX;
	int lastIndex = firstIndex + N_VERTEX;

	if (d_F[myId]) {
		d_F[myId] = 0;
		d_X[myId] = 1;
		for (i = firstIndex; i < lastIndex; i++) {
		//Consider only neighbors
			if (d_E[i] == 1) { //this means that vertex (i/N_VERTEX) and (i%N_VERTEX) are connected
				currentIndex = i % N_VERTEX;
				if (d_X[currentIndex] == 0) {    //if it is not visited
					d_C[currentIndex] = d_C[myId] + 1;
					d_F[currentIndex] = 1;
				}
			}
		}
	}
}


//This function returns 0 if the given matrix has only zeros and an integer if not.
int isFEmpty(int* h_F) {

	int i = 0;
	int result = 0;

	for (i = 0; i < N_VERTEX; i++) 
	{
		result += h_F[i];
	}
	return result;
}

void printArray(int* array,int nCol, int arraySize) {
	int i = 0;

	printf("-------------------------------------------------\n");
	for (i = 0; i < arraySize; i++) {
		if(i%nCol==0) printf("\n");
		printf("[%d] ", array[i]);
	}
	printf("-------------------------------------------------\n");
}

int main(int argc, char *argv[]) {

	cudaEvent_t begin, end;
	cudaEventCreate(&begin);
	cudaEventCreate(&end);
	int counter = 0;
	float millisecond = 0;
	int is_F_Empty = 1;
	int i = 0, j = 0;
	int nEdges = N_VERTEX * N_VERTEX; //this is not exactly the max number of the edges, but the size
	//of a matrix describing connectivity of each pair of vertices

	int* d_V;
	int* d_E;
	int* d_F;
	int* d_X;
	int* d_C;

	int h_V[N_VERTEX];      //Vertex
	int h_E[nEdges];        //Edge
	int h_F[N_VERTEX];      //Frontier
	int h_X[N_VERTEX];      //Visited
	int h_C[N_VERTEX];      //Cost (Distance from the beginning vertex)
    /*********************************/
   
    /*****************    EXAMPLE I ****************/
	/*
	h_E[0] = 0;
	h_E[1] = 0;
	h_E[2] = 0;
	h_E[3] = 1;
	h_E[4] = 1;
	h_E[5] = 0;

	h_E[6] = 0;
	h_E[7] = 0;
	h_E[8] = 1;
	h_E[9] = 1;
	h_E[10] = 1;
	h_E[11] = 0;

	h_E[12] = 0;
	h_E[13] = 1;
	h_E[14] = 0;
	h_E[15] = 0;
	h_E[16] = 0;
	h_E[17] = 0;

	h_E[18] = 1;
	h_E[19] = 1;
	h_E[20] = 0;
	h_E[21] = 0;
	h_E[22] = 0;
	h_E[23] = 1;

	h_E[24] = 1;
	h_E[25] = 1;
	h_E[26] = 0;
	h_E[27] = 0;
	h_E[28] = 0;
	h_E[29] = 0;

	h_E[30] = 0;
	h_E[31] = 0;
	h_E[32] = 0;
	h_E[33] = 1;
	h_E[34] = 0;
	h_E[35] = 0;
	*/
/*******************END I*********************/
   
/*****************    EXAMPLE II ***************/
	/*	
	for (i=0; i < nEdges; i++)
	{
		if(i/N_VERTEX == (i%N_VERTEX + 1))
			h_E[i] = 1;
		else
			h_E[i] = 0;

	}
	h_E[N_VERTEX - 1] = 1;
	*/
/*******************END II********************/

/******************* EXAMPLE III *************/
	for (i=0; i < nEdges; i++){
		if(2*(i/N_VERTEX)+1 == (i%N_VERTEX))
			h_E[i] = 1;
		else if(2*(i/N_VERTEX)+2 == (i%N_VERTEX))
			h_E[i] = 1;
		else
			h_E[i] = 0;
		
	}
	for(j=0; j< N_R; j++){
		i = rand() % nEdges;
		if(h_E[i] != 1)
			h_E[i]=1;
	}
//	printArray(h_E,N_VERTEX, nEdges);

/******************* END III ****************/
	for (i = 0; i < N_VERTEX; i++) 
	{
		h_V[i] = i;     //index
		h_F[i] = 0;     //false
		h_X[i] = 0;     //false
		h_C[i] = INF;   //infinity
	} 
/*********************TEST**********************/

    h_F[0] = 1;   //true
    h_C[0] = 0;

	cudaMalloc((void**) &d_V, sizeof(int) * N_VERTEX);
	cudaMalloc((void**) &d_E, sizeof(int) * nEdges);
	cudaMalloc((void**) &d_F, sizeof(int) * N_VERTEX);
	cudaMalloc((void**) &d_X, sizeof(int) * N_VERTEX);
	cudaMalloc((void**) &d_C, sizeof(int) * N_VERTEX);

	cudaMemset((void*) &d_V, 0, sizeof(int) * N_VERTEX);
	cudaMemset((void*) &d_F, 0, sizeof(int) * N_VERTEX);
	cudaMemset((void*) &d_X, 0, sizeof(int) * N_VERTEX);
	cudaMemset((void*) &d_C, 0, sizeof(int) * N_VERTEX);

	cudaMemcpy(d_V, h_V, sizeof(int) * N_VERTEX, cudaMemcpyHostToDevice);
	cudaMemcpy(d_E, h_E, sizeof(int) * nEdges, cudaMemcpyHostToDevice);
	cudaEventRecord(begin);
	while (is_F_Empty) 
	{//while h_F is not all zeros
		cudaMemcpy(d_F, h_F, sizeof(int) * N_VERTEX, cudaMemcpyHostToDevice);
		cudaMemcpy(d_X, h_X, sizeof(int) * N_VERTEX, cudaMemcpyHostToDevice);
		cudaMemcpy(d_C, h_C, sizeof(int) * N_VERTEX, cudaMemcpyHostToDevice);

		bfs_kernel<<<2,512>>>(d_V, d_E, d_F, d_X, d_C);

		cudaMemcpy(h_F, d_F, sizeof(int) * N_VERTEX, cudaMemcpyDeviceToHost);
		cudaMemcpy(h_X, d_X, sizeof(int) * N_VERTEX, cudaMemcpyDeviceToHost);
		cudaMemcpy(h_C, d_C, sizeof(int) * N_VERTEX, cudaMemcpyDeviceToHost);

		is_F_Empty = isFEmpty(h_F);
        
		printf("_________________________\n");
		printf("\nLOOP COUNTER: %d\n", counter);
		counter++;
	}
	cudaEventRecord(end);
	cudaEventSynchronize(end);
	cudaEventElapsedTime(&millisecond, begin, end);
	printf("Second: %f", millisecond);
	printArray(h_C, N_VERTEX, N_VERTEX);
	cudaFree(d_F);
	cudaFree(d_X);
	cudaFree(d_C);
	cudaFree(d_V);
	cudaFree(d_E);

	return EXIT_SUCCESS;
}
