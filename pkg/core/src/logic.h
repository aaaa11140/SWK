// **************************************************************************
// File       [ logic.h ]
// Author     [ littleshamoo ]
// Synopsis   [ Logic representation and operation ]
// Date       [ 2010/12/14 created ]
// **************************************************************************

#ifndef __CORE_LOGIC_H__
#define __CORE_LOGIC_H__

#include <cstdio>

namespace CoreNs {

// type defines
// typedef uint8_t   Value;
// typedef uintptr_t ParaValue;
typedef unsigned char Value;
typedef unsigned long ParaValue;

// constant single logic
const   Value     L         = 0;       // Low
const   Value     H         = 1;       // High
const   Value     X         = 2;       // Unknown
const   Value     D         = 3;       // D (good 1 / faulty 0)
const   Value     B         = 4;       // D-bar (good 0 / faulty 1)
const   Value     Z         = 5;       // High-impedence
const   Value     I         = 255;     // Invalid

// constant multi-bit logic
const   ParaValue PARA_L    = 0;       // all bits are zero
const   ParaValue PARA_H    = ~PARA_L; // all bits are one

// determine word size
const   size_t    BYTE_SIZE = 8;
const   size_t    WORD_SIZE = sizeof(ParaValue) * BYTE_SIZE;


class LogicHandler {
public:
    LogicHandler() {};
    virtual ~LogicHandler() {};

    virtual void setBit(ParaValue &pv, const size_t &i, const Value &v);
    virtual Value getBit(const ParaValue &pv, const size_t &i);

    virtual void setBit(ParaValue &l
        , ParaValue &h
        , const size_t &i
        , const Value &v);
    virtual Value getBit(const ParaValue &l
        , const ParaValue &h
        , const size_t &i);
};

class LogicPrinter {
public:
    LogicPrinter() {};
    virtual ~LogicPrinter() {};

    virtual void print(const Value &v, FILE *out = stdout);
    virtual void print(const ParaValue &v, FILE *out = stdout);
    virtual void print(const ParaValue &l
        , const ParaValue &h
        , FILE *out = stdout);
};

inline void LogicHandler::setBit(ParaValue &pv
    , const size_t &i
    , const Value &v) {
    pv = v == L ? pv & ~((ParaValue)0x01 << i) : pv | ((ParaValue)0x01 << i);
}

inline Value LogicHandler::getBit(const ParaValue &pv, const size_t &i) {
    return (pv & ((ParaValue)0x01 << i)) == PARA_L ? L : H;
}

inline void LogicHandler::setBit(ParaValue &l
    , ParaValue &h
    , const size_t &i
    , const Value &v)
{
    l = v == L ?  l | ((ParaValue)0x01 << i) : l & ~((ParaValue)0x01 << i);
    h = v == H ?  h | ((ParaValue)0x01 << i) : h & ~((ParaValue)0x01 << i);
}

inline Value LogicHandler::getBit(const ParaValue &l
    , const ParaValue &h
    , const size_t &i)
{
    Value vl = getBit(l, i);
    Value vh = getBit(h, i);
    if (vl == L && vh == L)
        return X;
    else if (vl == L && vh == H)
        return H;
    else if (vl == H && vh == L)
        return L;
    else
        return I;
}

};

#endif

