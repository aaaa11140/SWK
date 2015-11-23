#include <iostream>
#include "simulator.h"

using namespace std;
using namespace CoreNs;

//{{{ simulate(pCol, rmnFault, count)
void Simulator::simulate(PatternColl *pCol, FaultList& rmnFault, size_t count)
{
    // only simulate number of count patterns
    size_t i = 0;
    if (count < pCol->nPatterns())
        i = pCol->nPatterns() - count;

    for ( ; i < pCol->nPatterns(); i += WORD_SIZE) {

        if (rmnFault.empty())
            break;

        reset();

        // pack patterns into parallel value
        //   determine start pattern and end pattern
        int patStart = i;
        int patEnd = i + WORD_SIZE;
        if (i + WORD_SIZE > pCol->nPatterns())
            patEnd = pCol->nPatterns();

        //  set parallel pattern value
        LogicHandler logicHdler;
        int patBitIdx = 0;
        for ( ; patStart < patEnd; ++patStart) {
            Pattern* pat = pCol->getPattern(patStart);
            //  set value to each bit of PI in each frame
            for (size_t i = 0; i < cir_->nFrames(); ++i) {
                for (size_t j = 3; j < pat->nPis(); ++j) {
                    ParaValue gl = cir_->getPi(j - 3)->getGl(i);
                    ParaValue gh = cir_->getPi(j - 3)->getGh(i);
                    ParaValue fl = cir_->getPi(j - 3)->getFl(i);
                    ParaValue fh = cir_->getPi(j - 3)->getFh(i);
                    if (pat->getPi(j, i) == L) {
                        logicHdler.setBit(gl, patBitIdx, H);
                        logicHdler.setBit(fl, patBitIdx, H);
                    }
                    else {  // either low or high, no X after random fill
                        logicHdler.setBit(gh, patBitIdx, H);
                        logicHdler.setBit(fh, patBitIdx, H);
                    }
                    cir_->getPi(j)->setGl(gl, i);
                    cir_->getPi(j)->setGh(gh, i);
                    cir_->getPi(j)->setFl(fl, i);
                    cir_->getPi(j)->setFh(fh, i);
                }
            }

            // set value to each bit of PPI in the first frame
            for (size_t j = 0; j < pat->nScans(); ++j) {
                ParaValue gl = cir_->getPpi(j)->getGl(0);
                ParaValue gh = cir_->getPpi(j)->getGh(0);
                ParaValue fl = cir_->getPpi(j)->getFl(0);
                ParaValue fh = cir_->getPpi(j)->getFh(0);
                if (pat->getPpi(j) == L) {
                    logicHdler.setBit(gl, patBitIdx, H);
                    logicHdler.setBit(fl, patBitIdx, H);
                }
                else if (pat->getPpi(j) == H) {
                    logicHdler.setBit(gh, patBitIdx, H);
                    logicHdler.setBit(fh, patBitIdx, H);
                }
                cir_->getPpi(j)->setGl(gl, 0);
                cir_->getPpi(j)->setGh(gh, 0);
                cir_->getPpi(j)->setFl(fl, 0);
                cir_->getPpi(j)->setFh(fh, 0);
            }

            // move on to next bit
            ++patBitIdx;
        }

        // parallel pattern event driven fault simulation
        simulate(rmnFault);
    }
}
//}}}
//{{{ simulate(rmnFault)
void Simulator::simulate(FaultList& rmnFault)
{
    evalGood();
    clearEventList();
    FaultListIter iter = rmnFault.begin();
    while (iter != rmnFault.end()) {
        Fault* fault = *iter;
        if (fault->getState() == Fault::DT || fault->getState() == Fault::RE) {
            iter = rmnFault.erase(iter);
            continue;
        }

        // check activation
        ParaValue activated = getActivated(fault);
        if (PARA_L == activated) {
            ++iter;
            continue;
        }

        // fault injection
        inject(fault);
        recoverList_.push_back(fault->getGate());

        // put fanout into event list
        for (size_t i = 0; i < fault->getGate()->nFos(); ++i) {
            Gate* fo = fault->getGate()->getFo(i);
            eventList_[fo->getLvl()].push(fo);
            processed_[fo->getId()] = true;
        }
        evalEvent(fault);

        // check output for detection
        ParaValue outputDiff = PARA_L;
        for (size_t i = 0; i < cir_->nPos(); ++i) {
            Gate* po = cir_->getPo(i);
            ParaValue flDiff = po->getFl(1) & po->getGh(1);
            ParaValue fhDiff = po->getFh(1) & po->getGl(1);
            outputDiff |= flDiff | fhDiff;
        }
        for (size_t i = 0; i < cir_->nSeqs(); ++i) {
            Gate* ppo = cir_->getPpo(i);
            ParaValue flDiff = ppo->getFl(1) & ppo->getGh(1);
            ParaValue fhDiff = ppo->getFh(1) & ppo->getGl(1);
            outputDiff |= flDiff | fhDiff;
        }
        ParaValue detected = outputDiff & activated;

        // checking for n-detection
        LogicHandler logicHdler;
        for (size_t i = 0; i < WORD_SIZE; ++i) {
            if (logicHdler.getBit(detected, i) != H)
                continue;
            fault->setDet(fault->getDet() + 1);
            if (fault->getDet() >= detectNum_) {
                fault->setState(Fault::DT);
                break;
            }
        }

        if (fault->getState() == Fault::DT)
            iter = rmnFault.erase(iter);
        else
            iter++;

        recover();
    }
}
//}}}

//{{{ isActivated()
ParaValue Simulator::getActivated(Fault* f)
{
    Gate *gate = f->getGate();
    if (f->getLine() > 0) // fault on gate input
        gate = gate->getFi(f->getLine() - 1);

    if (f->getType() == Fault::STR) {
        return (gate->getGl(0) & gate->getGh(1));
    }
    else {
        return (gate->getGh(0) & gate->getGl(1));
    }
}
//}}}
//{{{ inject()
void Simulator::inject(Fault* f)
{
    Gate *gate = f->getGate();
    if (f->getLine() > 0)  // fault on gate input
        gate = gate->getFi(f->getLine() - 1);

    if (f->getType() == Fault::STR) {  // faulty low on second frame
        gate->setFl(PARA_H, 1);
        gate->setFh(PARA_L, 1);
    }
    else {  // faulty high on second frame
        gate->setFl(PARA_L, 1);
        gate->setFh(PARA_H, 1);
    }

    // fault on input line needs its value recovered
    if (f->getLine() > 0) {
        f->getGate()->evalF(1);
        gate->setFl(gate->getGl(1), 1);
        gate->setFh(gate->getGh(1), 1);
    }
}
//}}}
//{{{ evalGood()
void Simulator::evalGood()
{
    for (size_t i = 0; i < cir_->nFrames(); ++i) {
        for (size_t j = 0; j < cir_->nGates(); ++j) {
            cir_->getGate(j)->evalG(i);
            cir_->getGate(j)->setFl(cir_->getGate(j)->getGl(i), i);
            cir_->getGate(j)->setFh(cir_->getGate(j)->getGh(i), i);
        }
        // simulate launch-on-capture
        if (i + 1 != cir_->nFrames()) {
            for (size_t j = 0; j < cir_->nSeqs(); ++j) {
                cir_->getPpi(j)->setGl(cir_->getPpo(j)->getGl(i), i + 1);
                cir_->getPpi(j)->setGh(cir_->getPpo(j)->getGh(i), i + 1);
                cir_->getPpi(j)->setFl(cir_->getPpo(j)->getFl(i), i + 1);
                cir_->getPpi(j)->setFh(cir_->getPpo(j)->getFh(i), i + 1);
            }
        }
    }
}
//}}}
//{{{ reset()
void Simulator::reset()
{
    for (size_t i = 0; i < cir_->nFrames(); ++i) {
        for (size_t j = 0; j < cir_->nGates(); ++j) {
            cir_->getGate(j)->setGl(PARA_L, i);
            cir_->getGate(j)->setGh(PARA_L, i);
            cir_->getGate(j)->setFl(PARA_L, i);
            cir_->getGate(j)->setFh(PARA_L, i);
            processed_[j] = false;
        }
    }
}
//}}}
//{{{ clearEventList()
void Simulator::clearEventList()
{
    for (int i = 0; i < eventLevel_; ++i)
        while (!eventList_[i].empty())
            eventList_[i].pop();
}
//}}}
//{{{ evalEvent()
void Simulator::evalEvent(Fault* f) {
    ParaValue activated = getActivated(f);
    for (int i = f->getGate()->getLvl(); i < eventLevel_; ++i) {
        while (false == eventList_[i].empty()) {
            // take first gate out from event queue
            Gate* gate = eventList_[i].front();
            eventList_[i].pop();

            // faulty evalutaion on second frame
            gate->evalF(1);
            recoverList_.push_back(gate);

            // only activated bits with value different than good
            // propogate the event
            ParaValue lDiff = gate->getFl(1) ^ gate->getGl(1);
            ParaValue hDiff = gate->getFh(1) ^ gate->getGh(1);
            ParaValue vDiff = lDiff | hDiff;
            if ((vDiff & activated) == PARA_L)
                continue;

            // put not processed fanouts into the event list
            for (size_t j = 0; j < gate->nFos(); ++j) {
                Gate* fo = gate->getFo(j);
                if (processed_[fo->getId()] == true)
                    continue;
                eventList_[fo->getLvl()].push(fo);
                processed_[fo->getId()] = true;
            }
        }
    }
}
//}}}
//{{{ recover()
void Simulator::recover() {
    for (size_t i = 0; i < recoverList_.size(); ++i) {
        Gate* g = recoverList_[i];
        g->setFl(g->getGl(1), 1);
        g->setFh(g->getGh(1), 1);
        processed_[i] = false;
    }
    recoverList_.clear();
}
//}}}

