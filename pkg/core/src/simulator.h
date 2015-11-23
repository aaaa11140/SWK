#ifndef __CORE_SIMULATOR_H__
#define __CORE_SIMULATOR_H__

#include "circuit.h"
#include "pattern.h"
#include "fault.h"

namespace CoreNs {

class Simulator {

public:
    Simulator(Circuit* cir) : cir_(cir) {
        redundantNum_ = 0;
        detectNum_ = 1;
        eventLevel_ = cir_->getLvl();
        for (size_t i = 0; i < cir_->nGates(); ++i)
            processed_.push_back(false);
        eventList_  = new GateQueue[eventLevel_];
    }
    ~Simulator() {
        delete [] eventList_;
    }

    void setDetectNum(int n);
    void simulate(PatternColl *pCol, FaultList& rmnFault, size_t count);
    void simulate(FaultList& rmnFault);

    ParaValue getActivated(Fault* f);
    void inject(Fault* f);
    void evalGood();
    void reset();
    void clearEventList();
    void evalEvent(Fault* f);
    void recover();

private:
    Circuit*          cir_;
    int               detectNum_;
    int               eventLevel_;
    GateQueue*        eventList_;
    GateVec           recoverList_;
    std::vector<bool> processed_;
    int               redundantNum_;
};

inline void Simulator::setDetectNum(int n)
{
    detectNum_ = n;
}

};

#endif

