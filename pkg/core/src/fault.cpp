// **************************************************************************
// File       [ fault.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/10/05 created ]
// **************************************************************************

#include "fault.h"
#include <iostream>
#include <stdlib.h>
#include <time.h>

using namespace std;
using namespace IntfNs;
using namespace CoreNs;

void FaultColl::extract(Circuit *cir) {
    // clear faults
    for (size_t i = 0; i < faults_.size(); ++i)
        delete faults_[i];
    faults_.clear();
    delete [] gateToFault_;

    if (type_ == SAF) {
        gateToFault_ = new int[cir->nGates()];
        for (size_t i = 0; i < cir->nGates(); ++i) {
            gateToFault_[i] = faults_.size();
            Gate *g = cir->getGate(i);
            if (g->nFos() > 0) {
                faults_.push_back(new Fault(g, Fault::SA0, 0));
                faults_.push_back(new Fault(g, Fault::SA1, 0));
            }
            for (size_t j = 0; j < g->nFis(); ++j) {
                faults_.push_back(new Fault(g, Fault::SA0, j + 1));
                faults_.push_back(new Fault(g, Fault::SA1, j + 1));
            }
        }
    }
    else {
        gateToFault_ = new int[cir->nGates()];
        for (size_t i = 0; i < cir->nGates(); ++i) {
            gateToFault_[i] = faults_.size();
            Gate *g = cir->getGate(i);
            if (g->getType() == 2 || g->getType() == 3)continue;
            if (g->nFos() > 0) {
                faults_.push_back(new Fault(g, Fault::STR, 0));
                faults_.push_back(new Fault(g, Fault::STF, 0));
            }
            for (size_t j = 0; j < g->nFis(); ++j) {
                faults_.push_back(new Fault(g, Fault::STR, j + 1));
                faults_.push_back(new Fault(g, Fault::STF, j + 1));
            }
        }
    }

    for (size_t i = 0; i < faults_.size(); ++i)
        current_.push_back(faults_[i]);

    //reorder fault list by random (front, back)
    /*for (size_t i = 0; i < faults_.size(); i=i+2) {
        current_.push_back(faults_[i]);
        if ((i+1) < faults_.size())
            current_.push_front(faults_[i+1]); 
    }*/
        

    //reorder fault list by random
    /**srand(time(NULL));
    FaultList tmp;
    for (size_t i = 0; i < faults_.size(); ++i)
        tmp.push_back(faults_[i]);
    for (size_t i = 0; i < faults_.size(); ++i) {
        size_t n;
        n = rand() % tmp.size();
        FaultListIter it;
        for (size_t j = 0; j < n; j++) {
            it = tmp.begin();
            ++it;
        }
        current_.push_back(*it);
        tmp.erase(it);
    }*/

    //random reorder
/*    vector<Fault *> tmp;
    for (size_t i = 0; i < faults_.size(); ++i)
        tmp.push_back(faults_[i]);

    srand(time(NULL));
    for (size_t i = 0; i < faults_.size(); ++i) { 
        size_t n;
        n = rand() % tmp.size();
        current_.push_back(tmp[n]);
        tmp.erase(tmp.begin()+n);
    }*/    
}

