// **************************************************************************
// File       [ pattern.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/11 created ]
// **************************************************************************

#ifndef __CORE_PATTERN_H__
#define __CORE_PATTERN_H__

#include "gate.h"
#include <iostream>
using namespace std;
namespace CoreNs {

class Pattern;

typedef std::vector<Pattern *>           PatternVec;
typedef std::vector<std::vector<Value> > PatternValues;

class Pattern {
public:
    Pattern(const size_t &npi
        , const size_t &npo
        , const size_t &nframe
        , const size_t &nscan
    );
    ~Pattern();

    enum  Clk { HOLD = 0, CAPT };

    void setPi(const Value &v, const size_t &idx, const size_t &frame);
    void setPo(const Value &v, const size_t &idx, const size_t &frame);
    void setClk(const Clk &clk, const size_t &frame);
    void setPpi(const Value &v, const size_t &idx);
    void setPpo(const Value &v, const size_t &idx);

    Value getPi(const size_t &idx, const size_t &frame) const;
    Value getPo(const size_t &idx, const size_t &frame) const;
    Clk getClk(const size_t &frame) const;
    Value getPpi(const size_t &idx) const;
    Value getPpo(const size_t &idx) const;
    void  print(ostream &out = cout);

    size_t nFrames() const;
    size_t nPis() const;
    size_t nPos() const;
    size_t nScans() const;

protected:
    std::vector<std::vector<Value> > pi_;
    std::vector<std::vector<Value> > po_;
    std::vector<Clk>                 clk_;
    std::vector<Value>               ppi_;
    std::vector<Value>               ppo_;
};

class PatternColl {
public:
    PatternColl() {};
    PatternColl(PatternColl* pColl);
    ~PatternColl() {};

    size_t nPatterns() const;
    Pattern *getPattern(const size_t &i) const;

    size_t nPis() const;
    Gate *getPi(const size_t &i) const;
    unsigned getPiIdx(string name);
    unsigned getPiIdx(unsigned int id);

    size_t nPos() const;
    Gate *getPo(const size_t &i) const;

    size_t nScans() const;
    Gate *getScan(const size_t &i) const;
    unsigned getScanIdx(string name);
    unsigned getScanIdx(unsigned int id);

    void addPi(Gate * const g);
    void addPo(Gate * const g);
    void addScan(Gate * const g);
    void addPiStr(string str);
    void addPoStr(string str);
    void addScanStr(string str);
    string getPiStr(const size_t &i);
    string getPoStr(const size_t &i);
    string getScanStr(const size_t &i);
    void addPattern(Pattern * const pat);
    
    void print(std::ostream &out = std::cout);

    unsigned int*               cirPiId2PatId_; // circuit pattern Id to pattern pi Id 
    unsigned int*               cirScanId2PatId_; // circuit pattern Id to pattern pi Id 
protected:
    std::vector<Gate *> pis_;
    std::vector<Gate *> pos_;
    std::vector<Gate *> scans_;
    std::vector<string> pisStr_; // piName
    std::vector<string> posStr_; // piName
    std::vector<string> scansStr_; // piName
    std::map<string,unsigned>   piName2Idx_;   // get pi gate idx in pattern from name
    std::map<string,unsigned>   scanName2Idx_;
    PatternVec pats_;
};


//{{{ class Pattern methods
inline Pattern::Pattern(const size_t &npi
    , const size_t &npo
    , const size_t &nframe
    , const size_t &nscan)
{
    pi_.resize(nframe);
    po_.resize(nframe);
    clk_.resize(nframe);
    for (size_t i = 0; i < nframe; ++i) {
        pi_[i].resize(npi);
        po_[i].resize(npo);
    }
    ppi_.resize(nscan);
    ppo_.resize(nscan);
}

inline Pattern::~Pattern() {};

inline void Pattern::setPi(const Value &v
    , const size_t &idx
    , const size_t &frame)
{
    pi_[frame][idx] = v;
}

inline void Pattern::setPo(const Value &v
    , const size_t &idx
    , const size_t &frame)
{
    po_[frame][idx] = v;
}

inline void Pattern::setClk(const Pattern::Clk &clk
    , const size_t &frame)
{
    clk_[frame] = clk;
}

inline void Pattern::setPpi(const Value &v, const size_t &idx) {
    ppi_[idx] = v;
}

inline void Pattern::setPpo(const Value &v, const size_t &idx) {
    ppo_[idx] = v;
}


inline Value Pattern::getPi(const size_t &idx, const size_t &frame) const {
    return pi_[frame][idx];
}

inline Value Pattern::getPo(const size_t &idx, const size_t &frame) const {
    return po_[frame][idx];
}

inline Pattern::Clk Pattern::getClk(const size_t &frame) const {
    return clk_[frame];
}

inline Value Pattern::getPpi(const size_t &idx) const {
    return ppi_[idx];
}

inline Value Pattern::getPpo(const size_t &idx) const {
    return ppo_[idx];
}

inline size_t Pattern::nFrames() const {
    return pi_.size();
}

inline size_t Pattern::nPis() const {
    if (pi_.size() > 0)
        return pi_[0].size();
    return 0;
}

inline size_t Pattern::nPos() const {
    if (po_.size() > 0)
        return po_[0].size();
    return 0;
}

inline size_t Pattern::nScans() const {
    return ppi_.size();
}
inline void  Pattern::print(ostream &out){
    out<<clk_.size()<<" ";
    for(unsigned i = 0 ; i < clk_.size();++i){
        for(unsigned j = 0; j < pi_[i].size(); ++j){
            Value v = pi_[i][j];
            switch (v) {
                case L:
                    out << "0";
                    break;
                case H:
                    out << "1";
                    break;
                case X:
                    out << "X";
                    break;
                case Z:
                    out << "Z";
                    break;
                default:
                    out << "I";
            }
        }
        out<<" ";
        for(unsigned j = 0; j < po_[i].size(); ++j){
            Value v = po_[i][j];
            switch (v) {
                case L:
                    out << "0";
                    break;
                case H:
                    out << "1";
                    break;
                case X:
                    out << "X";
                    break;
                case Z:
                    out << "Z";
                    break;
                default:
                    out << "I";
            }
        }
        if(clk_[i] == HOLD)
            out<<" __HOLD__ ";
        else
            out<<" __CAPT__ ";
    }
    for(unsigned j = 0; j < ppi_.size(); ++j){
        Value v = ppi_[j];
        switch (v) {
            case L:
                out << "0";
                break;
            case H:
                out << "1";
                break;
            case X:
                out << "X";
                break;
            case Z:
                out << "Z";
                break;
            default:
                out << "I";
        }
    }
    out<<" ";
    for(unsigned j = 0; j < ppo_.size(); ++j){
        Value v = ppo_[j];
        switch (v) {
            case L:
                out << "0";
                break;
            case H:
                out << "1";
                break;
            case X:
                out << "X";
                break;
            case Z:
                out << "Z";
                break;
            default:
                out << "I";
        }
    }
}
//}}}
//{{{ class PatternColl methods
inline PatternColl::PatternColl(PatternColl* pColl){
    for(size_t i = 0; i < pColl->nPis();++i){
       addPi(pColl->getPi(i)); 
       pisStr_.push_back(pColl->getPiStr(i));
    }
    for(size_t i = 0; i < pColl->nPos();++i){
       addPo(pColl->getPo(i)); 
       posStr_.push_back(pColl->getPoStr(i));
    }
    for(size_t i = 0; i < pColl->nScans();++i){
       addScan(pColl->getScan(i)); 
       scansStr_.push_back(pColl->getScanStr(i));
    }
    cirPiId2PatId_ = pColl->cirPiId2PatId_; // circuit pattern Id to pattern pi Id 
    cirScanId2PatId_ = pColl->cirScanId2PatId_; // circuit pattern Id to pattern pi Id 
    
}
inline size_t PatternColl::nPatterns() const {
    return pats_.size();
}

inline Pattern *PatternColl::getPattern(const size_t &i) const {
    return pats_[i];
}


inline size_t PatternColl::nPis() const {
    return pis_.size();
}

inline Gate *PatternColl::getPi(const size_t &i) const {
    return pis_[i];
}


inline size_t PatternColl::nPos() const {
    return pos_.size();
}

inline Gate *PatternColl::getPo(const size_t &i) const {
    return pos_[i];
}


inline size_t PatternColl::nScans() const {
    return scans_.size();
}

inline Gate *PatternColl::getScan(const size_t &i) const {
    return scans_[i];
}


inline void PatternColl::addPi(Gate * const g) {
    pis_.push_back(g);
}

inline void PatternColl::addPo(Gate * const g) {
    pos_.push_back(g);
}

inline void PatternColl::addScan(Gate * const g) {
    scans_.push_back(g);
}

inline void PatternColl::addPiStr(string str) {
    piName2Idx_[str] = pisStr_.size(); 
    pisStr_.push_back(str);
}

inline void PatternColl::addPoStr(string str) {
    posStr_.push_back(str);
}

inline void PatternColl::addScanStr(string str) {
    scanName2Idx_[str] = scansStr_.size(); 
    scansStr_.push_back(str);
}
inline unsigned PatternColl::getPiIdx(string name){
    return piName2Idx_[name];
}
inline unsigned PatternColl::getScanIdx(string name){
    return scanName2Idx_[name];
}

inline void PatternColl::addPattern(Pattern * const pat) {
    pats_.push_back(pat);
}
inline string PatternColl::getPiStr(const size_t &i){
    return pisStr_[i];
}
inline string PatternColl::getPoStr(const size_t &i){
    return posStr_[i];
}
inline string PatternColl::getScanStr(const size_t &i){
    return scansStr_[i];
}
inline void PatternColl::print(std::ostream &out){
    out<<"__PI_ORDER__";
    for(unsigned i = 0 ; i < pisStr_.size(); ++i)
        out<<" "<<pisStr_[i];
    out<<endl<<"__PO_ORDER__";
    for(unsigned i = 0 ; i < posStr_.size(); ++i)
        out<<" "<<posStr_[i];
    out<<endl<<"__SCAN_ORDER__";
    for(unsigned i = 0 ; i < scansStr_.size(); ++i)
        out<<" "<<scansStr_[i];
    out<<endl;
    for(unsigned i = 0 ; i < pats_.size(); i++){
        out<<"__PATTERN__"<<" "<<i<<" ";
        pats_[i]->print(out);
        out<<endl;
    }
}
//}}}


};

#endif


