// **************************************************************************
// File       [ memory_allocator.h ]
// Author     [ littleshamoo ]
// Synopsis   [ Allocate GPU memory ]
// History    [ Version 1.0 2012/03/13 ]
// **************************************************************************

#ifndef __CORE_MEMORY_ALLOCATOR_H__
#define __CORE_MEMORY_ALLOCATOR_H__

#include "circuit.h"
#include <vector>

namespace CoreNs {
class MemoryAllocator {
public:
    MemoryAllocator(Circuit *cir, bool taMode, size_t nBlocks, size_t nThreads) :
        cir_(cir)
        , taMode_(taMode)
        , nBlocks_(nBlocks)
        , nThreads_(nThreads){};
    ~MemoryAllocator(){};

    // memory layout
    // **********************************************************************
    // faultGate_: fault gates. 32 * nBlocks (GPU word size) faults at a time
    // The data stored here is gateID of GPU
    // +-----+-----+-----+------+
    // | fg0 | fg1 | ... | fgn  |
    // +-----+-----+-----+------+
    //
    // faultType_: fault types. 32 * nBlocks (GPU word size) faults at a time
    //             fault type number is the same as those in fault.h
    // +-----+-----+-----+------+
    // | ft0 | ft1 | ... | ftn  |
    // +-----+-----+-----+------+
    //
    // faultLine_: fault lines. 32 * nBlocks (GPU word size) faults at a time
    //             fault line number is the same as those in fault.h
    //             0 means output, 1+ means the corresponding input index
    // +-----+-----+-----+------+
    // | fl0 | fl1 | ... | fln  |
    // +-----+-----+-----+------+
    //
    // split_: split vector pool with different zero-one ratios
    // +-----+-----+-----+-----+-----+
    // | 1:1 | 3:1 | 7:1 | 1:3 | 1:7 |
    // +-----+-----+-----+-----+-----+
    // |vecs |vecs |vecs |vecs |vecs |
    // +-----+-----+-----+-----+-----+
    //
    // All gates related vectors are arranged in the following fashion.
    // Each level contains number of gates equal to number of threads.
    // This is to balance different number of gates within each level.
    // Empty cell have type -1. (Which means NA. Same as gate.h)
    //
    //  original    ___ m threads ___       GPU
    //   level     /                 \     level
    //            +----+----+----+----+
    //     0      | G0 | G1 |... | Gm |      0
    //            +----+----+----+----+
    //     0      | m+1| m+2|... | G2m|      1
    //            +----+----+----+----+
    //     0      |2m+1| m+2|... | -1 |      2
    //            +----+----+----+----+
    //            ...
    //
    //          
    // gateType_: gate type
    // +----+----+----+----+
    // | G0 | G1 |... | Gn |
    // +----+----+----+----+
    // |type|type|... |type|
    // +----+----+----+----+
    //
    // gateSplit_: indicates which split vector pool the gate uses.
    //             See split_ to see different zero-one ratio vector pools.
    // +----+----+----+----+
    // | G0 | G1 |... | Gn |
    // +----+----+----+----+
    // |pool|pool|... |pool|
    // +----+----+----+----+
    //
    // fanins_: gate fanin vector. Maximum 4 fanins. -1 means not connected
    // +-----------+-----------+----+-----------+
    // |    G0     |    G1     |... |    Gn     |
    // +--+--+--+--+--+--+--+--+----+--+--+--+--+
    // |i0|i1|i2|i3|i0|i1|i2|i3|... |i0|i1|i2|i3|
    // +--+--+--+--+--+--+--+--+----+--+--+--+--+
    //
    // fanouts_: gate fanout vector. Maximum 8 fanouts. -1 means not connected
    // +----------+----------+----+----------+
    // |    G0    |    G1    |... |    Gn    |
    // +--+----+--+--+----+--+----+--+----+--+
    // |o0|... |o7|o0|... |o7|... |o0|... |o7|
    // +--+----+--+--+----+--+----+--+----+--+
    //
    // values_: gate values. Each gate has 8 values. Each block has its own
    //          copy of values. For example, if nBlocks = 64, there are 64
    //          copies of values.
    // +--------------------+----+----------+ `
    // |         G0         |... |    Gn    |  `
    // +-+-+-+-+---+---+--+-+----+-+-+-+----+   > block 0
    // |L|H|D|B|BtL|BtH|Pp|X|... |L|H|D|... |  '
    // +-+-+-+-+---+---+--+-+----+----------+ '
    // +--------------------+----+----------+ `
    // |         G0         |... |    Gn    |  `
    // +-+-+-+-+---+---+--+-+----+-+-+-+----+   > block 1
    // |L|H|D|B|BtL|BtH|Pp|X|... |L|H|D|... |  '
    // +-+-+-+-+---+---+--+-+----+----------+ '
    // ...
    // +--------------------+----+----------+ `
    // |         G0         |... |    Gn    |  `
    // +-+-+-+-+---+---+--+-+----+-+-+-+----+   > block m
    // |L|H|D|B|BtL|BtH|Pp|X|... |L|H|D|... |  '
    // +-+-+-+-+---+---+--+-+----+----------+ '
    // **********************************************************************
    void alloc(int nfaults);

    // return device pointers
    int* faultGateGpuPtr() { return gpuFaultGate_; }
    int* faultDetectGpuPtr() { return gpuFaultDetect_; }
    int* faultTypeGpuPtr() { return gpuFaultType_; }
    int* faultLineGpuPtr() { return gpuFaultLine_; }
    unsigned long* splitGpuPtr()     { return gpuSplit_;     }
    int* gateTypeGpuPtr()  { return gpuGateType_;  }
    int* gateSplitGpuPtr() { return gpuGateSplit_; }
    int* faninsGpuPtr()    { return gpuFanins_;    }
    //int* fanoutsGpuPtr()   { return gpuFanouts_;   }
    int* nLevelsGpuPtr()   { return gpuNLevels_;   }
    int* nInputsGpuPtr()   { return gpuNInputs_;   }
    unsigned long* valuesGpuPtr()    { return gpuValues_;    }

    // ID mapping
    int gpuId(int cpuId)   { return cpuIdToGpuId_[cpuId]; }

private:
    Circuit* cir_;
    bool     taMode_;   // timing-aware mode.
    size_t   nBlocks_;  // number of blocks.
    size_t   nThreads_; // number of threads.

    // cpu id to gpu id mapping
    std::vector<int> cpuIdToGpuId_;

    // transform data in classes into one dimension arrays
    void transform();

    // generate split vectors with different zero-one ratios
    std::vector<ParaValue> genSpVec(float ratio);

    // cpu memory pointers
    unsigned long* cpuSplit_; // JKY @ 20141112 int* cpuSplit_;
    int* cpuGateType_;
    int* cpuGateSplit_;
    int* cpuFanin_;
    int* cpuNLevels_;
    int* cpuNInputs_;


    // gpu memory pointers
    int* gpuFaultGate_;
    int* gpuFaultDetect_;
    int* gpuFaultType_;
    int* gpuFaultLine_;
    unsigned long* gpuSplit_;
    int* gpuGateType_;
    int* gpuGateSplit_;
    int* gpuFanins_;
    int* gpuNLevels_;
    int* gpuNInputs_;
    unsigned long* gpuValues_;

    // memory size
    size_t nTotalFaults_;
    size_t nSplits_;
    size_t nGateTypes_;
    size_t nGateSplits_;
    size_t nFanins_;
    //size_t nFanouts_;
    size_t nValues_;
    size_t nLevels_;
};
};
#endif


