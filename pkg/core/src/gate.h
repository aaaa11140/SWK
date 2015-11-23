// **************************************************************************
// File       [ gate.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/07/05 created ]
// **************************************************************************

#ifndef __CORE_GATE_H__
#define __CORE_GATE_H__

#include <iostream>
#include <vector>
#include <queue>


#include "interface/src/occ.h"

#include "logic.h"

namespace CoreNs {

class Gate;

typedef std::vector<Gate *> GateVec;
typedef std::queue<Gate *>  GateQueue;

class Gate {
public:
            Gate();
    virtual ~Gate();

    enum Type { NA = -1,
                PI,      PO,
                PPI,     PPO,
                INV,     BUF,
                AND,     NAND,
                OR,      NOR,
                XOR,     XNOR,
                MUX,
                TIE0,    TIE1,  TIEX, TIEZ,
              };

    enum Trans { RISE = 0, FALL };

    virtual void setId(const size_t &i);
    virtual size_t getId() const;

    virtual void setOcc(IntfNs::Occ * const occ);
    virtual IntfNs::Occ *getOcc() const;

    virtual void setLvl(const int &lvl);
    virtual int getLvl() const;

    virtual void setType(const Type &type);
    virtual Type getType() const;
    virtual const char *getTypeStr() const;

    virtual void addFi(Gate * const g);
    virtual size_t nFis() const;
    virtual Gate *getFi(const size_t &i);

    virtual void addFo(Gate * const g);
    virtual size_t nFos() const;
    virtual Gate *getFo(const size_t &i);

    virtual size_t nFrames() const;
    virtual void setFrame(const size_t &f);
    virtual void setV(const Value &v, const size_t &f);
    virtual Value getV(const size_t &f) const;
    virtual void setFv(const Value &v, const size_t &f);
    virtual Value getFv(const size_t &f) const;

    virtual void setDelay(const size_t &in, const Trans &trans, const float &delay);
    virtual float getDelay(const size_t &in, const Trans &trans);

    virtual void  setArrivalTime(const float& time);
    virtual float getArrivalTime();

    // virtual void  setPropagationTime(const size_t &out, const float& time);
    // virtual float getPropagationTime(const size_t &out);

    virtual void eval(const size_t &f) = 0;
    virtual void fEval(const size_t &f) = 0;

    // for parallel simulator
    void setGl(ParaValue v, size_t f);
    void setGh(ParaValue v, size_t f);
    void setFl(ParaValue v, size_t f);
    void setFh(ParaValue v, size_t f);
    ParaValue getGl(size_t f) const;
    ParaValue getGh(size_t f) const;
    ParaValue getFl(size_t f) const;
    ParaValue getFh(size_t f) const;
    virtual void evalG(size_t f) = 0;
    virtual void evalF(size_t f) = 0;

protected:
    size_t                 id_;             // position in gate array
    IntfNs::Occ            *occ_;           // occurance in the design
    int                    lvl_;            // level number in the circuit
    Type                   type_;           // type of the gate
    GateVec                fis_;            // fanins
    GateVec                fos_;            // fanouts
    std::vector<Value>     v_;              // gate values
    std::vector<Value>     fv_;             // gate faulty values
    std::vector<float>     delay_[2];       // delay values
    float                  at_;             // arrival time at the gate output
    //std::vector<float>     pt_;             // propagation time of different fanouts
    std::vector<ParaValue> gl_;  // parallel value good low
    std::vector<ParaValue> gh_;  // parallel value good high
    std::vector<ParaValue> fl_;  // parallel value faulty low
    std::vector<ParaValue> fh_;  // parallel value faulty high
};

//{{{ Gate
inline Gate::Gate()
    : id_(0)
    , occ_(NULL)
    , lvl_(-1)
    , type_(NA) {}

inline Gate::~Gate() {}

inline void Gate::setId(const size_t &i) {
    id_ = i;
}

inline size_t Gate::getId() const {
    return id_;
}

inline void Gate::setOcc(IntfNs::Occ * const occ) {
    occ_ = occ;
}

inline IntfNs::Occ *Gate::getOcc() const {
    return occ_;
}


inline void Gate::setLvl(const int &lvl) {
    lvl_ = lvl;
}

inline int Gate::getLvl() const {
    return lvl_;
}

inline void Gate::setType(const Type &type) {
    type_ = type;
}

inline Gate::Type Gate::getType() const {
    return type_;
}

inline const char *Gate::getTypeStr() const {
    return "UNKNOWN";
}


inline void Gate::addFi(Gate * const g) {
    fis_.push_back(g);
    delay_[0].push_back(0.0);
    delay_[1].push_back(0.0);
}

inline size_t Gate::nFis() const {
    return fis_.size();
}

inline Gate *Gate::getFi(const size_t &i) {
    return fis_[i];
}


inline void Gate::addFo(Gate * const g) {
    fos_.push_back(g);
}

inline size_t Gate::nFos() const {
    return fos_.size();
}

inline Gate *Gate::getFo(const size_t &i) {
    return fos_[i];
}

inline size_t Gate::nFrames() const {
    return v_.size();
}

inline void Gate::setFrame(const size_t &f) {
    v_.resize(f, X);
    fv_.resize(f, X);
    gl_.resize(f, PARA_L);
    gh_.resize(f, PARA_L);
    fl_.resize(f, PARA_L);
    fh_.resize(f, PARA_L);
}

inline void Gate::setV(const Value &v, const size_t &f) {
    v_[f] = v;
}

inline Value Gate::getV(const size_t &f) const {
    return v_[f];
}

inline void Gate::setFv(const Value &v, const size_t &f) {
    fv_[f] = v;
}

inline Value Gate::getFv(const size_t &f) const {
    return fv_[f];
}

inline void Gate::setDelay(const size_t &in
    , const Trans &trans
    , const float &delay)
{
    delay_[trans][in] = delay;
}

inline float Gate::getDelay(const size_t &in, const Trans &trans) {
    return delay_[trans][in];
}

inline void Gate::setArrivalTime(const float& time) {
    at_ = time;
}

inline float Gate::getArrivalTime() {
    return at_;
}

inline void Gate::setGl(ParaValue v, size_t f)
{
    gl_[f] = v;
}

inline void Gate::setGh(ParaValue v, size_t f)
{
    gh_[f] = v;
}

inline void Gate::setFl(ParaValue v, size_t f)
{
    fl_[f] = v;
}

inline void Gate::setFh(ParaValue v, size_t f)
{
    fh_[f] = v;
}

inline ParaValue Gate::getGl(size_t f) const
{
    return gl_[f];
}

inline ParaValue Gate::getGh(size_t f) const
{
    return gh_[f];
}

inline ParaValue Gate::getFl(size_t f) const
{
    return fl_[f];
}

inline ParaValue Gate::getFh(size_t f) const
{
    return fh_[f];
}
//}}}

//{{{ PiGate
class PiGate : public Gate {
public:
    PiGate() {
        type_ = Gate::PI;
        delay_[0].push_back(0.0);
        delay_[1].push_back(0.0);
    };
    ~PiGate() {};

    void eval(const size_t &f) {};
    void fEval(const size_t &f) {};
    const char *getTypeStr() const {
        return "PI";
    }

    void evalG(size_t f) {};
    void evalF(size_t f) {};
};
//}}}
//{{{ PoGate
class PoGate : public Gate {
public:
    PoGate() { type_ = Gate::PO; };
    ~PoGate() {};

    void eval(const size_t &f) {
        const Value table[] = { L, H, X };
        v_[f] = table[fis_[0]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[] = { L, H, X };
        fv_[f] = table[fis_[0]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "PO";
    }

    void evalG(size_t f) {
        gl_[f] = fis_[0]->getGl(f);
        gh_[f] = fis_[0]->getGh(f);
    }
    void evalF(size_t f) {
        fl_[f] = fis_[0]->getFl(f);
        fh_[f] = fis_[0]->getFh(f);
    }
};
//}}}
//{{{ PpiGate
class PpiGate : public Gate {
public:
    PpiGate() {
        type_ = Gate::PPI;
        delay_[0].push_back(0.0);
        delay_[1].push_back(0.0);
    };
    ~PpiGate() {};

    void eval(const size_t &f) {};
    void fEval(const size_t &f) {};
    const char *getTypeStr() const {
        return "PPI";
    }

    void evalG(size_t f) {};
    void evalF(size_t f) {};
};
//}}}
//{{{ PpoGate
class PpoGate : public Gate {
public:
    PpoGate() { type_ = Gate::PPO; };
    ~PpoGate() {};

    void eval(const size_t &f) {
        const Value table[] = { L, H, X };
        v_[f] = table[fis_[0]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[] = { L, H, X };
        fv_[f] = table[fis_[0]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "PPO";
    }

    void evalG(size_t f) {
        gl_[f] = fis_[0]->getGl(f);
        gh_[f] = fis_[0]->getGh(f);
    }
    void evalF(size_t f) {
        fl_[f] = fis_[0]->getFl(f);
        fh_[f] = fis_[0]->getFh(f);
    }
};
//}}}
//{{{ InvGate
class InvGate : public Gate {
public:
    InvGate() { type_ = Gate::INV; };
    ~InvGate() {};

    void eval(const size_t &f) {
        const Value table[] = { H, L, X };
        v_[f] = table[fis_[0]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[] = { H, L, X };
        fv_[f] = table[fis_[0]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "INV";
    }

    void evalG(size_t f) {
        gl_[f] = fis_[0]->getGh(f);
        gh_[f] = fis_[0]->getGl(f);
    }
    void evalF(size_t f) {
        fl_[f] = fis_[0]->getFh(f);
        fh_[f] = fis_[0]->getFl(f);
    }
};
//}}}
//{{{ BufGate
class BufGate : public Gate {
public:
    BufGate() { type_ = Gate::BUF; };
    ~BufGate() {};

    void eval(const size_t &f) {
        const Value table[] = { L, H, X };
        v_[f] = table[fis_[0]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[] = { L, H, X };
        fv_[f] = table[fis_[0]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "BUF";
    }

    void evalG(size_t f) {
        gl_[f] = fis_[0]->getGl(f);
        gh_[f] = fis_[0]->getGh(f);
    }
    void evalF(size_t f) {
        fl_[f] = fis_[0]->getFl(f);
        fh_[f] = fis_[0]->getFh(f);
    }
};
//}}}
//{{{ AndGate
class AndGate : public Gate {
public:
    AndGate() { type_ = Gate::AND; };
    ~AndGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, L, L },
            { L, H, X },
            { L, X, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, L, L },
            { L, H, X },
            { L, X, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "AND";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            gl |= fis_[i]->getGl(f);
            gh &= fis_[i]->getGh(f);
        }
        gl_[f] = gl;
        gh_[f] = gh;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            fl |= fis_[i]->getFl(f);
            fh &= fis_[i]->getFh(f);
        }
        fl_[f] = fl;
        fh_[f] = fh;
    }
};
//}}}
//{{{ NandGate
class NandGate : public Gate {
public:
    NandGate() { type_ = Gate::NAND; };
    ~NandGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, L, L },
            { L, H, X },
            { L, X, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
        const Value inv[] = { H, L, X };
        v_[f] = inv[v_[f]];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, L, L },
            { L, H, X },
            { L, X, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
        const Value inv[] = { H, L, X };
        fv_[f] = inv[fv_[f]];
    };
    const char *getTypeStr() const {
        return "NAND";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            gl |= fis_[i]->getGl(f);
            gh &= fis_[i]->getGh(f);
        }
        gl_[f] = gh;
        gh_[f] = gl;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            fl |= fis_[i]->getFl(f);
            fh &= fis_[i]->getFh(f);
        }
        fl_[f] = fh;
        fh_[f] = fl;
    }
};
//}}}
//{{{ OrGate
class OrGate : public Gate {
public:
    OrGate() { type_ = Gate::OR; };
    ~OrGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, H, H },
            { X, H, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, H, H },
            { X, H, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "OR";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            gl &= fis_[i]->getGl(f);
            gh |= fis_[i]->getGh(f);
        }
        gl_[f] = gl;
        gh_[f] = gh;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            fl &= fis_[i]->getFl(f);
            fh |= fis_[i]->getFh(f);
        }
        fl_[f] = fl;
        fh_[f] = fh;
    }
};
//}}}
//{{{ NorGate
class NorGate : public Gate {
public:
    NorGate() { type_ = Gate::NOR; };
    ~NorGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, H, H },
            { X, H, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
        const Value inv[] = { H, L, X };
        v_[f] = inv[v_[f]];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, H, H },
            { X, H, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
        const Value inv[] = { H, L, X };
        fv_[f] = inv[fv_[f]];
    };
    const char *getTypeStr() const {
        return "NOR";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            gl &= fis_[i]->getGl(f);
            gh |= fis_[i]->getGh(f);
        }
        gl_[f] = gh;
        gh_[f] = gl;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            fl &= fis_[i]->getFl(f);
            fh |= fis_[i]->getFh(f);
        }
        fl_[f] = fh;
        fh_[f] = fl;
    }
};
//}}}
//{{{ XorGate
class XorGate : public Gate {
public:
    XorGate() { type_ = Gate::XOR; };
    ~XorGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, L, X },
            { X, X, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, L, X },
            { X, X, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
    };
    const char *getTypeStr() const {
        return "XOR";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            ParaValue tmpGl = (fis_[i]->getGl(f) & gl) | (fis_[i]->getGh(f) & gh);
            ParaValue tmpGh = (fis_[i]->getGl(f) & gh) | (fis_[i]->getGh(f) & gl);
            gl = tmpGl;
            gh = tmpGh;
        }
        gl_[f] = gl;
        gh_[f] = gh;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            ParaValue tmpFl = (fis_[i]->getFl(f) & fl) | (fis_[i]->getFh(f) & fh);
            ParaValue tmpFh = (fis_[i]->getFl(f) & fh) | (fis_[i]->getFh(f) & fl);
            fl = tmpFl;
            fh = tmpFh;
        }
        fl_[f] = fl;
        fh_[f] = fh;
    }
};
//}}}
//{{{ XnorGate
class XnorGate : public Gate {
public:
    XnorGate() { type_ = Gate::XNOR; };
    ~XnorGate() {};

    void eval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, L, X },
            { X, X, X }
        };
        v_[f] = fis_[0]->getV(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            v_[f] = table[v_[f]][fis_[i]->getV(f)];
        const Value inv[] = { H, L, X };
        v_[f] = inv[v_[f]];
    };
    void fEval(const size_t &f) {
        const Value table[3][3] = {
            { L, H, X },
            { H, L, X },
            { X, X, X }
        };
        fv_[f] = fis_[0]->getFv(f);
        for (size_t i = 1; i < fis_.size(); ++i)
            fv_[f] = table[fv_[f]][fis_[i]->getFv(f)];
        const Value inv[] = { H, L, X };
        fv_[f] = inv[fv_[f]];
    };
    const char *getTypeStr() const {
        return "XNOR";
    }

    void evalG(size_t f) {
        ParaValue gl = fis_[0]->getGl(f);
        ParaValue gh = fis_[0]->getGh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            ParaValue tmpGl = (fis_[i]->getGl(f) & gl) | (fis_[i]->getGh(f) & gh);
            ParaValue tmpGh = (fis_[i]->getGl(f) & gh) | (fis_[i]->getGh(f) & gl);
            gl = tmpGl;
            gh = tmpGh;
        }
        gl_[f] = gh;
        gh_[f] = gl;
    }
    void evalF(size_t f) {
        ParaValue fl = fis_[0]->getFl(f);
        ParaValue fh = fis_[0]->getFh(f);
        for (size_t i = 1; i < fis_.size(); ++i) {
            ParaValue tmpFl = (fis_[i]->getFl(f) & fl) | (fis_[i]->getFh(f) & fh);
            ParaValue tmpFh = (fis_[i]->getFl(f) & fh) | (fis_[i]->getFh(f) & fl);
            fl = tmpFl;
            fh = tmpFh;
        }
        fl_[f] = fh;
        fh_[f] = fl;
    }
};
//}}}

};


#endif

