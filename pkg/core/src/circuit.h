// **************************************************************************
// File       [ circuit.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2010/12/29 created ]
// **************************************************************************

#ifndef __CORE_CIRCUIT_H__
#define __CORE_CIRCUIT_H__

#include <map>

#include "gate.h"

namespace CoreNs {

class Circuit {
public:
    Circuit();
    ~Circuit() {};


    // gate layout
    // **********************************************************************
    //  npi_  nseq_  ncomb_  npo_  nseq_
    // +----+-------+--------+----+-------+-----------------+
    // | PI | DFF Q |  comb  | PO | DFF D | frame 1 gates   |...
    // +----+-------+--------+----+-------+-----------------+
    //  \__________ frame 0 _____________/ \___ frame 1 ___/
    //
    // **********************************************************************
    size_t nPis() const;              // number of PIs
    size_t nPos() const;              // number of POs
    size_t nSeqs() const;             // number of sequential elements
    size_t nCombs() const;            // number of combinational gates
    size_t nGates() const;            // total number of gates
    size_t nFrames() const;           // number of frames
    int    getLvl() const;            // circuit level
    void   setLvl(const int &lvl);
    void   setFrame(const size_t &nframe);

    Gate *getPi(const size_t &i);     // ith PI
    Gate *getPo(const size_t &i);     // ith PO
    Gate *getPpi(const size_t &i);    // ith PPI
    Gate *getPpo(const size_t &i);    // ith PPO
    Gate *getComb(const size_t &i);   // ith combinational gate
    Gate *getGate(const size_t &i);   // ith gate
    GateVec *getGates();              // get all gates


    void addPi(Gate * const g);
    void addPo(Gate * const g);
    void addPpi(Gate * const g);
    void addPpo(Gate * const g);
    void addComb(Gate * const g);
    Gate *getGate(IntfNs::Occ * const occ) const;
    void setOccToGate(IntfNs::Occ * const occ, Gate * const g);
    IntfNs::Module *getModRoot() const;
    void setModRoot(IntfNs::Module * const module);
    IntfNs::Occ *getOccRoot() const;
    void setOccRoot(IntfNs::Occ * const occ);

protected:
    size_t npi_;
    size_t npo_;
    size_t nseq_;
    size_t ncomb_;
    size_t ngate_;
    size_t nframe_;
    int lvl_;
    GateVec gates_;
    IntfNs::Module *module_;
    IntfNs::Occ *occ_;
    std::map<IntfNs::Occ *, Gate *> occToGate_;
};

inline Circuit::Circuit()
    : npi_(0)
    , npo_(0)
    , nseq_(0)
    , ncomb_(0)
    , ngate_(0)
    , nframe_(1)
    , lvl_(-1)
    , module_(NULL)
    , occ_(NULL) {}

inline size_t Circuit::nPis() const {
    return npi_;
}

inline size_t Circuit::nPos() const {
    return npo_;
}

inline size_t Circuit::nSeqs() const {
    return nseq_;
}

inline size_t Circuit::nCombs() const {
    return ncomb_;
}

inline size_t Circuit::nGates() const {
    return ngate_;
}

inline size_t Circuit::nFrames() const {
    return nframe_;
}

inline int Circuit::getLvl() const {
    return lvl_;
}

inline void Circuit::setLvl(const int &lvl) {
    lvl_ = lvl;
}

inline void Circuit::setFrame(const size_t &nframe) {
    nframe_ = nframe;
}

inline Gate *Circuit::getPi(const size_t &i) {
    return gates_[i];
}

inline Gate *Circuit::getPo(const size_t &i) {
    return gates_[ngate_ - nseq_ - npo_ + i];
}

inline Gate *Circuit::getPpi(const size_t &i) {
    return gates_[npi_ + i];
}

inline Gate *Circuit::getPpo(const size_t &i) {
    return gates_[ngate_ - nseq_ + i];
}

inline Gate *Circuit::getComb(const size_t &i) {
    return gates_[npi_ + nseq_ + i];
}

inline Gate *Circuit::getGate(const size_t &i) {
    return gates_[i];
}

inline GateVec *Circuit::getGates() {
    return &gates_;
}

inline void Circuit::addPi(Gate * const g) {
    gates_.push_back(g);
    npi_++;
    ngate_++;
}

inline void Circuit::addPo(Gate * const g) {
    gates_.push_back(g);
    npo_++;
    ngate_++;
}

inline void Circuit::addPpi(Gate * const g) {
    gates_.push_back(g);
    nseq_++;
    ngate_++;
}

inline void Circuit::addPpo(Gate * const g) {
    gates_.push_back(g);
    ngate_++;
}

inline void Circuit::addComb(Gate * const g) {
    gates_.push_back(g);
    ncomb_++;
    ngate_++;
}

inline Gate *Circuit::getGate(IntfNs::Occ * const occ) const {
    std::map<IntfNs::Occ *, Gate *>::const_iterator it = occToGate_.find(occ);
    return it == occToGate_.end() ? NULL : it->second;
}

inline void Circuit::setOccToGate(IntfNs::Occ * const occ, Gate * const g) {
    occToGate_[occ] = g;
}

inline IntfNs::Module *Circuit::getModRoot() const {
    return module_;
}

inline void Circuit::setModRoot(IntfNs::Module * const module) {
    module_ = module;
}

inline IntfNs::Occ *Circuit::getOccRoot() const {
    return occ_;
}

inline void Circuit::setOccRoot(IntfNs::Occ * const occ) {
    occ_ = occ;
}


};

#endif

