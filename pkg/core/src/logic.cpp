// **************************************************************************
// File       [ logic.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/07/05 created ]
// **************************************************************************

#include "logic.h"

using namespace std;
using namespace CoreNs;

void LogicPrinter::print(const Value &v, FILE *out) {
    switch (v) {
        case L:
            fprintf(out, "0");
            break;
        case H:
            fprintf(out, "1");
            break;
        case X:
            fprintf(out, "X");
            break;
        case D:
            fprintf(out, "D");
            break;
        case B:
            fprintf(out, "B");
            break;
        case Z:
            fprintf(out, "Z");
            break;
        default:
            fprintf(out, "I");
    }
}


void LogicPrinter::print(const ParaValue &v, FILE *out) {
    for (size_t i = 0; i < WORD_SIZE; ++i) {
        size_t j = WORD_SIZE - i - 1;
        ParaValue mask = 0x01;
        mask <<= j;
        if ((v & mask) != PARA_L)
            fprintf(out, "1");
        else
            fprintf(out, "0");
    }
}

void LogicPrinter::print(const ParaValue &l, const ParaValue &h, FILE *out) {
    for (size_t i = 0; i < WORD_SIZE; ++i) {
        size_t j = WORD_SIZE - i - 1;
        ParaValue mask = 0x01;
        mask <<= j;
        if ((l & mask) != PARA_L)
            fprintf(out, "0");
        else if ((h & mask) != PARA_L)
            fprintf(out, "1");
        else
            fprintf(out, "X");
    }
}

