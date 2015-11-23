// **************************************************************************
// File       [ gate.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/07/05 created ]
// **************************************************************************

#ifndef __CORE_GATE_H__
#define __CORE_GATE_H__

#include <vector>
#include <string>

#include "logic.h"

namespace CoreNs {

//{{{ class Gate
class Gate {
public:
            Gate(const string &name) : name_{name}
                , id_{0}
                , lvl_{-1}
                , type_{Gate::PI}
                , gl_{ParaL}
                , gh_{ParaL}
                , fl_{ParaL}
                , fh_{ParaL}
                , ol_{ParaL}
                , oh_{ParaL}
                , pp_{ParaL} {}

    virtual ~Gate();

    enum Type {
        PI,   PO,  PPI, PPO,
        BUF,  INV, AND, NAND,
        OR,   NOR
    };

    string name_; // name from the netlist
    size_t id_;   // index in the gate vector
    int    lvl_;  // logic level in the circuit
    Type   type_; // gate type

    // values
    ParaV  gl_;   // parallel value good low
    ParaV  gh_;   // parallel value good high
    ParaV  fl_;   // parallel value faulty low
    ParaV  fh_;   // parallel value faulty high
    ParaV  ol_;   // parallel value objective low
    ParaV  oh_;   // parallel value objective high
    ParaV  pp_;   // parallel value propagation

    // circuit structures
    void   addFanin(Gate* g);
    size_t nFanins() const                     { return fanins_.size();  };
    Gate*  getFanin(size_t i) const            { return fanins_[i];      };
    void   addFanout(Gate* g)                  { fanouts_.push_back(g);  };
    size_t nFanouts() const                    { return fanouts_.size(); };
    Gate*  getFanout(size_t i) const           { return fanouts_[i];     };

    // delay from standard delay file
    float  getRiseDalay(size_t i) const        { return riseDelay_[i];   };
    void   setRiseDelay(size_t i, float delay) { riseDelay_[i] = delay;  };
    float  getFallDelay(size_t i) const        { return fallDelay_[i];   };
    void   setFallDelay(size_t i, float delay) { fallDelay_[i] = delay;  };

    // logic operations
    virtual void gEvaluate() = 0; // evaluate parallel good value
    virtual void fEvaluate() = 0; // evaluate parallel faulty value
    virtual void propagate() = 0;
    virtual void backtrace(ParaV split, ParaV& objFlag) = 0;

    // clear backtrace related values for next backtrace
    virtual void clearBacktraceValues() { ol_ = ParaL; oh_ = ParaL; };

    // determine fanout stem objectives using SWK backtrace fanout operations
    virtual void determineStemObjectives(ParaV split, ParaV& objFlag);

private:
    vector<Gate*> fanins_;    // fanin gates
    vector<Gate*> fanouts_;   // fanout gates
    vector<float> delayRise_; // rising delay from inputs to output
    vector<float> delayFall_; // falling delay from inputs to output
};

inline Gate::determineStemObjectives(ParaV split, ParaV& objFlag) {
    ParaV tmpOl = ol_;
    ParaV tmpOh = oh_;
    ol_ = (tmpOl & ~tmpOh) | (tmpOl & tmpOh & split)
    oh_ = (tmpOh & ~tmpOl) | (tmpOl & tmpOh & ~split)
}
//}}}

class PiGate : public Gate {
public:
    PiGate(const string& name) : Gate(name), type_{Gate::PI} {};
    ~PiGate() {};

    void gEvaluate() {};
    void fEvaluate() {};
    void propagate() {};
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
    };
};

class PoGate : public Gate {
public:
    PoGate(const string& name) : Gate(name), type_{Gate::PO} {};
    ~PoGate() {};

    void gEvaluate() { gl_ = fanins_[0]->gl_; gh_ = fanins_[0]->gh_; };
    void fEvaluate() { fl_ = fanins_[0]->fl_; fh_ = fanins_[0]->fh_; };
    void propagate() {
        gEvaluate();
        fEvaluate();
        pp_ = fanins_[0]->pp_;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        fanins_[0]->ol_ |= ol_;
        fanins_[0]->oh_ |= oh_;
        fanins_[0]->pp_ |= pp_;
    };
};

class PpiGate : public Gate {
public:
    PpiGate(const string& name) : Gate(name), type_{Gate::PPI} {};
    ~PpiGate() {};

    void gEvaluate() {};
    void fEvaluate() {};
    void propagate() {};
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
    };
};

class PpoGate : public Gate {
public:
    PpoGate(const string& name) : Gate(name), type_{Gate::PPO} {};
    ~PpoGate() {};

    void gEvaluate() { gl_ = fanins_[0]->gl_; gh_ = fanins_[0]->gh_; };
    void fEvaluate() { fl_ = fanins_[0]->fl_; fh_ = fanins_[0]->fh_; };
    void propagate() {
        gEvaluate();
        fEvaluate();
        pp_ = fanins_[0]->pp_;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        fanins_[0]->ol_ |= ol_;
        fanins_[0]->oh_ |= oh_;
        fanins_[0]->pp_ |= pp_;
    };
};

class BufGate : public Gate {
public:
    BufGate(const string& name) : Gate(name), type_{Gate::BUF} {};
    ~BufGate() {};

    void gEvaluate() { gl_ = fanins_[0]->gl_; gh_ = fanins_[0]->gh_; };
    void fEvaluate() { fl_ = fanins_[0]->fl_; fh_ = fanins_[0]->fh_; };
    void propagate() {
        gEvaluate();
        fEvaluate();
        pp_ = fanins_[0]->pp_;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        fanins_[0]->ol_ |= ol_;
        fanins_[0]->oh_ |= oh_;
        fanins_[0]->pp_ |= pp_;
    };
};

class InvGate : public Gate {
public:
    InvGate(const string& name) : Gate(name), type_{Gate::INV} {};
    ~InvGate() {};

    void gEvaluate() { gl_ = fanins_[0]->gl_; gh_ = fanins_[0]->gh_; };
    void fEvaluate() { fl_ = fanins_[0]->fl_; fh_ = fanins_[0]->fh_; };
    void propagate() {
        gEvaluate();
        fEvaluate();
        pp_ = fanins_[0]->pp_;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        fanins_[0]->ol_ |= ol_;
        fanins_[0]->oh_ |= oh_;
        fanins_[0]->pp_ |= pp_;
    };
};


class AndGate : public Gate {
public:
    AndGate(const string& name) : Gate(name), type_{Gate::AND} {};
    ~AndGate() {};

    void gEvaluate() {
        gl_ = fanins_[0]->gl_ | fanins_[1]->gl_;
        gh_ = fanins_[0]->gh_ & fanins_[1]->gh_;
    };
    void fEvaluate() {
        fl_ = fanins_[0]->fl_ | fanins_[1]->fl_;
        fh_ = fanins_[0]->fh_ & fanins_[1]->fh_;
    };
    void propagate() {
        gEvaluate();
        fEvaluate();
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);
        ParaV cx = ~(fl_ | fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-generation
        pp_ = ax & bd | bx & ad;
        // p-propagation
        pp_ |= ~a->fl_ & b->pp_ & cx | a->pp_ & ~b->fl_ & cx;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-implication
        ParaV ap = a->pp_ & (b->fh_ | ~b->pp_) & pp_ & ~objFlag;
        ParaV bp = b->pp_ & (a->fh_ | ~a->pp_) & pp_ & ~objFlag;

        // p-split
        ap |= a->pp_ & b->pp_ & pp_ & ~objFlag & split;
        bp |= a->pp_ & b->pp_ & pp_ & ~objFlag & ~split;

        // o-backtrace
        ParaV aol = ax & ~b->pp_ & ol_ | a->pp_ & b->pp_ & ol_ & split;
        ParaV bol = bx & ~a->pp_ & ol_ | b->pp_ & a->pp_ & ol_ & ~split;
        ParaV aoh = ax & bd & pp_ & ~objFlag | ax & ~b->fl_ & oh_;
        ParaV boh = bx & ad & pp_ & ~objFlag | bx & ~a->fl_ & oh_;

        // update OBJ flag
        objFlag |= aol | aoh | bol | boh;

        // update objectives and propagation values of fanins
        fanins_[0].ol_ |= aol;
        fanins_[0].oh_ |= aoh;
        fanins_[0].pp_ |= ap;
        fanins_[1].ol_ |= bol;
        fanins_[1].oh_ |= boh;
        fanins_[1].pp_ |= bp;
    };
};


class NandGate : public Gate {
public:
    NandGate(const string& name) : Gate(name), type_{Gate::NAND} {};
    ~NandGate() {};

    void gEvaluate() {
        gl_ = fanins_[0]->gh_ & fanins_[1]->gh_;
        gh_ = fanins_[0]->gl_ | fanins_[1]->gl_;
    };
    void fEvaluate() {
        fl_ = fanins_[0]->fh_ & fanins_[1]->fh_;
        fh_ = fanins_[0]->fl_ | fanins_[1]->fl_;
    };
    void propagate() {
        gEvaluate();
        fEvaluate();
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);
        ParaV cx = ~(fl_ | fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-generation
        pp_ = ax & bd | bx & ad;
        // p-propagation
        pp_ |= ~a->fl_ & b->pp_ & cx | a->pp_ & ~b->fl_ & cx;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-implication
        ParaV ap = a->pp_ & (b->fh_ | ~b->pp_) & pp_ & ~objFlag;
        ParaV bp = b->pp_ & (a->fh_ | ~a->pp_) & pp_ & ~objFlag;

        // p-split
        ap |= a->pp_ & b->pp_ & pp_ & ~objFlag & split;
        bp |= a->pp_ & b->pp_ & pp_ & ~objFlag & ~split;

        // o-backtrace
        ParaV aol = ax & ~b->pp_ & ol_ | a->pp_ & b->pp_ & oh_ & split;
        ParaV bol = bx & ~a->pp_ & ol_ | b->pp_ & a->pp_ & oh_ & ~split;
        ParaV aoh = ax & bd & pp_ & ~objFlag | ax & ~b->fl_ & ol_;
        ParaV boh = bx & ad & pp_ & ~objFlag | bx & ~a->fl_ & ol_;

        // update OBJ flag
        objFlag |= aol | aoh | bol | boh;

        // update objectives and propagation values of fanins
        fanins_[0].ol_ |= aol;
        fanins_[0].oh_ |= aoh;
        fanins_[0].pp_ |= ap;
        fanins_[1].ol_ |= bol;
        fanins_[1].oh_ |= boh;
        fanins_[1].pp_ |= bp;
    };
};


class OrGate : public Gate {
public:
    OrGate(const string& name) : Gate(name), type_{Gate::OR} {};
    ~OrGate() {};

    void gEvaluate() {
        gl_ = fanins_[0]->gl_ & fanins_[1]->gl_;
        gh_ = fanins_[0]->gh_ | fanins_[1]->gh_;
    };
    void fEvaluate() {
        fl_ = fanins_[0]->fl_ & fanins_[1]->fl_;
        fh_ = fanins_[0]->fh_ | fanins_[1]->fh_;
    };
    void propagate() {
        gEvaluate();
        fEvaluate();
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);
        ParaV cx = ~(fl_ | fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-generation
        pp_ = ax & bd | bx & ad;
        // p-propagation
        pp_ |= ~a->fh_ & b->pp_ & cx | a->pp_ & ~b->fh_ & cx;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-implication
        ParaV ap = a->pp_ & (b->fl_ | ~b->pp_) & pp_ & ~objFlag;
        ParaV bp = b->pp_ & (a->fl_ | ~a->pp_) & pp_ & ~objFlag;

        // p-split
        ap |= a->pp_ & b->pp_ & pp_ & ~objFlag & split;
        bp |= a->pp_ & b->pp_ & pp_ & ~objFlag & ~split;

        // o-backtrace
        ParaV aol = ax & bd & pp_ & ~objFlag | ax & ~b->fh_ & ol_;
        ParaV bol = bx & ad & pp_ & ~objFlag | bx & ~a->fh_ & ol_;
        ParaV aoh = ax & ~b->pp_ & oh_ | a->pp_ & b->pp_ & oh_ & split;
        ParaV boh = bx & ~a->pp_ & oh_ | b->pp_ & a->pp_ & oh_ & ~split;

        // update OBJ flag
        objFlag |= aol | aoh | bol | boh;

        // update objectives and propagation values of fanins
        fanins_[0].ol_ |= aol;
        fanins_[0].oh_ |= aoh;
        fanins_[0].pp_ |= ap;
        fanins_[1].ol_ |= bol;
        fanins_[1].oh_ |= boh;
        fanins_[1].pp_ |= bp;
    };
};


class NorGate : public Gate {
public:
    NorGate(const string& name) : Gate(name), type_{Gate::NOR} {};
    ~NorGate() {};

    void gEvaluate() {
        gl_ = fanins_[0]->gh_ | fanins_[1]->gh_;
        gh_ = fanins_[0]->gl_ & fanins_[1]->gl_;
    };
    void fEvaluate() {
        fl_ = fanins_[0]->fh_ | fanins_[1]->fh_;
        fh_ = fanins_[0]->fl_ & fanins_[1]->fl_;
    };
    void propagate() {
        gEvaluate();
        fEvaluate();
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);
        ParaV cx = ~(fl_ | fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-generation
        pp_ = ax & bd | bx & ad;
        // p-propagation
        pp_ |= ~a->fh_ & b->pp_ & cx | a->pp_ & ~b->fh_ & cx;
        clearBacktrace();
    };
    void backtrace(ParaV split, ParaV& objFlag) {
        determineStemObjectives(split, objFlag);
        Gate *a = fanins_[0];
        Gate *b = fanins_[1];

        // calculate unknown
        ParaV ax = ~(a->fl_ | a->fh_);
        ParaV bx = ~(b->fl_ | b->fh_);

        // calculate faulty effect D or D-bar
        ParaV ad = a->fl_ & a->gh_ | a->fh_ & a->gl_;
        ParaV bd = b->fl_ & b->gh_ | b->fh_ & b->gl_;

        // p-implication
        ParaV ap = a->pp_ & (b->fl_ | ~b->pp_) & pp_ & ~objFlag;
        ParaV bp = b->pp_ & (a->fl_ | ~a->pp_) & pp_ & ~objFlag;

        // p-split
        ap |= a->pp_ & b->pp_ & pp_ & ~objFlag & split;
        bp |= a->pp_ & b->pp_ & pp_ & ~objFlag & ~split;

        // o-backtrace
        ParaV aol = ax & ~b->pp_ & oh_ | a->pp_ & b->pp_ & oh_ & split;
        ParaV bol = bx & ~a->pp_ & oh_ | b->pp_ & a->pp_ & oh_ & ~split;
        ParaV aoh = ax & bd & pp_ & ~objFlag | ax & ~b->fh_ & ol_;
        ParaV boh = bx & ad & pp_ & ~objFlag | bx & ~a->fh_ & ol_;

        // update OBJ flag
        objFlag |= aol | aoh | bol | boh;

        // update objectives and propagation values of fanins
        fanins_[0].ol_ |= aol;
        fanins_[0].oh_ |= aoh;
        fanins_[0].pp_ |= ap;
        fanins_[1].ol_ |= bol;
        fanins_[1].oh_ |= boh;
        fanins_[1].pp_ |= bp;
    };
};

};


#endif

