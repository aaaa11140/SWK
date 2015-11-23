// **************************************************************************
// File       [ timing_analyzer.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/11/01 ]
// **************************************************************************

#ifndef __CORE_TIMING_ANALYZER_H__
#define __CORE_TIMING_ANALYZER_H__

#include "circuit.h"

namespace CoreNs {

class TimingAnalyzer {
public:
    TimingAnalyzer(Circuit* cir) : cir_{cir} {};
    ~TimingAnalyzer() {};

    void calculateArrivalTime();

private:
    Circuit* cir_;
};

};

#endif


