// **************************************************************************
// File       [ swk_gpu_atpg.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2010/03/10 ]
// **************************************************************************

#include "swk_gpu_atpg.h"
#include "curand_kernel.h"
#include "pattern.h"
#include <fstream>
#include <cuda.h>
#include <cuda_runtime.h>
#include <cutil.h>
#include <cutil_inline.h>
#include <iomanip>
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include "helper_cuda.h"
using namespace CoreNs;
using namespace std;

// Function Name : void __checkCudaErrors
// Functionality : use to check whether kernel has any error or not
// Usage         : CCE(cudaDeviceSynchronize());
template< typename T >
inline void __checkCudaErrors(T result, char const *const func, const char *const file, int const line)
{
	cudaError_t err = cudaGetLastError();

	if (cudaSuccess != err)
	{
		fprintf(stderr, "%s:%i : checkCudaErrors() CUDA error (#%d): %s.\n",
				file, line, (int)err, cudaGetErrorString(err));
		exit(-1);
	}
}
#define CCE(val) __checkCudaErrors( (val), #val, __FILE__, __LINE__ )


// Function Name : void faultSim
// Functionality : the kernel of SWK fault simulation
__device__ void faultSim (
    int*             numRmnFaults
    , unsigned long* split
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , int*           gateType
    , int*           fanin
    , int*           nLevels
    , unsigned long* value
    , int*           nDetect
    , unsigned long* pattern
);

__device__ void randFill(
    int*             gateType
    , int            nLevels
    , unsigned long* value
    , unsigned long* split
);

__device__ void goodEval(
    int*             gateType
    , int*           fanin
    , int            nLevels
    , unsigned long* value
);

__device__ void faultEval(
    int*             gateType
    , int*           fanin
    , int            nLevels
    , unsigned long* value
    , int            numRmnFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , int            nDetect
    , unsigned long* pattern
);

__device__ void resetValuesToGood(
    int              startLevel
    , int*           gateType
    , int            nLevels
    , unsigned long* value
);

// Function Name : void gpuGen
// Functionality : the kernel of SWK algorithm
__global__ void gpuGen (
    // circuit information
    int*             numRmnFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , unsigned long* split
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    , int*           nLevels
    , unsigned long* value
    // backtrack
    , int*           bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
    // atpg parameters
    , int*           nDetect
    , int*           abLimit
    , int*           bkLimit
    , bool*          taMode
    , bool*          getMode
    // zero copy
    , int*           nInputs
    , unsigned long* pattern
);


// Function Name : void initBkParam
// Functionality : initialize the backtrack parameter bkPtr to -1
// Usage         : deadClones(32bits), bit = 1 means the clone need initialize
__device__ void initBkParam(
    int*  bkPtr,
    unsigned long & deadClones
);


// Function Name : void initialObjective
// Functionality : initialize the initial obkective
// Usage         : deadMask(32bits), bit = 1 means the clone need initial objective
// Usage         : only 4 threads needed for this function due to 4 total faults in 32 clones
__device__ void initialObjectives (
    int nFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int            nLevels
    , int*           fanin
    , unsigned long* value
    , int            nDetect
    , bool           getMode
    , unsigned long  deadMask
);


// Function Name : void propagation
// Functionality : do propagation, -1 < level < nLevels * 2, 2 due to two timeframes
// Usage         : propagatable(32bits), bit = 1 means there is p at any PO or PPO in this clone
// Usage         : detected(32bits), bit = 1 means there is d|b at any PO or PPO in this clone
__device__ void propagation(
    int              currentLevel
    , int            nFaults
    , unsigned long& propagatable
    , unsigned long& detected
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    //, int*           fanout
    , int            nLevels
    , unsigned long* values
    , int* faultGate
    , int* faultType
    , int* faultLine
);


// Function Name : void backtrack
// Functionality : do backtrack
// Usage         : deadClones(32bits), bit = 1 means the clone is dead and the stack is not empty -->needs backtrack
// Usage         : StackEmpty(32bits), bit = 1 means the cloes's stack is empty, no need for backtrack anymore
__device__ void backtrack(
    unsigned long    deadClones
    , int            nLevels
    , unsigned long* value
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
    , unsigned long* StackEmpty
);


// Function Name : void backtrace
// Functionality : do propagation, nLevels * 2 > level > -1, 2 due to two timeframes
// Usage         : obj(32bits), bit = 1 means the clone has objective, no o-generation can be performed
__device__ void backtrace(
    int              currentLevel
    , unsigned long& obj
    , unsigned long* split
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    //, int*           fanout
    , int            nLevels
    , unsigned long* value
    // for backtrack
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
);


// Function Name : void trackAssignment
// Functionality : record the assignment of each clone in the stack after each backtrace loop
// Usage         : assignedId(int * 128), the gateId in the corresponding backtrace loop
// Usage         : assignedV0(32bits * 128), the new l value in the corresponding backtrace loop  (after assignment)
// Usage         : assignedV1(32bits * 128), the new h value in the corresponding backtrace loop  (after assignment)
// Usage         : prevV0(32bits * 128), the previous l value in the corresponding backtrace loop (before assignment)
// Usage         : prevV1(32bits * 128), the previous h value in the corresponding backtrace loop (before assignment)
__device__ void trackAssignment(
    int*             assignedId
    , unsigned long* assignedV0
    , unsigned long* assignedV1
    , unsigned long* prevV0
    , unsigned long* prevV1
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
);


// Function Name : void zeroCopy
// Functionality : copy pattern in GPU memory to CPU memory
__device__ void zeroCopy(
    int*             gateType
    , unsigned long* values
    , unsigned long* pattern
    , int            nLevels
    , int            nInputs
);


// Function Name : void printValue
// Functionality : print the value according to v0 and v1
__device__ void printValue(
    int             gateId
    , unsigned long v0
    , unsigned long v1
);


// Function Name : void clearValue
// Functionality : clear the value in "values"
// Usage         : clearClones(32bits), bit = 1 means the values(l,h,d,b,btl,bth,p) of this clone need to be clean
// Usage         : pp flag = 1 means clear all the values <<<instead of PI in timeframe1,2 and PPI in timeframe1>>>
// Usage         : bt flag = 1 means clear all the backtrace values(btl,bth)
__device__ void clearValue(unsigned long *values
    , int* gateType
    , int nLevels
    , unsigned long clearClones
    , bool pp
    , bool bt
);


// Function Name : void NumberOfSetBits
// Functionality : return how many set bits in a 32-bits value
int SwkGpuAtpg::NumberOfSetBits(unsigned long i)
{
     i = i - ((i >> 1) & 0x55555555);
     i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
     return (int)(((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}


// Function Name : void WritePattern
// Functionality : build pCol(add 32 pattern) after each kernel
// Usage         : TotalBlocks(int), shows the used number of block in this kernal
void SwkGpuAtpg::WritePattern(PatternColl *pCol, int TotalBlocks)
{
    unsigned long v0;
    unsigned long v1;

    // trace all the blocks in this kernel
    for(int block = 0; block < TotalBlocks; ++block){

        // detect information has been saved in the begin of the array cpuPattern_
        //unsigned long Detected = cpuPattern_[block];
        unsigned long Detected = ~(0x0);
        int nDetectedPattern = NumberOfSetBits(Detected);
        printf(" | block %2d ----> detected = %8lx\n",block,Detected);

        // create number of detected pattern class and update clock information
        Pattern* Pat[nDetectedPattern];
        for(int i = 0; i < nDetectedPattern; ++i){
            Pat[i] = new Pattern( cir_->nPis() + 3, cir_->nPos(), cir_->nFrames(), cir_->nSeqs() );// CK...

            // set CAPT in timeframe1,2
            Pattern::Clk clk = Pattern::CAPT;
            Value v = L;
            size_t frame = 0;
            Pat[i]->setClk(clk, frame);
            Pat[i]->setPi(v, 0, frame);// CK
            Pat[i]->setPi(v, 1, frame);// test_si
            Pat[i]->setPi(v, 2, frame);// test_se
            frame = 1;
            Pat[i]->setClk(clk, frame);
            Pat[i]->setPi(v, 0, frame);// CK
            Pat[i]->setPi(v, 1, frame);// test_se
            Pat[i]->setPi(v, 2, frame);// test_si
        }

        // set input value
        // trace all the PI PPI in two timeframes
        for(int k = 0; k < nInputs_ * 2; ++k){
            // k is input offset
            // block * nInputs_ * 2 is block offset(*2 due to two timeframe)
            // *2 outside is due to two value per PI or PPI
            // TotalBlocks is the offset for detection information
            v0 = cpuPattern_[(k + block * nInputs_ * 2) * 2 + 0 + TotalBlocks];
            v1 = cpuPattern_[(k + block * nInputs_ * 2) * 2 + 1 + TotalBlocks];

            Value v;

            // skip if the input is PPI and the input is in timeframe2 (in __CAPT__ mode)
            if(k >= cir_->nPis() * 2 && k%2 != 0)continue;

            // idx = k / 2                if the input is PI
            // idx = k / 2 - cir_->nPis() if the input is PPI (remove the offset of number of PI)
            size_t idx   = k < cir_->nPis() * 2 ? k / 2 : k / 2 - cir_->nPis();

            // frame = k % 2                if the input is PI
            // frame = 0                    if the input is PPI (if the input is PPI, the timeframe is always 1)
            size_t frame = k < cir_->nPis() * 2 ? k % 2 : 0 ;

            int AddedPattern = 0;
            // trace all the clone
            for (size_t i = 0; i < 32; ++i) {
                // skip if not detect in this clone
                int skip = (Detected >> i) & 0x01;
                if(skip == 0)continue;

                // get value according to the v0 and v1
                unsigned long v0bit = (v0 >> i) & (unsigned long)0x01;
                unsigned long v1bit = (v1 >> i) & (unsigned long)0x01;

                // X--0--1--? in each condition
                if(v0bit == 0 && v1bit == 0)
                    v = rand()%2 == 0 ? L : H;//random fill
                else if (v0bit == 1 && v1bit == 0)
                    v = L;
                else if (v0bit == 0 && v1bit == 1)
                    v = H;
                else
                    v = rand()%2 == 0 ? L : H;//random fill

                // add value into pattern
                if(k < cir_->nPis() * 2)
                    Pat[AddedPattern]->setPi(v, idx + 3, frame);// CK...
                else
                    Pat[AddedPattern]->setPpi(v, idx);
                AddedPattern++;
            }
        }

        // push back all the pattern objects to pCol
        for(int i = 0; i < nDetectedPattern; ++i)
            pCol->addPattern(Pat[i]);
    }
}


// Function Name : void allocFaults
// Functionality : allocate memory for remaining faults on GPU
void SwkGpuAtpg::allocFaults(FaultList& rmnFault) {
    (*cpuNumRmnFaults_) = rmnFault.size();
    FaultListIter iter = rmnFault.begin();
    int idx = 0;
    while (iter != rmnFault.end()) {
        Fault* f = *iter;
        cpuFaultGate_[idx] = memAlloc_->gpuId(f->getGate()->getId());
        cpuFaultDetect_[idx] = f->getDet();
        cpuFaultType_[idx] = f->getType();
        cpuFaultLine_[idx] = f->getLine();
        ++idx;
        ++iter;
    }

    // copy memory to GPU
    cudaMemcpy(gpuNumRmnFaults_, cpuNumRmnFaults_, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(memAlloc_->faultGateGpuPtr(), cpuFaultGate_, sizeof(int) * (*cpuNumRmnFaults_), cudaMemcpyHostToDevice);
    cudaMemcpy(memAlloc_->faultDetectGpuPtr(), cpuFaultDetect_, sizeof(int) * (*cpuNumRmnFaults_), cudaMemcpyHostToDevice);
    cudaMemcpy(memAlloc_->faultTypeGpuPtr(), cpuFaultType_, sizeof(int) * (*cpuNumRmnFaults_), cudaMemcpyHostToDevice);
    cudaMemcpy(memAlloc_->faultLineGpuPtr(), cpuFaultLine_, sizeof(int) * (*cpuNumRmnFaults_), cudaMemcpyHostToDevice);
}


// Function Name : void zeroCopyPreparation
// Functionality : prepare for zerocopy
void SwkGpuAtpg::zeroCopyPreparation() {

    // number of inputs is number of PI add number of PPI
    nInputs_ = cir_->nPis() + cir_->nSeqs();

    // number of pattern is number of inputs * 2 timeframe * 2 values(l,h)
    int nValues = nInputs_ * cir_->nFrames() * 2;

    // number of pattern array is number of pattern + total blocks in this kernel(use to record the detected information)
    nPatterns_ = nValues * nBlocks_ + nBlocks_;
    cpuPattern_ = (unsigned long*)malloc(sizeof(unsigned long) * nPatterns_);
    cudaMalloc((void**)&gpuPattern_, sizeof(unsigned long) * nPatterns_);
}

void SwkGpuAtpg::gen(PatternColl *pCol, FaultColl *fCol) {

    //sddcudaSim->cudaDataTrans();
    cout << " [Correct] Simulator Alloaction finished" << endl;

    cout << " ==========================================================" << endl;
    cout << " =                  Start SWK ATPG                        =" << endl;
    cout << " ==========================================================" << endl;
    unsigned int timer = 0;
    (cutCreateTimer(&timer));
    (cutStartTimer(timer));

    Fault     *f;

    // allocate ATPG parameters memory on GPU
    allocAtpgParameters();

    // prepare zero copy generated test patterns
    zeroCopyPreparation();

    // put all the faults in the circuit into the remain fault list
    FaultList rmnGenFault;
    FaultList rmnSimFault;
    for (size_t i = 0; i < fCol->getFaults()->size(); ++i) {
        f = fCol->getFaults()->at(i);
        if(f->getState() == Fault::UD || f->getState() == Fault::AB)
            rmnGenFault.push_back(fCol->getFaults()->at(i));
    }

    // allocate space to store faults
    int nTotalFaults = fCol->getFaults()->size();
    cpuNumRmnFaults_ = new int;
    cpuNumPrimaryFaults_ = new int;
    cpuFaultGate_ = new int[nTotalFaults];
    cpuFaultDetect_ = new int[nTotalFaults];
    cpuFaultType_ = new int[nTotalFaults];
    cpuFaultLine_ = new int[nTotalFaults];
    cudaMalloc((void**)&gpuNumRmnFaults_, sizeof(int));
    (*cpuNumPrimaryFaults_) = nTotalFaults;
    cout << " [Correct] Fault Allocation finished" << endl;

    // report Memory Usage
    size_t free_byte;
    size_t total_byte;
    if(cudaMemGetInfo(&free_byte,&total_byte) != cudaSuccess){
        printf(" [Error]: Memory Get Info Fail!!\n");
        return;
    }
    else
        printf(" [Success]: Memory Get Info success!!\n");
    cout<<" ------------------------------------------\n";
    cout<<" | GPU memory free = "<<setw(12)<<(float)(free_byte)/1024.0/1024.0<<" MB      |\n";
    cout<<" | GPU memory used = "<<setw(12)<<(float)(total_byte - free_byte)/1024.0/1024.0<<" MB      |\n";
    cout<<" ------------------------------------------\n";
    cout<<" | Mem Setup Time  = "<<setw(12)<< cutGetTimerValue(timer) <<" ms      |\n";
    cout<<" ------------------------------------------\n";


    cout << " ==========================================================" << endl;
    cout << " =                  Start Generation                      =" << endl;
    cout << " ==========================================================" << endl;
    int iter = 0;
    while (rmnGenFault.size() > 0) {
        // allocate corresponding faults on GPU
        allocFaults(rmnGenFault);

        cout << " ----------------------------------------------------------" << endl;
        cout << " | Clock  = " << setw(12) << cutGetTimerValue(timer) <<" ms" << endl;
        cout << " | Iter   = " << iter << endl;
        cout << " | Generate " << nBlocks_ * 4 << " faults... " << *cpuNumPrimaryFaults_ << " remains" << endl;

        // test generation kernel
        gpuGen <<< nBlocks_, nThreads_ >>> (
            // circuit information
            gpuNumRmnFaults_
            , memAlloc_->faultGateGpuPtr()
            , memAlloc_->faultTypeGpuPtr()
            , memAlloc_->faultLineGpuPtr()
            , memAlloc_->faultDetectGpuPtr()
            , memAlloc_->splitGpuPtr()
            , memAlloc_->gateTypeGpuPtr()
            , memAlloc_->gateSplitGpuPtr()
            , memAlloc_->faninsGpuPtr()
            , memAlloc_->nLevelsGpuPtr()
            , memAlloc_->valuesGpuPtr()
            // backtrack parameters
            , gpuBkStackSize_
            , gpuBkValue_
            , gpuBkPtr_
            , gpuBkGate_
            , gpuBkFlipped_
            // atpg parameters
            , gpuNDetect_
            , gpuDcLimit_
            , gpuBkLimit_
            , gpuTaMode_
            , gpuGetMode_
            // zero copy
            , memAlloc_->nInputsGpuPtr()
            , gpuPattern_
        );
        cudaDeviceSynchronize();

        // zero copy patterns back to CPU
        CCE(cudaMemcpy(cpuPattern_, gpuPattern_, sizeof(unsigned long)*nPatterns_ , cudaMemcpyDeviceToHost));

        WritePattern(pCol, nBlocks_);
        //pCol->print();

        dropFaults(rmnGenFault, rmnSimFault, pCol);
        iter++;
    }
}

void SwkGpuAtpg::dropFaults(FaultList& rmnGenFault
    , FaultList& rmnSimFault
    , PatternColl* pCol)
{
    // put generated faults into remaining sim list
    int nPrevGenFaults = nBlocks_ * 4;
    FaultListIter it = rmnGenFault.begin();
    int count = 0;
    while (it != rmnGenFault.end()) {
        Fault* f = (*it);
        it = rmnGenFault.erase(it);
        rmnSimFault.insert(rmnSimFault.begin(), f);
        ++count;
        if (count == nPrevGenFaults)
            break;
        ++it;
    }

    cout << " ==========================================================" << endl;
    cout << " =                  Start Simulation                      =" << endl;
    cout << " ==========================================================" << endl;
    // perform fault simulation on two fault lists
    int nPrevGenPatterns = nBlocks_ * 32;
    sim_->simulate(pCol, rmnSimFault, nPrevGenPatterns);
    sim_->simulate(pCol, rmnGenFault, nPrevGenPatterns);
    cout << " Done " << endl;
    cout << " Remaining number of generation faults: " << rmnGenFault.size() << endl;
    cout << " Remaining number of simulation faults: " << rmnSimFault.size() << endl;
}

__device__ void faultSim (
    int*             numRmnFaults
    , unsigned long* split
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , int*           gateType
    , int*           fanin
    , int*           nLevels
    , unsigned long* value
    , int*           nDetect
    , unsigned long* pattern
) {
    // DEBUG
    clock_t timerStart;
    clock_t timerStop;
    double totaltime;
    if (blockIdx.x == 1 && threadIdx.x == 0)
        timerStart = clock();
    __syncthreads();

    randFill(gateType, (*nLevels), value, split);

    if (blockIdx.x == 1 && threadIdx.x == 0) {
        timerStop = clock64();
        totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
        printf("  + Random fill %lf s\n", totaltime);
        timerStart = clock64();
    }
    __syncthreads();

    goodEval(gateType, fanin, (*nLevels), value);

    if (blockIdx.x == 1 && threadIdx.x == 0) {
        timerStop = clock64();
        totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
        printf("  + Good evaluation %lf s\n", totaltime);
        timerStart = clock64();
    }
    __syncthreads();

    faultEval(
        gateType
        , fanin
        , (*nLevels)
        , value
        , (*numRmnFaults)
        , faultGate
        , faultType
        , faultLine
        , faultDetect
        , (*nDetect)
        , pattern
    );

    if (blockIdx.x == 1 && threadIdx.x == 0) {
        timerStop = clock64();
        totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
        printf("  + Faulty evaluation %lf s\n", totaltime);
        timerStart = clock64();
    }
    __syncthreads();

}

__device__ void faultEval(
    int*             gateType
    , int*           fanin
    , int            nLevels
    , unsigned long* value
    , int            numRmnFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , int            nDetect
    , unsigned long* pattern
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;

    __shared__ int nGatesPerFrame;      // for finding corresponding gates in second time frame
    __shared__ unsigned long activated; // monitor activated bits at fault site
    __shared__ unsigned long detected;  // monitor detected bits at PO and PPO
    //__shared__ unsigned long changed;   // monitor faulty value change in each level

    clock_t timerStart;
    clock_t timerStop;
    clock_t timerStart2;
    clock_t timerStop2;
    double totaltime;

    if (thId == 0)
        nGatesPerFrame = blockDim.x * nLevels;
    __syncthreads();
    
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        timerStart2 = clock64();
    }

    int startIdx = blockIdx.x * (numRmnFaults / gridDim.x);
    for (int i = 0; i < numRmnFaults ; ++i) {
        bool debug = false;
        if (blockIdx.x == 1 && threadIdx.x == 0) {
            if (i % 10000 == 0 ) {//|| i % 10000 == 1) {
                timerStop2 = clock64();
                //totaltime = ((double)(timerStop2) - (double)(timerStart2))/CLOCKS_PER_SEC;
                //printf("    + total i = %d\n", i);
                //printf("    + total time = %f\n", totaltime);
                debug = true;
                printf("    + i = %d\n", i);
                printf("    + timeStop  = %lu s\n", timerStop2);
                printf("    + timeStart = %lu s\n", timerStart2);
                //printf("    + clock per sec = %lu s\n", CLOCKS_PER_SEC);
                //printf("    + time      = %lf s\n", (double)(timerStop2 - timerStart2)/CLOCKS_PER_SEC);
                timerStart = clock64();
            }
        }

        // each block start from different fault
        int faultIdx = i + startIdx;
        if (faultIdx >= numRmnFaults)  // loop to the beginning
            faultIdx -= numRmnFaults;

        /*if (blockIdx.x == 0 && threadIdx.x == 0) {

            if (i == 1 || i == 3 || i == 5) {
                printf("    + i = %d\n", i);
                debug = true;
                timerStart = clock();
            }
        }*/
        __syncthreads();

        // check previous detection
        if (faultDetect[faultIdx] >= nDetect) {
            /*if (threadIdx.x == 0) {
                printf("block %d skip\n",blockIdx.x);
            }*/
            __syncthreads();
            continue;
        }
        int gate = faultGate[faultIdx];
        int type = faultType[faultIdx];
        int line = faultLine[faultIdx];
        if (line > 0)
            gate = fanin[gate * 4 + line - 1];
        int gateT2 = gate + nGatesPerFrame;

        // thread 0 check activation
        if (thId == 0) {
            activated = 0x0;
            detected = 0x0;
            //changed = 0x0;

            // faultGate value, used for inject fault
            int faultgate = faultGate[faultIdx];
            int faultgateT2 = faultGate[faultIdx] + nGatesPerFrame;
            int gatetype = gateType[faultgate];

            // falutGate's input value, used for check activation
            int faultgate_a = fanin[faultgate * 4 + 0]; 
            int faultgate_b = fanin[faultgate * 4 + 1];
            int faultgate_aT2 = fanin[faultgateT2 * 4 + 0];
            int faultgate_bT2 = fanin[faultgateT2 * 4 + 1];

            // find values in the two time frames
            unsigned long t1gl = value[blId * nGatesPerFrame * 8 * 2 + gate * 8 + 0];
            unsigned long t1gh = value[blId * nGatesPerFrame * 8 * 2 + gate * 8 + 1];
            unsigned long t2gl = value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 0];
            unsigned long t2gh = value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 1];

            unsigned long t1a0 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_a * 8 + 0];
            unsigned long t1a1 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_a * 8 + 1];
            unsigned long t1b0 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_b * 8 + 0];
            unsigned long t1b1 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_b * 8 + 1];
            unsigned long t2a0 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_aT2 * 8 + 0];
            unsigned long t2a1 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_aT2 * 8 + 1];
            unsigned long t2b0 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_bT2 * 8 + 0];
            unsigned long t2b1 = value[blId * nGatesPerFrame * 8 * 2 + faultgate_bT2 * 8 + 1];

            // determine activation based on fault types
            // if line==0 : check faultGate's output
            // if line!=0 : check faultGate's input
            if (type == 2) // slow-to-rise
                activated = t1gl & t2gh;
            else if (type == 3) // slow-to-fall
                activated = t1gh & t2gl;

            // update activated value (check side input value) if line!=0

            if (line == 1){
                if (gatetype == 6 || gatetype == 7) // AND / NAND  side input not zero
                    if(type == 2)
                        activated &= ~t2b0;
                    else if(type == 3)
                        activated &= ~t1b0;
                else if (gatetype == 8 || gatetype == 9) // OR / NOR side input not 1
                    if(type == 2)
                        activated &= ~t2b1;
                    else if(type == 3)
                        activated &= ~t1b1;
            }
            else if (line == 2){
                if (gatetype == 6 || gatetype == 7) // AND / NAND  side input not zero
                    if(type == 2)
                        activated &= ~t2a0;
                    else if(type == 3)
                        activated &= ~t1a0;
                else if (gatetype == 8 || gatetype == 9) // OR / NOR side input not 1
                    if(type == 2)
                        activated &= ~t2a1;
                    else if(type == 3)
                        activated &= ~t1a1;
            }

        }

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Check activation %lf s\n", totaltime);
            timerStart = clock64();
        }

        __syncthreads();
        if (activated == 0x0) // find next activated fault
            continue;

        // update gate after checking activation
        gate = faultGate[faultIdx];
        gateT2 = gate + nGatesPerFrame;

        // thread 0 inject faults at gate output
        if (thId == 0) {
            int gatetype = gateType[gate];
            if (type == 2) { // slow-to-rise
                if((line == 0) || (gatetype != 4 && gatetype != 7 && gatetype != 9)){// INV NAND NOR
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 2] = ~(0x0); // faulty low in second time frame
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 3] = 0x0;    // faulty high in second time frame
                }
                else{
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 2] = 0x0; // faulty low in second time frame
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 3] = ~(0x0);    // faulty high in second time frame
                }
            }
            else if (type == 3) { // slow-to-fall
                if((line == 0) || (gatetype != 4 && gatetype != 7 && gatetype != 9)){
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 2] = 0x0;    // faulty low in second time frame
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 3] = ~(0x0); // faulty high in second time frame
                }
                else{
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 2] = ~(0x0);    // faulty low in second time frame
                    value[blId * nGatesPerFrame * 8 * 2 + gateT2 * 8 + 3] = 0x0; // faulty high in second time frame
                }
            }
        }

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Inject fault %lf s\n", totaltime);
            timerStart = clock64();
        }

        __syncthreads();

        // perform faulty evaluation for each gate starting from the level of the faulty gate
        int startLevel = gateT2 / blockDim.x;
        for (int currLevel = startLevel + 1; currLevel < nLevels * 2; ++currLevel) {
            // check for events using the changed flag
            //if (thId == 0)
            //    changed = 0x0;
            //__syncthreads();

            int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
            int levelOffset = currLevel * blockDim.x;
            int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

            // find gate and gate type
            int gate = levelOffset + threadIdx.x;
            int type = gateType[gate];

            unsigned long gl = value[valueStart + 0]; // good low
            unsigned long gh = value[valueStart + 1]; // good high
            unsigned long fl = value[valueStart + 2]; // faulty low
            unsigned long fh = value[valueStart + 3]; // faulty high

            // find fanin values
            int aStart= -1;
            int bStart= -1;
            if(fanin[gate * 4] != -1)
                aStart = blockOffset * 8 + fanin[gate * 4] * 8;     // fanin 0
            if(fanin[gate * 4 + 1] != -1)
                bStart = blockOffset * 8 + fanin[gate * 4 + 1] * 8; // fanin 1

            unsigned long afl = 0x0;
            unsigned long afh = 0x0;
            unsigned long bfl = 0x0;
            unsigned long bfh = 0x0;
            if (aStart != -1) {
                afl = value[aStart + 2];
                afh = value[aStart + 3];
            }
            if (bStart != -1) {
                bfl = value[bStart + 2];
                bfh = value[bStart + 3];
            }
            
            // perform good simulation for different gate types
            //type in here is gate type
            if (type == 0) // PI do not need simulation
                ;
            else if (type == 2 && currLevel >= nLevels) { // PPI act as BUF
                fl = afl;
                fh = afh;
            }
            else if (type == 1 || type == 3) { // PO, PPO
                // special case when faultGate is PO
                // no propagation is needed because fault effect has already at PO
                fl = afl;
                fh = afh;
                //atomicOr((unsigned int *)&detected, (gl ^ fh) & (gh ^ fl));
                //atomicOr((unsigned int *)&detected, (gl ^ fl) & (gh ^ fh));
            }
            else if (type == 4) { // INV
                fl = afh;
                fh = afl;
            }
            else if (type == 5) { // BUF
                fl = afl;
                fh = afh;
            }
            else if (type == 6) { // AND
                fl = afl | bfl;
                fh = afh & bfh;
            }
            else if (type == 7) { // NAND
                fh = afl | bfl;
                fl = afh & bfh;
            }
            else if (type == 8) { // OR
                fl = afl & bfl;
                fh = afh | bfh;
            }
            else if (type == 9) { // NOR
                fl = afh | bfh;
                fh = afl & bfl;
            }

            //printf("thread %d, level %d type %d\n", threadIdx.x, currLevel, type);
            if(type != -1){
                //printValue(gate, gl, gh);
                //printValue(gate, fl, fh);
            }
            // assign simulated faulty values back to global memory
            value[valueStart + 2] = fl;
            value[valueStart + 3] = fh;
            __syncthreads();
        }

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Evaluation %lf s\n", totaltime);
            timerStart = clock64();
        }

        // update detected info
        for (int currLevel = nLevels; currLevel < nLevels * 2; ++currLevel) {

            int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
            int levelOffset = currLevel * blockDim.x;
            int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

            // find gate and gate type
            int gate = levelOffset + threadIdx.x;
            int type = gateType[gate];

            if(type == 1 || type == 3){
                unsigned long gl = value[valueStart + 0]; // good low
                unsigned long gh = value[valueStart + 1]; // good high
                unsigned long fl = value[valueStart + 2]; // faulty low
                unsigned long fh = value[valueStart + 3]; // faulty high
                atomicOr((unsigned int *)&detected, (gl ^ fl) & (gh ^ fh));
            }
            //__syncthreads();
        }

            __syncthreads();

        if(thId == 0){
            detected &= activated;
            // update detection data
            //pattern[blId] |= detected;// JKY @ 20150415
        }

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Update detected %lf s\n", totaltime);
            timerStart = clock64();
        }

        __syncthreads();

        // count number of detection
        if (thId == 0 && detected != 0x0) {
            unsigned long mask = 0x1;
            for (int j = 0; j < 32; ++j) {
                unsigned long bitDetect = mask & detected;
                if (bitDetect != 0x0){
                    atomicAdd((unsigned int*)&faultDetect[faultIdx], 1);
                    pattern[blId] |= bitDetect;

                    if(faultDetect[faultIdx] >= nDetect)
                        break;
                }
                mask <<= 1;
            }
        }

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Count detected %lf s\n", totaltime);
            timerStart = clock64();
        }

        __syncthreads();

        // reset circuit to good evaluation values
        resetValuesToGood(startLevel, gateType, nLevels, value);

        if (debug) {
            timerStop = clock64();
            totaltime = (double)(timerStop - timerStart)/CLOCKS_PER_SEC / 1000;
            printf("    + Reset to good %lf s\n", totaltime);
            timerStart = clock64();
        }

        __syncthreads();
    }
}

__device__ void resetValuesToGood(
    int              startLevel
    , int*           gateType
    , int            nLevels
    , unsigned long* value
) {
    for (int currLevel = startLevel; currLevel < nLevels * 2; ++currLevel) {
        int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
        int levelOffset = currLevel * blockDim.x;
        int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

        // find gate and gate type
        value[valueStart + 2] = value[valueStart + 0]; // set faulty low to good low
        value[valueStart + 3] = value[valueStart + 1]; // set faulty high to good high
    }
}

__device__ void goodEval(
    int*             gateType
    , int*           fanin
    , int            nLevels
    , unsigned long* value
) {
    for (int level = 0; level < nLevels * 2; ++level) {
        int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
        int levelOffset = level * blockDim.x;
        int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

        // find gate and gate type
        int gate = levelOffset + threadIdx.x;
        int type = gateType[gate];

        unsigned long gl = value[valueStart + 0]; // good low
        unsigned long gh = value[valueStart + 1]; // good high

        // find fanin values
        int aStart = -1;
        int bStart = -1;
        if(fanin[gate * 4] != -1)
            aStart = blockOffset * 8 + fanin[gate * 4] * 8;     // fanin 0
        if(fanin[gate * 4 + 1] != -1)
            bStart = blockOffset * 8 + fanin[gate * 4 + 1] * 8; // fanin 1

        unsigned long agl   = 0x0;
        unsigned long agh   = 0x0;
        unsigned long bgl   = 0x0;
        unsigned long bgh   = 0x0;
        if (aStart != -1) {
            agl = value[aStart + 0];
            agh = value[aStart + 1];
        }
        if (bStart != -1) {
            bgl = value[bStart + 0];
            bgh = value[bStart + 1];
        }

        // perform good simulation for different gate types
        if (type == 0) // PI do not need simulation
            ;
        else if (type == 2 && level >= nLevels) { // PPI act as BUF
            gl = agl;
            gh = agh;
        }
        else if (type == 1 || type == 3 || type == 5) { // PO, PPO, and BUF
            gl = agl;
            gh = agh;
        }
        else if (type == 4) { // INV
            gl = agh;
            gh = agl;
        }
        else if (type == 6) { // AND
            gl = agl | bgl;
            gh = agh & bgh;
        }
        else if (type == 7) { // NAND
            gh = agl | bgl;
            gl = agh & bgh;
        }
        else if (type == 8) { // OR
            gl = agl & bgl;
            gh = agh | bgh;
        }
        else if (type == 9) { // NOR
            gl = agh | bgh;
            gh = agl & bgl;
        }

        // assign simulated good values back to global memory
        // faulty values and the same as good values
        value[valueStart + 0] = gl;
        value[valueStart + 1] = gh;
        value[valueStart + 2] = gl;
        value[valueStart + 3] = gh;
        __syncthreads();
    }
}

__device__ void randFill(
    int*             gateType
    , int            nLevels
    , unsigned long* value
    , unsigned long* split
) {

    int thId = threadIdx.x;
    int blId = blockIdx.x;

    // initialize random vector
    curandState rand_s;
    unsigned int seed = (unsigned int) clock64() * (threadIdx.x + 2);
    if (threadIdx.x == 0)
        curand_init(seed, blockIdx.x * threadIdx.x, 0, &rand_s);
    __syncthreads();

    for (int level = 0; level < nLevels; ++level) {
        int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
        int levelOffset = level * blockDim.x;
        int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

        // find gate and gate type
        int gate = levelOffset + threadIdx.x;
        int type = gateType[gate];


        // PIs in both time frames and PPIs in the first time frame
        if (type == 0 || (type == 2 && level < nLevels)) {
            unsigned long gl = value[valueStart + 0] | value[valueStart + 3]; // low or D bar
            unsigned long gh = value[valueStart + 1] | value[valueStart + 2]; // high or D

            // fill dont care bits and random fill
            // unsigned long rand_int = (unsigned long)(curand_uniform(&rand_s) * (4294967295 + 0.999999));
            // JKY @ 20150416 choose random values in pool
            int rand_int = (int)(curand_uniform(&rand_s) * 100000);
            unsigned long evenS = split[(rand_int+thId) % 1000];
            unsigned long dc = ~(gl ^ gh); // find dont care bits
            gl = ((~evenS) & dc) | gl;
            gh = (evenS & dc) | gh;

            // write filled values back to global memory
            value[valueStart + 0] = gl & 0xFFFFFFFF;
            value[valueStart + 1] = gh & 0xFFFFFFFF;
            value[valueStart + 2] = gl & 0xFFFFFFFF; // faulty low same as good low
            value[valueStart + 3] = gh & 0xFFFFFFFF; // faulty high same as good high
            //printf("random %d\n", rand_int);
            //printValue(gate, gl, gh);

            if (type == 0) { // fill dont cares of the corresponding PI in time frame 2
                int levelOffset = (level + nLevels) * blockDim.x;
                int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

                unsigned long gl = value[valueStart + 0] | value[valueStart + 3]; // low or D bar
                unsigned long gh = value[valueStart + 1] | value[valueStart + 2]; // high or D

                // fill dont care bits and random fill
                // unsigned long rand_int = (unsigned long)(curand_uniform(&rand_s) * 100000);
                // JKY @ 20150416 choose random values in pool
                int rand_int = (int)(curand_uniform(&rand_s) * 100000);
                unsigned long evenS = split[(rand_int+thId) % 1000];
                unsigned long dc = ~(gl ^ gh); // find dont care bits
                gl = ((~evenS) & dc) | gl;
                gh = (evenS & dc) | gh;

                // write filled values back to global memory
                value[valueStart + 0] = gl & 0xFFFFFFFF;
                value[valueStart + 1] = gh & 0xFFFFFFFF;
                value[valueStart + 2] = gl & 0xFFFFFFFF; // faulty low same as good low
                value[valueStart + 3] = gh & 0xFFFFFFFF; // faulty high same as good high
            }
        }
        else // break for all other gate types
            break;
    }
    __syncthreads();
}

__global__ void gpuGen (
    // circuit information
    int*             numRmnFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int*           faultDetect
    , unsigned long* split
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    , int*           nLevels
    , unsigned long* value
    // backtrack
    , int*           bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
    // atpg parameters
    , int*           nDetect
    , int*           abLimit
    , int*           bkLimit
    , bool*          taMode
    , bool*          getMode
    // zero copy
    , int*           nInputs
    , unsigned long* pattern
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;

    // DEBUG timer
    clock_t timerStart;
    clock_t timerStop;
    double totaltime;
    /*if (blId == 0 && thId == 0) {
        timerStart = clock();
    }*/
    __syncthreads();



    // calculate how many faults in a GPU word
    int nFaults = 32 / (*nDetect);

    //clear all the value in memory
    clearValue(value, gateType, *nLevels, ~(0x0), 0 ,0);
    __syncthreads();

    // initialize objectives for 4 faults with 4 corresponding threads
    if (thId < nFaults)
        initialObjectives(nFaults // nFaults = 4 because of 32/8 (8-detects)
                , faultGate
                , faultType
                , faultLine
                , *nLevels
                , fanin
                , value
                , *nDetect
                , *getMode
                , ~(0x0) // initial all the clone (deadMask: 1 means need to be initial)
        );
    __syncthreads();// wait for initialize objectives to finish

    __shared__ int currentLevel;           // current execution level for all clones
    __shared__ unsigned long detected;     // detection status for each clone
    __shared__ unsigned long propagatable; // propagation value at output for each clone
    __shared__ unsigned long obj;          // objective flag for each clone
    __shared__ unsigned long deadClones;   // cehck whether there is any deadclone or not
    __shared__ int nIters;                 // abort limit counter


    // thread 0 update atpg level and status
    if (thId == 0) {
        currentLevel = (*nLevels) * 2 - 1;
        detected     = 0x0;
        obj          = 0x0;
        nIters       = 0;
        deadClones   = 0xFFFFFFFF;
    }
    __syncthreads();

    initBkParam(bkPtr, deadClones);
    __syncthreads();

    if (thId == 0) {
        deadClones   = 0;
    }
    __syncthreads();


    // test generation loop
    //                          |---<---backtrack limit---<----
    //                          |                             |
    // backtrace--->propagation--->(backtrack--->propagation)--->re-initial objective----
    //    |                                                                             |
    //    --------------<-----------------abort limit---------------<--------------------
    while (true) {
        if (blId == 1 && thId == 0) {
            timerStart = clock();
        }

        if(thId==0){
            nIters++;
            obj = 0x0;
        }
        __syncthreads();

        // backtrace
        backtrace(
            (*nLevels) * 2 - 1
            , obj
            , split
            , gateType
            , gateSplit
            , fanin
            //, fanout
            , *nLevels
            , value
            // for backtrack
            , *bkStackSize
            , bkValue
            , bkPtr
            , bkGate
            , bkFlipped
        );
        __syncthreads();

        //clear all the value of btl bth
        clearValue(value, gateType, *nLevels, ~(0x0), 0, 1);
        __syncthreads();

        if(thId == 0){
            propagatable = 0x0;
            detected     = 0x0;
        }
        __syncthreads();

        // propagation
        propagation(0
            , nFaults
            , propagatable
            , detected
            , gateType
            , gateSplit
            , fanin
            , *nLevels
            , value
            , faultGate
            , faultType
            , faultLine
        );
        __syncthreads();

        if(thId == 0)
            deadClones = ~detected & ~propagatable & 0xFFFFFFFF;
        __syncthreads();

        __shared__ unsigned long StackEmpty;
        __shared__ unsigned long NeedBK;
        __shared__ int bkIters;
        if (thId == 0) {
            StackEmpty = 0x0;
            bkIters    = 0;
            NeedBK     = ~(propagatable | detected | StackEmpty) & 0xFFFFFFFF;
        }
        __syncthreads();


        // perform backtrack
        if (NeedBK != 0x0) {
            backtrack(
                deadClones
                , *nLevels
                , value
                , *bkStackSize
                , bkValue
                , bkPtr
                , bkGate
                , bkFlipped
                , &StackEmpty
            );
            if(thId == 0){
                propagatable = 0x0;
                detected     = 0x0;
            }
            __syncthreads();
            propagation(0
                , nFaults
                , propagatable
                , detected
                , gateType
                , gateSplit
                , fanin
                , *nLevels
                , value
                , faultGate
                , faultType
                , faultLine
            );

            if(thId == 0)
                deadClones = ~detected & ~propagatable & 0xFFFFFFFF;
            __syncthreads();

            // reinitialize dead clones primary fault objectives
            if (thId < nFaults)
                initialObjectives(nFaults
                    , faultGate
                    , faultType
                    , faultLine
                    , *nLevels
                    , fanin
                    , value
                    , *nDetect
                    , *getMode
                    , deadClones
                );
        }

        // check for termination condition
        if ((detected == 0xFFFFFFFF) || nIters >= *abLimit){
            if(thId == 0)
                pattern[blId] = detected;
                //pattern[blId] = 0x0;
            break;
        }
        __syncthreads();

        // initBkParam(bkPtr, deadClones);
        // __syncthreads();
    }
    //__syncthreads();

    // DEBUG timer
    //if (blId == 0 && thId == 0) {
    //    timerStop = clock();
    //    printf("+ ATPG runtime %d s\n", (timerStop - timerStart)/CLOCKS_PER_SEC);
    //    timerStart = clock();
    //}
    //__syncthreads();

    // do fault simulation after test generation
    //faultSim (
    //    numRmnFaults
    //    , split
    //    , faultGate
    //    , faultType
    //    , faultLine
    //    , faultDetect
    //    , gateType
    //    , fanin
    //    , nLevels
    //   , value
    //    , nDetect
    //    , pattern
    //);

    // DEBUG timer
    //if (blId == 0 && thId == 0) {
    //    timerStop = clock();
    //    printf("+ Simulation runtime %d s\n", (timerStop - timerStart)/CLOCKS_PER_SEC);
    //    timerStart = clock();
    //}
    randFill(gateType, (*nLevels), value, split);
    __syncthreads();


    // pattern zero copy
    zeroCopy(gateType, value, pattern, *nLevels, *nInputs);

    // DEBUG timer
    //if (blId == 0 && thId == 0) {
    //    timerStop = clock();
    //    printf("+ Zero copy runtime %d s\n", (timerStop - timerStart)/CLOCKS_PER_SEC);
    //}
    __syncthreads();
}

// clear corresponding clones' values if bit of clearClones is 1
__device__ void clearValue(unsigned long *values
    , int* gateType
    , int nLevels
    , unsigned long clearClones
    , bool pp // if pp = 1, clear all the values exclude PI in timeframe1,2 and PPI in timeframe1
    , bool bt // if bt = 1, only clear backtrace value(btl,bth)
) {

    int thId = threadIdx.x;
    //int blId = blockIdx.x;
    int level = 0;

    while (level != nLevels * 2) {
        int blockOffset = ( nLevels * 2 ) * blockDim.x * blockIdx.x; //total gate in block
        int levelOffset = level * blockDim.x; //gate number per level
        int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8; //the start point of gate

        if(bt == 0){
            //continue if in pp mode and the gate is PI or PPI(time frame 1)
            if(pp == 1 && gateType[levelOffset + thId] == 0){level++;continue;}
            if(pp == 1 && gateType[levelOffset + thId] == 2 && level < nLevels){level++;continue;}
            values[valueStart+0] &= ~clearClones;
            values[valueStart+1] &= ~clearClones;
            values[valueStart+2] &= ~clearClones;
            values[valueStart+3] &= ~clearClones;
            values[valueStart+4] &= ~clearClones;
            values[valueStart+5] &= ~clearClones;
            values[valueStart+6] &= ~clearClones;
            values[valueStart+7] &= ~clearClones;
        }
        else if(bt == 1){
            values[valueStart+4] &= ~clearClones;
            values[valueStart+5] &= ~clearClones;
        }

        level++;
    }
}

__device__ void zeroCopy(
    int*             gateType
    , unsigned long* values
    , unsigned long* pattern
    , int            nLevels
    , int            nInputs
) {
    // #######################################################################
    //   pattern sequence
    //
    //   start-- block0--    detected   [ unsigned long 32 bits            ]
    //        |  block1--    detected   [ unsigned long 32 bits            ]
    //        ...
    //        ...
    //   start-- block0-- PI0-- t0-- v0 [ unsigned long 32 bits            ]
    //        |        |     \    `- v1 [ 00100010010111010100101010101000 ]
    //        |        |      - t1-- v0 [                                  ]
    //        |        |          `- v1 [                                  ]
    //        |        +- PI1-- t0-- v0 [                                  ]
    //        |        |     \    `- v1 [                                  ]
    //        |        |      - t1-- v0 [                                  ]
    //        |        |          `- v1 [                                  ]
    //        |
    //        |        ...
    //        |
    //        |        `- PIn-- t0-- v0 [                                  ]
    //        |              \    `- v1 [                                  ]
    //        |               - t1-- v0 [                                  ]
    //        |                   `- v1 [                                  ]
    //
    //        ...
    //
    //        `
    //         -  block1-- PI0-- t0-- v0 [                                 ]
    //
    // #######################################################################

    //int thId = threadIdx.x;
    //int blId = blockIdx.x;
    int level = 0;
    int timeframe = 0;
    while (level != nLevels * 2) {

        // find gate type
        int gateLevelOffset = level * blockDim.x; //gate's number per level 
        int gateId = gateLevelOffset + threadIdx.x; 
        int type = gateType[gateId];

        if (type != 0 && type != 2) {
            timeframe = 1;
            level++;
            continue;
        }

        // find value starting point
        int gateBlockOffset = ( nLevels * 2 ) * blockDim.x * blockIdx.x;
            //gate's number per block(the total circuit gate's number * 2 timeframes ) * blockId
        int valueStart = (gateBlockOffset + gateLevelOffset + threadIdx.x) * 8;

        // find pattern starting point
        int patBlockOffset = nInputs * blockIdx.x; 
        int patPiOffset = gateId - timeframe * nLevels * blockDim.x;
        int patStart = (patBlockOffset + patPiOffset) * 4 + timeframe * 2;

        // write pattern
        pattern[patStart + 0 + gridDim.x] = values[valueStart + 0];
        pattern[patStart + 1 + gridDim.x] = values[valueStart + 1];

        // DEBUG littleshamoo
        //printValue(gateId, pattern[patStart + 0 + gridDim.x], pattern[patStart + 1 + gridDim.x]);

        level++;
    }
}

__device__ void printValue(int gateId, unsigned long v0, unsigned long v1)
{
    char vStr[33];
    vStr[32] = '\0';
    for (size_t i = 0; i < 32; ++i) {
        unsigned long v0bit = (v0 >> (31 - i)) & (unsigned long)0x01;
        unsigned long v1bit = (v1 >> (31 - i)) & (unsigned long)0x01;
        if (v0bit == 0 && v1bit == 0)
            vStr[i] = 'X';
        else if (v0bit == 1 && v1bit == 0)
            vStr[i] = '0';
        else if (v0bit == 0 && v1bit == 1)
            vStr[i] = '1';
        else
            vStr[i] = '?';
    }
    printf("Gate %d, value %s\n", gateId, vStr);
}

__device__ void propagation(
    int              currentLevel
    , int            nFaults
    , unsigned long& propagatable
    , unsigned long& detected
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    , int            nLevels
    , unsigned long* values
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;

    __shared__ int SfaultGate[4];
    __shared__ int SfaultType[4];
    __shared__ int SfaultLine[4];
    __shared__ unsigned long Sactive[4];
    __shared__ unsigned long Spp;
    __shared__ unsigned long Sdetect;

    // update "propagatable" and "detected" without race condition
    if(thId < 4){
        SfaultGate[thId] = faultGate[blId * nFaults + thId]; //nFaults = 4
        SfaultType[thId] = faultType[blId * nFaults + thId];
        SfaultLine[thId] = faultLine[blId * nFaults + thId];
        Sactive[thId]    = 0x0;
        Spp              = 0x0;
        Sdetect          = 0x0;
    }

    //clear all the values( instead of PI(1,2) and PPI(1) ) before propagation
    clearValue(values, gateType, nLevels, ~(0x0), 1, 0);
    __syncthreads();

    for(int level=currentLevel; level != nLevels * 2; ++level){

        // determine offset first
        int blockOffset = ( nLevels * 2 ) * blockDim.x * blockIdx.x;
        int levelOffset = level * blockDim.x;

        // find gate and gate type
        int gate = levelOffset + threadIdx.x;
        int type = gateType[gate];
        if (type != -1){ // do operation if not empty gate
            int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;

            int aStart=-1, bStart=-1;
            if(fanin[gate * 4] != -1)
                aStart = blockOffset * 8 + fanin[gate * 4] * 8;     // fanin 0
            if(fanin[gate * 4 + 1] != -1)
                bStart = blockOffset * 8 + fanin[gate * 4 + 1] * 8; // fanin 1


            unsigned long l   = values[valueStart + 0];
            unsigned long h   = values[valueStart + 1];
            unsigned long d   = values[valueStart + 2];
            unsigned long b   = values[valueStart + 3];
            unsigned long btl = values[valueStart + 4];
            unsigned long bth = values[valueStart + 5];
            unsigned long pp  = values[valueStart + 6];
            unsigned long x   = ~(l | h | d | b);

            unsigned long al   = 0x0;
            unsigned long ah   = 0x0;
            unsigned long ad   = 0x0;
            unsigned long ab   = 0x0;
            unsigned long abtl = 0x0;
            unsigned long abth = 0x0;
            unsigned long app  = 0x0;
            unsigned long ax   = 0x0;
            unsigned long bl   = 0x0;
            unsigned long bh   = 0x0;
            unsigned long bd   = 0x0;
            unsigned long bb   = 0x0;
            unsigned long bbtl = 0x0;
            unsigned long bbth = 0x0;
            unsigned long bpp  = 0x0;
            unsigned long bx   = 0x0;

            if(aStart != -1){
                al   = values[aStart + 0];
                ah   = values[aStart + 1];
                ad   = values[aStart + 2];
                ab   = values[aStart + 3];
                abtl = values[aStart + 4];
                abth = values[aStart + 5];
                app  = values[aStart + 6];
                ax   = ~(al | ah | ad | ab);
            }

            if(bStart != -1){
                bl   = values[bStart + 0];
                bh   = values[bStart + 1];
                bd   = values[bStart + 2];
                bb   = values[bStart + 3];
                bbtl = values[bStart + 4];
                bbth = values[bStart + 5];
                bpp  = values[bStart + 6];
                bx   = ~(bl | bh | bd | bb);
            }

            //handle D B before calculation
            for(int i = 0; i < 4; ++i){
                //D B check activation (time frame 1)
                if( level < nLevels ){
                    if(gate == SfaultGate[i] && SfaultLine[i] != 0 && SfaultType[i] == 2){//find fault gate and STR
                        Sactive[i] = (SfaultLine[i]==1 ? al : bl)>>(i*8) & 0xFF;
                    }
                    else if(gate == SfaultGate[i] && SfaultLine[i] != 0 && SfaultType[i] == 3){//find fault gate and STF
                        Sactive[i] = (SfaultLine[i]==1 ? ah : bh)>>(i*8) & 0xFF;
                    }
                }
                //D B generation (time frame 2)
                else{
                    if(gate-nLevels*blockDim.x == SfaultGate[i] && SfaultLine[i] != 0 && SfaultType[i] == 2){//find fault gate and STR
                        if(SfaultLine[i] == 1){
                            ad |= Sactive[i]<<(i*8) & ah & 0xFF<<(i*8); //if fault be activated successful
                            ah = ( ah & ~(0xFF<<(i*8)) ) | ( ~ad & ah & 0xFF<<(i*8) ); //then h be cleaned
                        }
                        else{
                            bd |= Sactive[i]<<(i*8) & bh & 0xFF<<(i*8);
                            bh = ( bh & ~(0xFF<<(i*8)) ) | ( ~bd & bh & 0xFF<<(i*8) );
                        }
                    }
                    else if(gate-nLevels*blockDim.x == SfaultGate[i] && SfaultLine[i] != 0 && SfaultType[i] == 3){//find fault gate and STF
                        if(SfaultLine[i] == 1){
                            ab |= Sactive[i]<<(i*8) & al & 0xFF<<(i*8);
                            al = ( al & ~(0xFF<<(i*8)) ) | ( ~ab & al & 0xFF<<(i*8) );
                        }
                        else{
                            bb |= Sactive[i]<<(i*8) & bl & 0xFF<<(i*8);
                            bl = ( bl & ~(0xFF<<(i*8)) ) | ( ~bb & bl & 0xFF<<(i*8) );
                        }
                    }
                }
            }

            if (type == 0) // PI do not need propagation
                ;
            else if (type == 2 && level >= nLevels) { // PPI act as BUF
                l = al;
                h = ah;
                d = ad;
                b = ab;
                pp  = app;
            }
            // PO and PPO also check propagation and detection
            else if (type == 1 || type == 3) {
                l = al;
                h = ah;
                d = ad;
                b = ab;
                pp  = app;
                atomicOr((unsigned int*) &Spp ,pp);
                atomicOr((unsigned int*) &Sdetect ,d | b);
            }
            else if (type == 5) { // BUF
                l = al;
                h = ah;
                d = ad;
                b = ab;
                pp  = app;
            }
            else if (type == 4) { // INV
                l = ah;
                h = al;
                d = ab;
                b = ad;
                btl = abth;
                bth = abtl;
                pp  = app;
            }
            else if (type == 6) { // AND
                l = al | bl | ad & bb | ab & bd;
                h = ah & bh;
                d = ad & bd | ad & bh | ah & bd;
                b = ab & bb | ab & bh | ah & bb;
                pp = ax & (bd | bb) | bx & (ad | ab);
                pp |= ~al & bpp & x;
                pp |= ~bl & app & x;
            }
            else if (type == 7) { // NAND
                h = al | bl | ad & bb | ab & bd;
                l = ah & bh;
                b = ad & bd | ad & bh | ah & bd;
                d = ab & bb | ab & bh | ah & bb;
                pp = ax & (bd | bb) | bx & (ad | ab);
                pp |= ~al & bpp & x;
                pp |= ~bl & app & x;
            }
            else if (type == 8) { // OR
                l = al & bl;
                h = ah | bh | ad & bb | ab & bd;
                d = ad & bd | ad & bl | al & bd;
                b = ab & bb | ab & bl | al & bb;
                pp = ax & (bd | bb) | bx & (ad | ab);
                pp |= ~ah & bpp & x;
                pp |= ~bh & app & x;
            }
            else if (type == 9) { // NOR
                l = ah | bh | ad & bb | ab & bd;
                h = al & bl;
                d = ab & bb | ab & bl | al & bb;
                b = ad & bd | ad & bl | al & bd;
                pp = ax & (bd | bb) | bx & (ad | ab);
                pp |= ~ah & bpp & x;
                pp |= ~bh & app & x;
            }

            //handle D B after calculation

            for(int i = 0; i < 4; ++i){
                //D B check activation (time frame 1)
                if( level < nLevels ){
                    if(gate == SfaultGate[i] && SfaultLine[i] == 0 && SfaultType[i] == 2){//find fault gate and STR
                        Sactive[i] = l>>(i*8) & 0xFF;
                    }
                    else if(gate == SfaultGate[i] && SfaultLine[i] == 0 && SfaultType[i] == 3){//find fault gate and STF
                        Sactive[i] = h>>(i*8) & 0xFF;
                    }
                }
                //D B generation (time frame 2)
                else{
                    if(gate-nLevels*blockDim.x == SfaultGate[i] && SfaultLine[i] == 0 && SfaultType[i] == 2){//find fault gate and STR
                        d |= Sactive[i]<<(i*8) & h & 0xFF<<(i*8);
                        h = ( h & ~(0xFF<<(i*8)) ) | ( ~d & h & 0xFF<<(i*8) ) & 0xFFFFFFFF;
                    }
                    else if(gate-nLevels*blockDim.x == SfaultGate[i] && SfaultLine[i] == 0 && SfaultType[i] == 3){//find fault gate and STF
                        b |= Sactive[i]<<(i*8) & l & 0xFF<<(i*8);
                        l = ( l & ~(0xFF<<(i*8)) ) | ( ~b & l & 0xFF<<(i*8) ) & 0xFFFFFFFF;
                    }
                }
            }

            // l and h update above
            values[valueStart + 0] = l;
            values[valueStart + 1] = h;
            atomicOr((unsigned int*) &values[valueStart + 2] ,d);
            atomicOr((unsigned int*) &values[valueStart + 3] ,b);
            atomicOr((unsigned int*) &values[valueStart + 4] ,btl);
            atomicOr((unsigned int*) &values[valueStart + 5] ,bth);
            atomicOr((unsigned int*) &values[valueStart + 6] ,pp);

            if(aStart != -1){
                atomicOr((unsigned int*) &values[aStart + 0] ,al);
                atomicOr((unsigned int*) &values[aStart + 1] ,ah);
                atomicOr((unsigned int*) &values[aStart + 2] ,ad);
                atomicOr((unsigned int*) &values[aStart + 3] ,ab);
                atomicOr((unsigned int*) &values[aStart + 6] ,app);
            }

            if(bStart != -1){
                atomicOr((unsigned int*) &values[bStart + 0] ,bl);
                atomicOr((unsigned int*) &values[bStart + 1] ,bh);
                atomicOr((unsigned int*) &values[bStart + 2] ,bd);
                atomicOr((unsigned int*) &values[bStart + 3] ,bb);
                atomicOr((unsigned int*) &values[bStart + 6] ,bpp);
            }
        }
        __syncthreads();
        if(thId == 0){
            propagatable |= Spp;
            detected |= Sdetect;
        }
        __syncthreads();
    }
}

__device__ void backtrace(
    int              currentLevel
    , unsigned long& obj
    , unsigned long* split
    , int*           gateType
    , int*           gateSplit
    , int*           fanin
    //, int*           fanout
    , int            nLevels
    , unsigned long* value
    // for backtrack
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;
    // use share memory to track PI assignments
    __shared__ int           assignedId[128]; //gate Id will be assigned value
    __shared__ unsigned long assignedV0[128]; //current assign V0
    __shared__ unsigned long assignedV1[128]; //current assign V1
    __shared__ unsigned long prevV0[128]; //previous V0 value
    __shared__ unsigned long prevV1[128]; //previous V1 value

    for(int level=currentLevel; level != -1; level--){

        // clear assigned gates
        assignedId[thId] = -1;
        assignedV0[thId] = 0x0;
        assignedV1[thId] = 0x0;
        prevV0[thId]     = 0x0;
        prevV1[thId]     = 0x0;

        // determine offset
        int blockOffset = ( nLevels * 2) * blockDim.x * blockIdx.x; //#gate per block
        int levelOffset = level * blockDim.x; //#gate per level

        // find gate and gate type
        int gate = levelOffset + threadIdx.x; //gateId
        if(gate < 0)break;// JKY @ 20150113 level may not updated when checking != -1
        int type = gateType[gate];

        if (type != -1){ // empty gate. cannot use continue because traceAssignment need all the thread

            //rand() is not available, use this instead.
            __shared__ curandState rand_s;
            unsigned int seed = (unsigned int) clock64() * (thId+2);
            if(thId==0)curand_init(seed, blId*thId, 0, &rand_s);

            // find split vector
            int rand_int = (int)(curand_uniform(&rand_s) * 100000);
            unsigned long evenS = split[rand_int % 1000];

            rand_int = (int)(curand_uniform(&rand_s) * 1000000);
            unsigned long s = split[gateSplit[gate] * 1000 + rand_int % 1000];

            // stem backtrace for all types of gates
            int valueStart = (blockOffset + levelOffset) * 8 + threadIdx.x * 8;
            unsigned long stemBtl = value[valueStart + 4]; //btl
            unsigned long stemBth = value[valueStart + 5]; //bth
            unsigned long tempBtl = stemBtl;
            unsigned long tempBth = stemBth;

            //Btl & Bth no conflict or random choose
            stemBtl = (tempBtl & ~tempBth) | (tempBtl & tempBth & evenS);  
            stemBth = (tempBth & ~tempBtl) | (tempBtl & tempBth & ~evenS);
            value[valueStart + 4] = stemBtl;
            value[valueStart + 5] = stemBth;

            int aStart=-1, bStart=-1;
            if(fanin[gate * 4] != -1)
                aStart = blockOffset * 8 + fanin[gate * 4] * 8;     // fanin 0
            if(fanin[gate * 4 + 1] != -1)
                bStart = blockOffset * 8 + fanin[gate * 4 + 1] * 8; // fanin 1

            unsigned long l   = value[valueStart + 0];
            unsigned long h   = value[valueStart + 1];
            unsigned long d   = value[valueStart + 2];
            unsigned long b   = value[valueStart + 3];
            unsigned long btl = value[valueStart + 4];
            unsigned long bth = value[valueStart + 5];
            unsigned long pp  = value[valueStart + 6];
            unsigned long al  = 0x0;
            unsigned long ah  = 0x0;
            unsigned long ad  = 0x0;
            unsigned long ab  = 0x0;
            unsigned long abtl= 0x0;
            unsigned long abth= 0x0;
            unsigned long app = 0x0;
            unsigned long ax  = 0x0;
            unsigned long bl  = 0x0;
            unsigned long bh  = 0x0;
            unsigned long bd  = 0x0;
            unsigned long bb  = 0x0;
            unsigned long bbtl= 0x0;
            unsigned long bbth= 0x0;
            unsigned long bpp = 0x0;
            unsigned long bx  = 0x0;
            unsigned long x   = ~(l | h | d | b);
            if(aStart != -1){
                al   = value[aStart + 0];
                ah   = value[aStart + 1];
                ad   = value[aStart + 2];
                ab   = value[aStart + 3];
                abtl = value[aStart + 4];
                abth = value[aStart + 5];
                app  = value[aStart + 6];
                ax   = ~(al | ah | ad | ab);
            }

            if(bStart != -1){
                bl   = value[bStart + 0];
                bh   = value[bStart + 1];
                bd   = value[bStart + 2];
                bb   = value[bStart + 3];
                bbtl = value[bStart + 4];
                bbth = value[bStart + 5];
                bpp  = value[bStart + 6];
                bx   = ~(bl | bh | bd | bb);
            }
            // backtrace equations for all types of gates
            if (type == 0 || (type == 2 && level < nLevels)) { // PI and PPI do assignment instead
                // need to check both l and b, h and d
                unsigned long Low       = l | b;
                unsigned long High      = h | d;
                unsigned long LowCheck  = (Low ^ btl) & x; //check is Low and btl conflict or not
                unsigned long HighCheck = (High ^ bth) & x;
                //!=0x0 means x = 11...11(can assign value) and "Low=0, btl=1" or "Low=1,btl=0"
                if (LowCheck != 0x0 || HighCheck != 0x0) {
                    assignedId[threadIdx.x] = gate;
                    assignedV0[threadIdx.x] = (btl & x) | Low; //assign 0
                    assignedV1[threadIdx.x] = (bth & x) | High; //assign 1
                    prevV0[threadIdx.x]     = Low; //previous Low value
                    prevV1[threadIdx.x]     = High; //previous High value
                    value[valueStart + 0]   |= btl & x; //update value
                    value[valueStart + 1]   |= bth & x;
                }
            }
            else if (type == 2 && level >= nLevels) {//PPI in time frame 2 do backtrace as BUF
                abtl = btl;
                abth = bth;
                app  = pp;
            }
            else if (type == 1 || type == 3 || type == 5) { // PO, PPO, and BUF
                abtl = btl;
                abth = bth;
                app  = pp;
            }
            else if (type == 4) { // INV
                abtl = bth;
                abth = btl;
                app  = pp;
            }
            else if (type == 6) { // AND
                abth  = ax &  (bd | bb) & pp & ~obj;
                abth |= ax & ~(bl | bb) & bth;
                abth |= ax &  (bd | bb) & bth;
                abtl  = ax &  bx  & btl & s;
                abtl |= ax &  (bh | bd | bb) & btl;
                bbth  = bx &  (ad | ab) & pp & ~obj;
                bbth |= bx & ~(al | ab) & bth;
                bbth |= bx &  (ad | ab) & bth & s;
                bbtl  = bx &  ax  & btl & ~s;
                bbtl |= bx &  (ah | ad | ab) & btl;
                atomicOr((unsigned int*) &obj ,abth | abtl | bbth | bbtl);

                app   = app & ~bpp & pp & ~obj;
                app  |= app & bpp  & pp & ~obj & s;
                bpp   = bpp & ~app & pp & ~obj;
                bpp  |= app & bpp  & pp & ~obj & ~s;
            }
            else if (type == 7) { // NAND
                abth  = ax &  (bd | bb) & pp & ~obj;
                abth |= ax & ~(bl | bb) & btl;
                abth |= ax &  (bd | bb) & btl;
                abtl  = ax &  bx  & bth & s;
                abtl |= ax &  (bh | bd | bb) & bth;
                bbth  = bx &  (ad | ab) & pp & ~obj;
                bbth |= bx & ~(al | ab) & btl;
                bbth |= bx &  (ad | ab) & btl & s;
                bbtl  = bx &  ax  & bth & ~s;
                bbtl |= bx &  (ah | ad | ab) & bth;
                atomicOr((unsigned int*) &obj ,abth | abtl | bbth | bbtl);

                app   = app & ~bpp & pp & ~obj;
                app  |= app & bpp  & pp & ~obj & s;
                bpp   = bpp & ~app & pp & ~obj;
                bpp  |= app & bpp  & pp & ~obj & ~s;
            }
            else if (type == 8) { // OR
                abtl  = ax &  (bd | bb) & pp & ~obj;
                abtl |= ax & ~(bh | bd) & btl;
                abtl |= ax &  (bd | bb) & btl;
                abth  = ax &  bx  & bth & s;
                abth |= ax &  (bl | bd | bb) & bth;
                bbtl  = bx &  (ad | ab) & pp & ~obj;
                bbtl |= bx & ~(ah | ad) & btl;
                bbtl |= bx &  (ad | ab) & btl;
                bbth  = bx &  ax  & bth & ~s;
                bbth |= bx &  (al | ad | ab) & bth;
                atomicOr((unsigned int*) &obj ,abth | abtl | bbth | bbtl);

                app   = app & ~bpp & pp & ~obj;
                app  |= app & bpp  & pp & ~obj & s;
                bpp   = bpp & ~app & pp & ~obj;
                bpp  |= app & bpp  & pp & ~obj & ~s;
            }
            else if (type == 9) { // NOR
                abtl  = ax &  (bd | bb) & pp & ~obj;
                abtl |= ax & ~(bh | bd) & bth;
                abtl |= ax &  (bd | bb) & bth;
                abth  = ax &  bx  & btl & s;
                abth |= ax &  (bl | bd | bb) & btl;
                bbtl  = bx &  (ad | ab) & pp & ~obj;
                bbtl |= bx & ~(ah | ad) & bth;
                bbtl |= bx &  (ad | ab) & bth;
                bbth  = bx &  ax  & btl & ~s;
                bbth |= bx &  (al | ad | ab) & btl;
                atomicOr((unsigned int*) &obj ,abth | abtl | bbth | bbtl);

                app   = app & ~bpp & pp & ~obj;
                app  |= app & bpp  & pp & ~obj & s;
                bpp   = bpp & ~app & pp & ~obj;
                bpp  |= app & bpp  & pp & ~obj & ~s;
            }

            // update fanin value // JKY @ 20141104
            if(aStart != -1){
                atomicOr((unsigned int*) &value[aStart + 4] ,abtl);
                atomicOr((unsigned int*) &value[aStart + 5] ,abth);
                atomicOr((unsigned int*) &value[aStart + 6] ,app);
            }
            if(bStart != -1){
                atomicOr((unsigned int*) &value[bStart + 4] ,bbtl);
                atomicOr((unsigned int*) &value[bStart + 5] ,bbth);
                atomicOr((unsigned int*) &value[bStart + 6] ,bpp);
            }
        }
        __syncthreads();

        // track assignments for backtrack
        trackAssignment(
            assignedId
            , assignedV0
            , assignedV1
            , prevV0
            , prevV1
            , bkStackSize
            , bkValue
            , bkPtr
            , bkGate
            , bkFlipped
        );
        __syncthreads();
    }
}


__device__ void trackAssignment(
    int*             assignedId
    , unsigned long* assignedV0
    , unsigned long* assignedV1
    , unsigned long* prevV0
    , unsigned long* prevV1
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;

    // handle 128 gates separately
    for (int i = 0; i < blockDim.x; ++i) {

        // skip if no assignments
        int skip = false;
        if (assignedId[i] == -1) {
            skip = true;
        }
        if (skip)
            continue;

        int gateId = assignedId[i];
        unsigned long pV0 = prevV0[i];
        unsigned long pV1 = prevV1[i];
        unsigned long aV0 = assignedV0[i];
        unsigned long aV1 = assignedV1[i];
        if (thId < 32) { // only need 32 threads to handle 32 clones
            // shift bits to find the clone of interest
            int vpV0 = (int)((pV0 >> (thId)) & 0x01);
            int vpV1 = (int)((pV1 >> (thId)) & 0x01);
            int vaV0 = (int)((aV0 >> (thId)) & 0x01);
            int vaV1 = (int)((aV1 >> (thId)) & 0x01);
            if (vpV0 == vaV0 && vpV1 == vaV1) //assign value like previous, do nothing
                ;
            else {
                // find assignment value
                int va = 0;
                if (vaV1 != 0) //vaV1 = 1, va = 1
                    va = 1;
                // put assignment into the stack
                int offset = (blId * 32 + thId) * bkStackSize; //bkValue offset
                int ptr = bkPtr[blId * 32 + thId]; //back track ptr
                bkPtr[blId * 32 + thId]++; //put new one into stack, Ptr++
                ptr++;
                bkValue[offset + ptr] = va;
                bkGate[offset + ptr] = gateId;
                bkFlipped[offset + ptr] = false;
            }
        }
        __syncthreads();
    }
}


__device__ void backtrack(
    unsigned long    deadClones
    , int            nLevels
    , unsigned long* value
    , int            bkStackSize
    , int*           bkValue
    , int*           bkPtr
    , int*           bkGate
    , bool*          bkFlipped
    , unsigned long* StackEmpty
) {
    int thId = threadIdx.x;
    int blId = blockIdx.x;
    int dead;

    if(thId < 32)
        dead = (int)(deadClones >> thId) & 0x01; //check this clone is dead or not

    __syncthreads();// JKY @ 20150113

    if (thId >= 32)
        ;
    // clone not dead, no need for backtrack
    else if( dead == 0 )
        ;
    else {
        int offset = (blId * 32 + thId) * bkStackSize;
        int ptr = bkPtr[blId * 32 + thId];
        if (ptr == -1 && ptr < bkStackSize) // stack empty
            atomicOr( (unsigned int*) StackEmpty ,(unsigned int)(0x01 << thId));
        else {
            // find unflipped assignment
            while (ptr > -1 && ptr < bkStackSize) {
                int va = bkValue[offset + ptr];
                int gateId  = bkGate[offset + ptr];
                bool flipped = bkFlipped[offset + ptr];
                int blockOffset = (nLevels * 2) * blockDim.x * blockIdx.x;
                int valueStart = (blockOffset + gateId) * 8;
                if (flipped) { // reset gate value to X //flipped = true means has been flipped
                    atomicAnd( (unsigned int*) &value[valueStart + 0] ,(unsigned int)(~(0x01 << thId)) );
                    atomicAnd( (unsigned int*) &value[valueStart + 1] ,(unsigned int)(~(0x01 << thId)) );
                    bkPtr[blId * 32 + thId]--;
                }
                else {
                    // determine backtrack value
                    if (va == 0){
                        atomicAnd( (unsigned int*) &value[valueStart + 0] ,(unsigned int)(~(0x01 << thId)) );
                        atomicOr ( (unsigned int*) &value[valueStart + 1] ,(unsigned int)( (0x01 << thId)) );
                    }
                    else{
                        atomicOr ( (unsigned int*) &value[valueStart + 0] ,(unsigned int)( (0x01 << thId)) );
                        atomicAnd( (unsigned int*) &value[valueStart + 1] ,(unsigned int)(~(0x01 << thId)) );
                    }
                    bkFlipped[offset + ptr] = 1;
                    break;
                }
                ptr = bkPtr[blId * 32 + thId];
            }
            //__syncthreads();
        }
    }
    __syncthreads();
}

__device__ void initBkParam(int* bkPtr, unsigned long & deadClones)
{
    // first 32 threads initialize backtrack parameters
    // since we have 32 clones. If number of threads is
    // less than 32, we loop available threads.
    int nClones = 32;
    if(threadIdx.x < 32)
        if(deadClones & (0x01<<threadIdx.x) != 0x0)
            bkPtr[blockIdx.x * nClones + threadIdx.x] = -1;
}

__device__ void initialObjectives (
    int              nFaults
    , int*           faultGate
    , int*           faultType
    , int*           faultLine
    , int            nLevels
    , int*           fanin
    , unsigned long* value
    , int            nDetect
    , bool           getMode
    , unsigned long  deadMask
) {

    int thId = threadIdx.x;
    int blId = blockIdx.x;

    // generate mask that has number of ones equal to nDetect
    unsigned long mask = 0x0;
    for (int i = 0; i < nDetect; ++i) {
        mask <<= 1;
        mask |= 0x1;
    }
    // shift to the position that is used by this thread
    mask <<= nDetect * thId;// JKY @ 20141101 thId

    int gate = faultGate[blId * nFaults + thId];
    int type = faultType[blId * nFaults + thId];
    int line = faultLine[blId * nFaults + thId];
    unsigned long t1btl = 0x0;
    unsigned long t1bth = 0x0;
    unsigned long t2btl = 0x0;
    unsigned long t2bth = 0x0;
    if (type == 2) { // slow-to-rise
        t1btl = ~(0x0);
        t2bth = ~(0x0);
    }
    else if (type == 3) { // slow-to-fall
        t1bth = ~(0x0);
        t2btl = ~(0x0);
    }

    int btGate = gate; // find backtrace gate. Default output of the faulty gate
    if (line > 0) //find fanin gate (fault on input)
        btGate = fanin[gate * 4 + line - 1];

    // find btGate in time frame 2
    int nGates = blockDim.x * nLevels; //total gate's number  of t1 circuit(#gate/level * total level)
    int nGatesPerFrame = nGates;
    int btGateT2 = btGate + nGatesPerFrame;

    // set backtrace value
    // value index: 0: L, 1: H, 2: D, 3: B, 4: btl, 5: bth, 6: pp, 7: x
    // deadMask are used to give second chance to dead clones
    // If the mask is 0, it means the clone is dead. Else it's alive and no
    // values will be changed

    atomicOr ( (unsigned int*) &value[blId * nGates * 8 * 2 + btGate * 8 + 4] ,t1btl & mask & deadMask);
    atomicOr ( (unsigned int*) &value[blId * nGates * 8 * 2 + btGate * 8 + 5] ,t1bth & mask & deadMask);
    atomicOr ( (unsigned int*) &value[blId * nGates * 8 * 2 + btGateT2 * 8 + 4] ,t2btl & mask & deadMask);
    atomicOr ( (unsigned int*) &value[blId * nGates * 8 * 2 + btGateT2 * 8 + 5] ,t2bth & mask & deadMask);
}

void SwkGpuAtpg::allocAtpgParameters() {
    cudaMalloc((void**)&gpuNDetect_, sizeof(int));
    cudaMalloc((void**)&gpuDcLimit_, sizeof(int));
    cudaMalloc((void**)&gpuBkLimit_, sizeof(int));
    cudaMalloc((void**)&gpuTaMode_,  sizeof(bool));
    cudaMalloc((void**)&gpuGetMode_, sizeof(bool));

    cudaMemcpy(gpuNDetect_, &nDetect_, sizeof(int),  cudaMemcpyHostToDevice);
    cudaMemcpy(gpuDcLimit_, &abLimit_, sizeof(int),  cudaMemcpyHostToDevice);
    cudaMemcpy(gpuBkLimit_, &bkLimit_, sizeof(int),  cudaMemcpyHostToDevice);
    cudaMemcpy(gpuTaMode_,  &taMode_,  sizeof(bool), cudaMemcpyHostToDevice);
    cudaMemcpy(gpuGetMode_, &getMode_, sizeof(bool), cudaMemcpyHostToDevice);

    // for backtrack memory allocation. By littleshamoo
    //
    //                                               bkStackSize
    //                                      ______________/\_____________
    //                                     /                             \
    //   gpuBkValue_ -- block0 --  clone0  [ | | | | | | | | | | ... | | ]
    //               |         +-  clone1  [ | | | | | | | | | | ... | | ]
    //               |         +-  clone2  [ | | | | | | | | | | ... | | ]
    //               ...       ...
    //               |         `-  clone31 [ | | | | | | | | | | ... | | ]
    //               |
    //               `- block1 --  clone0  [ | | | | | | | | | | ... | | ]
    //
    int nClones = nBlocks_ * 32;
    cudaMalloc((void**)&gpuBkStackSize_, sizeof(int));
    cudaMalloc((void**)&gpuBkValue_,     sizeof(int)  * nClones * bkStackSize_);
    cudaMalloc((void**)&gpuBkPtr_,       sizeof(int)  * nClones);
    cudaMalloc((void**)&gpuBkGate_,      sizeof(int)  * nClones * bkStackSize_);
    cudaMalloc((void**)&gpuBkFlipped_,   sizeof(bool) * nClones * bkStackSize_);
    cudaMemcpy(gpuBkStackSize_, &bkStackSize_, sizeof(int), cudaMemcpyHostToDevice);
}
