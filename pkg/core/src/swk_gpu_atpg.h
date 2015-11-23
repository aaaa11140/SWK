// **************************************************************************
// File       [ swk_gpu_atpg.h ]
// Author     [ littleshamoo ]
// Synopsis   [ SWK ATPG GPU version ]
// History    [ Version 1.0 2010/02/04 ]
// **************************************************************************

#ifndef __SWK_GPU_ATPG_H__
#define __SWK_GPU_ATPG_H__

#include "simulator.h"
#include "pattern.h"
#include "fault.h"
#include "memory_allocator.h"
#include "SddCudaSim.h"

namespace CoreNs{ 
class SwkGpuAtpg {
public:
    SwkGpuAtpg(Circuit *cir, MemoryAllocator *memAlloc) {
        cir_         = cir;
        memAlloc_    = memAlloc;
        nDetect_     = 8;
        abLimit_     = 10;
        bkLimit_     = 3;
        nBlocks_     = 64;
        nThreads_    = 128;
        taMode_      = false;
        getMode_     = false;
        nPatterns_   = 0;
        nInputs_     = 0;
        bkStackSize_ = 1000;
        sim_         = new Simulator(cir_);
    }
    ~SwkGpuAtpg() {
        delete sim_;
    }

    void gen(PatternColl *pCol, FaultColl *fCol);

    int  nDetect_;  // target number of detection
    int  abLimit_;  // dynamic compaction limit
    int  bkLimit_;  // backtrack limit
    int  nBlocks_;  // number of blocks on GPU
    int  nThreads_; // number of threads on GPU
    bool taMode_;   // timing-aware mode
    bool getMode_;  // gate exhaustive transition mod

    SddCudaSim*      sddcudaSim;

protected:
    Circuit*         cir_;
    Simulator*       sim_;
    MemoryAllocator* memAlloc_;

    // memory sizes
    int            nPatterns_;
    int            nInputs_;
    int            bkStackSize_;

    // cpu memory
    int*           cpuFaultGate_;
    int*           cpuFaultDetect_;
    int*           cpuFaultType_;
    int*           cpuFaultLine_;
    int*           cpuNumRmnFaults_;
    int*           cpuNumPrimaryFaults_;
    unsigned long* cpuPattern_;

    //unsigned long* Pattern_c; // memory for patterns in CPU

    // gpu memory
    int*           gpuNDetect_;
    int*           gpuDcLimit_;
    int*           gpuBkLimit_;
    bool*          gpuTaMode_;
    bool*          gpuGetMode_;
    unsigned long* gpuPattern_;
    int*           gpuBkStackSize_;
    int*           gpuBkValue_;
    int*           gpuBkPtr_;
    int*           gpuBkGate_;
    bool*          gpuBkFlipped_;
    int*           gpuNumRmnFaults_;

    void allocAtpgParameters();
    void allocFaults(FaultList& rmnFault);
    void dropFaults(FaultList& rmnGenFault, FaultList& rmnSimFault, PatternColl* pCol);
    void zeroCopyPreparation();
    int  NumberOfSetBits(unsigned long i);
    //void printPatterns();
    void WritePattern(PatternColl *pCol, int TotalBlocks);
};

};
#endif


