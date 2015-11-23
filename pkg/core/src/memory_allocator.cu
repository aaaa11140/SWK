// **************************************************************************
// File       [ memory_allocator.cu ]
// Author     [ littleshamoo ]
// Synopsis   [ Allocate GPU memory ]
// History    [ Version 1.0 2012/03/13 ]
// **************************************************************************

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
//#include <cutil.h>
//#include <cutil_inline.h>
#include <iomanip>
//#include "helper_cuda.h"
#include "pattern.h"
#include "fault.h"
#include "logic.h"

#include "memory_allocator.h"
using namespace CoreNs;
using namespace std;
void MemoryAllocator::alloc(int nFaults) {
    nTotalFaults_ = nFaults;
    transform();
    cudaSetDevice(0);
    cudaDeviceReset();

    // allocate only
    cudaMalloc((void**)&gpuFaultGate_, sizeof(int)*(nTotalFaults_));
    cudaMalloc((void**)&gpuFaultDetect_, sizeof(int)*(nTotalFaults_));
    cudaMalloc((void**)&gpuFaultType_, sizeof(int)*(nTotalFaults_));
    cudaMalloc((void**)&gpuFaultLine_, sizeof(int)*(nTotalFaults_));
    cudaMalloc((void**)&gpuValues_,    sizeof(unsigned long)*(nValues_));

    // allocate and copy
    cudaMalloc((void**)&gpuSplit_,     sizeof(unsigned long)*(nSplits_));
    cudaMalloc((void**)&gpuGateType_,  sizeof(int)*(nGateTypes_));
    cudaMalloc((void**)&gpuGateSplit_, sizeof(int)*(nGateSplits_));
    cudaMalloc((void**)&gpuFanins_,    sizeof(int)*(nFanins_));
    cudaMalloc((void**)&gpuNLevels_,   sizeof(int)*(nLevels_));
    cudaMalloc((void**)&gpuNInputs_,   sizeof(int));
    cudaMemcpy(gpuSplit_,     cpuSplit_,     sizeof(unsigned long)*(nSplits_), cudaMemcpyHostToDevice);
    cudaMemcpy(gpuGateType_,  cpuGateType_,  sizeof(int)*(nGateTypes_),        cudaMemcpyHostToDevice);
    cudaMemcpy(gpuGateSplit_, cpuGateSplit_, sizeof(int)*(nGateSplits_),       cudaMemcpyHostToDevice);
    cudaMemcpy(gpuFanins_,    cpuFanin_,     sizeof(int)*(nFanins_),           cudaMemcpyHostToDevice);
    cudaMemcpy(gpuNLevels_,   cpuNLevels_,   sizeof(int)*(nLevels_),           cudaMemcpyHostToDevice);
    cudaMemcpy(gpuNInputs_,   cpuNInputs_,   sizeof(int),                      cudaMemcpyHostToDevice);
}

void MemoryAllocator::transform() {

    // allocate split vector pool on GPU
    // 5 pools of vectors with different zero-one ratios as in memry_allocator.h
    // each pool contains 1000 vectors
    nSplits_ = 5 * 1000;
    cpuSplit_ = new unsigned long[nSplits_];
    vector<ParaValue> sp11 = genSpVec(1.0);
    vector<ParaValue> sp31 = genSpVec(3.0);
    vector<ParaValue> sp71 = genSpVec(7.0);
    vector<ParaValue> sp13 = genSpVec(0.333);
    vector<ParaValue> sp17 = genSpVec(0.143);
    for (size_t i = 0; i < 1000; ++i)
        cpuSplit_[i] = sp11[i];
    for (size_t i = 0; i < 1000; ++i)
        cpuSplit_[1000 + i] = sp31[i];
    for (size_t i = 0; i < 1000; ++i)
        cpuSplit_[2000 + i] = sp71[i];
    for (size_t i = 0; i < 1000; ++i)
        cpuSplit_[3000 + i] = sp13[i];
    for (size_t i = 0; i < 1000; ++i)
        cpuSplit_[4000+ i] = sp17[i];

    // Transform circuit. Number of gates within each level will be equal
    // to number of threads. Record number of gates in original level and
    // mapping of orginal level to new level.
    vector<int> nGatesInOrgLevel;
    vector<int> orgLevelToNewLevel;
    orgLevelToNewLevel.push_back(0); // level 0 in both org and new are the same
    int prevOrgLevel = 0;
    int gateCount = 0;
    for (size_t i = 0; i < cir_->nGates(); ++i) {
        Gate* g = cir_->getGate(i);
        int currOrgLevel = g->getLvl();
        if (currOrgLevel != prevOrgLevel) {
            nGatesInOrgLevel.push_back(gateCount);
            int prevNewLevel = orgLevelToNewLevel[orgLevelToNewLevel.size() - 1];
            int nAddedLevels = gateCount / nThreads_;
            if (gateCount % nThreads_ != 0)
                nAddedLevels++;
            orgLevelToNewLevel.push_back(prevNewLevel + nAddedLevels);

            // find next new level
            gateCount = 0;
            prevOrgLevel = currOrgLevel;
        }
        gateCount++;
    }
    nLevels_ = 1;

    // map original ID to new ID
    int levelStartOrgId = 0;
    prevOrgLevel = 0;
    for (size_t i = 0; i < cir_->nGates(); ++i) {
        Gate* g = cir_->getGate(i);
        int currOrgLevel = g->getLvl();
        if (currOrgLevel != prevOrgLevel) {
            levelStartOrgId = g->getId();
            prevOrgLevel = currOrgLevel;
        }
        int newLevel = orgLevelToNewLevel[currOrgLevel];
        int newId = (g->getId() - levelStartOrgId) + newLevel * nThreads_;
        cpuIdToGpuId_.push_back(newId);
    }
    int lastNewId = cpuIdToGpuId_[cpuIdToGpuId_.size() - 1];
    int nTotalNewLevels = lastNewId / nThreads_;
    if (nTotalNewLevels % nThreads_ != 0)
        nTotalNewLevels++;
    cpuNLevels_ = new int[nLevels_];
    *cpuNLevels_ = nTotalNewLevels;
    cout<<"nTotalNewLevels:"<<nTotalNewLevels<<endl;
    size_t nGatesPerFrame = *cpuNLevels_ * nThreads_;
    size_t nTotalGates = nGatesPerFrame * cir_->nFrames();

    // transform gate type vector. Types are the same as those in gate.h
    nGateTypes_ = nTotalGates;
    cpuGateType_ = new int[nGateTypes_];
    for (size_t i = 0; i < nGateTypes_; ++i)
        cpuGateType_[i] = -1; // initialize to -1 to indicate NA gates
    for (size_t i = 0; i < cir_->nFrames(); ++i) {
        for (size_t j = 0; j < cir_->nGates(); ++j) {
            Gate *g = cir_->getGate(j);
            int newId = cpuIdToGpuId_[j];
            cpuGateType_[i * nGatesPerFrame + newId] = g->getType();
        }
    }

    // use weighted split vector if timing-aware mode is on.
    nGateSplits_ = nTotalGates;
    cpuGateSplit_ = new int[nGateSplits_];
    if (!taMode_) { // all gates use split vector pool 0 (zero:one = 1:1)
        for (size_t i = 0; i < nGateSplits_; ++i)
            cpuGateSplit_[i] = 0;
    }

    else { // choose split vector pool based on arrival time
        for (size_t i = 0; i < cir_->nFrames(); ++i) {
            for (size_t j = 0; j < cir_->nGates(); ++j) {
                Gate* g = cir_->getGate(j);
                int spVecPool = 0; // default
                // PI, PPI, PO, and PPO do not need weighted split
                if (g->getType() == Gate::PI || g->getType() == Gate::PPI
                    || g->getType() == Gate::PO || g->getType() == Gate::PPO
                    || g->getType() == Gate::INV || g->getType() == Gate::BUF)
                    ;
                else {
                    float atRatio = g->getFi(0)->getArrivalTime() / g->getFi(1)->getArrivalTime();
                    if (atRatio < 0.6) // fanin 0 shorter >40%
                        spVecPool = 2; // n0:n1 = 7:1
                    else if (atRatio < 0.85) // 15% < fanin 0 shorter < 40%
                        spVecPool = 1; // n0:n1 = 3:1
                    else if (atRatio > 1.4) // fanin 0 longer > 40%
                        spVecPool = 4; // n0:n1 = 1:7
                    else if (atRatio > 1.15) // 15% < fanin 0 longer < 40%
                        spVecPool = 3; // n0:n1 = 1:3
                }
                int newId = cpuIdToGpuId_[j];
                cpuGateSplit_[i * nGatesPerFrame + newId] = spVecPool;
            }
        }
    }

    // transform gate fanin vector
    nFanins_ = nTotalGates * 4; // maximum 4 fanins
    cpuFanin_ = new int[nFanins_];
    map<int,int> FFmapping;
    for (size_t i = 0; i < nFanins_; ++i)
        cpuFanin_[i] = -1; // initialized to -1 to indicate not connected
    for (size_t i = 0; i < cir_->nFrames(); ++i) {
        for (size_t j = 0; j < cir_->nGates(); ++j) {
            Gate* g = cir_->getGate(j);
            for (size_t k = 0; k < g->nFis(); ++k) {
                if(i==0 && g->getType()==2){//when FF in time frame 1
                    FFmapping[g->getFi(0)->getId()] = g->getId();// add to FFmapping, process when fransform gate fanout
                    continue;//no need to add fanin value
                }
                int newId = cpuIdToGpuId_[j];
                size_t index = i * nThreads_ * (*cpuNLevels_) * 4 + newId * 4 + k;
                size_t fiId = cpuIdToGpuId_[g->getFi(k)->getId()] + i * nGatesPerFrame;
                if(g->getType() == 2) fiId = cpuIdToGpuId_[g->getFi(k)->getId()] + 0 * nGatesPerFrame;
                cpuFanin_[index] = fiId;
            }
        }
    }

    // transform gate fanout vector
    /*nFanouts_ = nTotalGates * 8; // maximum 8 fanouts
    cpuFanout_ = new int[nFanouts_];
    for (size_t i = 0; i < nFanouts_; ++i)
        cpuFanout_[i] = -1; // initialized to -1 to indicate not connected
    map<int,int>::iterator it=FFmapping.begin();
    for(;it!=FFmapping.end();it++){
        int newId = cpuIdToGpuId_[it->first];
        size_t index = 0 * nThreads_ * (*cpuNLevels_) * 8 + newId * 8 + 0;
        size_t FoNewId = 1 * nThreads_ * (*cpuNLevels_) + cpuIdToGpuId_[it->second];
        cpuFanout_[index] = FoNewId;
    }
    for (size_t i = 0; i < cir_->nFrames(); ++i) {
        for (size_t j = 0; j < cir_->nGates(); ++j) {
            Gate* g = cir_->getGate(j);
            for (size_t k = 0; k < g->nFos(); ++k) {
                int newId = cpuIdToGpuId_[j];
                size_t index = i * nThreads_ * (*cpuNLevels_) * 8 + newId * 8 + k;// index = i * nGatesPerFrame + newId * 8 + k
                size_t foId = cpuIdToGpuId_[g->getFo(k)->getId()] + i * nGatesPerFrame;
                cpuFanout_[index] = foId;
            }
        }
    }*/

    // number of values denpends total number of gates and number of blocks.
    // Each gate has 8 values
    nValues_ = nTotalGates * nBlocks_ * 8;


    // littleshamoo
    cpuNInputs_ = new int;
    *cpuNInputs_ = cir_->nPis() + cir_->nSeqs();
}

vector<ParaValue> MemoryAllocator::genSpVec(float ratio) {
    int       count   = 0;
    size_t    zeroNum = 0;
    size_t    oneNum  = 0;
    ParaValue mask    = 0;
    ParaValue sp      = 0;
    vector<ParaValue> spVec;

    float percentage = ratio / (ratio + 1.0);
    size_t reqZeroNum = (size_t)(32.0 * percentage);
    for (size_t i = 0; i < 1000; ++i) {
        zeroNum = 0;
        oneNum  = 0;
        mask    = 1;
        sp      = 0;
        count   = 0;

        while(count < 32 - reqZeroNum){
            int nBit = rand()%32;
            if( (sp>>nBit) & 0x01 == 1)continue;
            else{
                sp |= 0x01<<nBit;
                count++;
            }
        }

        spVec.push_back(sp & 0xFFFFFFFF);
    }
    return spVec;
}
