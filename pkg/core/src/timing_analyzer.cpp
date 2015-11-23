// **************************************************************************
// File       [ timing_analyzer.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/11/01 ]
// **************************************************************************

#include "timing_analyzer.h"

using namespace std;
using namespace CoreNs;

void TimingAnalyzer::calculateArrivalTime()
{
    for (size_t i = 0; i < cir_->nGates(); ++i) {
        Gate* g = cir_->getGate(i);
        float maxFiAt = 0.0;
        for (size_t j = 0; j < g->nFis(); ++j) {
            Gate *fi = g->getFi(j);
            float fiAt = g->getDelay(j, Gate::RISE);
            if (fiAt < g->getDelay(j, Gate::FALL))
                fiAt = g->getDelay(j, Gate::FALL);
            fiAt += fi->getArrivalTime();
            if (fiAt > maxFiAt)
                maxFiAt = fiAt;
        }
        g->setArrivalTime(maxFiAt);
    }
}

