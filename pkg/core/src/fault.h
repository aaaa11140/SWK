// **************************************************************************
// File       [ fault.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/10/04 created ]
// **************************************************************************

#ifndef __CORE_FAULT_H__
#define __CORE_FAULT_H__

#include <list>

#include "circuit.h"

namespace CoreNs {

class Fault;
typedef std::vector<Fault *>         FaultVec;
typedef std::list<Fault *>           FaultList;
typedef std::list<Fault *>::iterator FaultListIter;

class Fault {
public:
    // ************************************
    // * fault types
    // *     SA0    stuck-at zero
    // *     SA1    stuck-at one
    // *     STR    slow to rise
    // *     STF    slow to fall
    // *
    // * fault states
    // *     UD     undetected
    // *     DT     detected
    // *     PT     possibly testable
    // *     AU     ATPG untestable
    // *     TI     tied
    // *     RE     redundant
    // *     AB     aborted
    // ************************************
    enum  Type { SA0 = 0, SA1, STR, STF };
    enum  State { UD = 0, DT, PT, AU, TI, RE, AB };

    Fault();
    Fault(Gate *gate, Type type, int line);
    ~Fault();

    Gate *getGate() const;
    Type getType() const;
    int getLine() const;
    void setDet(const int &det);
    int getDet() const;
    void setState(const State &state);
    State getState() const;

protected:
    Gate* gate_;  // faulty gate
    Type  type_;  // fault type
    int   line_;  // faulty line: 0 means output fault. 1+ means input fault
                  //              on the corresponding input line
    int   det_;   // number of detection
    State state_; // fault state
};

class FaultColl {
public:
    enum Type { SAF = 0, TDF };

    FaultColl();
    ~FaultColl();

    void extract(Circuit *cir);
    int getFault(const int &i) const;
    FaultVec *getFaults();
    FaultList *getCurrent();
    Type getType() const;
    void setType(const Type &type);

protected:
    int       *gateToFault_;
    FaultVec  faults_;
    FaultList current_;
    Type      type_;
};

inline Fault::Fault() {
    gate_  = NULL;
    type_  = SA0;
    line_  = -1;
    det_   = 0;
    state_ = UD;
}

inline Fault::Fault(Gate *gate, Type type, int line) {
    gate_  = gate;
    type_  = type;
    line_  = line;
    det_   = 0;
    state_ = UD;
}

inline Fault::~Fault() {}

inline Gate *Fault::getGate() const {
    return gate_;
}

inline Fault::Type Fault::getType() const {
    return type_;
}

inline int Fault::getLine() const {
    return line_;
}

inline void Fault::setDet(const int &det) {
    det_ = det;
}

inline int Fault::getDet() const {
    return det_;
}

inline void Fault::setState(const State &state) {
    state_ = state;
}

inline Fault::State Fault::getState() const {
    return state_;
}


inline FaultColl::FaultColl() {
    gateToFault_ = NULL;
    type_        = SAF;
}

inline FaultColl::~FaultColl() {
    delete [] gateToFault_;
}

inline int FaultColl::getFault(const int &i) const {
    return gateToFault_[i];
}

inline FaultVec *FaultColl::getFaults() {
    return &faults_;
}

inline FaultList *FaultColl::getCurrent() {
    return &current_;
}

inline FaultColl::Type FaultColl::getType() const {
    return type_;
}

inline void FaultColl::setType(const FaultColl::Type &type) {
    type_ = type;
}

};

#endif


