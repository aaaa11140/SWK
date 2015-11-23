// **************************************************************************
// File       [ circuit_builder.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/11 created ]
// **************************************************************************

#ifndef __CORE_CIRCUIT_BUILDER_H__
#define __CORE_CIRCUIT_BUILDER_H__

#include "interface/src/design.h"

#include "circuit.h"

namespace CoreNs {

class CircuitBuilder {
public:
    CircuitBuilder();
    ~CircuitBuilder() {};

    void build(IntfNs::Design * const design, const size_t &f);

    Circuit *getCircuit() const;

protected:
    Gate *createGate(IntfNs::Occ *occ);
    void levelize();
    void setTimeFrame(const size_t &f);

    Circuit *cir_;
};

inline CircuitBuilder::CircuitBuilder() : cir_(NULL) {}

inline Circuit *CircuitBuilder::getCircuit() const {
    return cir_;
}

inline bool cmpGateLvl(const Gate * const i, const Gate * const j) {
    return i->getLvl() < j->getLvl();
}

};

#endif


