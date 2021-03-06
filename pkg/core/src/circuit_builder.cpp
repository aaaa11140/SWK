// **************************************************************************
// File       [ circuit_builder.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/11 created ]
// **************************************************************************

#include <queue>
#include <string>
#include <algorithm>
#include <map>
#include "circuit_builder.h"

using namespace std;
using namespace IntfNs;
using namespace CoreNs;

void CircuitBuilder::build(Design * const design, const size_t &f) {
    delete cir_;
    cir_ = new Circuit;
    cir_->setFrame(f);
    cir_->setOccRoot(design->getOcc());
    cir_->setModRoot(design->getTop());
    map<string,Gate*> FFMap;    // flip-flop map, used to connecte PPI & PPO
    // create PI
    // ignore CK, test_si, and test_so
    for (size_t i = 0; i < design->getTop()->nModTerms(); ++i) {
        ModTerm *term = design->getTop()->getModTerm(i);
        if (term->getType() != ModTerm::INPUT 
            || strcmp(term->getName(),"test_si") == 0 
            || strcmp(term->getName(),"test_se") == 0
            || strcmp(term->getName(),"CK") == 0 )
            continue;
        Gate *g = new PiGate;
        g->setOcc(design->getOcc());
        cir_->addPi(g);
    }

    // create PPI
    for (size_t i = 0; i < design->getOcc()->nChildren(); ++i) {
        Occ *occ = design->getOcc()->getChild(i);
        string modName(occ->getModInst()->getModName());
        if (modName.size() < 4 || modName.substr(0,4) != "SDFF")
            continue;
        Gate *g = new PpiGate;
        g->setOcc(occ);
        cir_->addPpi(g);
        cir_->setOccToGate(occ, g);
        FFMap[occ->getModInst()->getName()] = g;
    }

    // create combinational gates
    for (size_t i = 0; i < design->getOcc()->nChildren(); ++i) {
        Occ *occ = design->getOcc()->getChild(i);
        string modName(occ->getModInst()->getModName());
        if (modName.size() > 3 && modName.substr(0,4) == "SDFF")
            continue;
        Gate *g = createGate(occ);
        g->setOcc(occ);
        cir_->addComb(g);
        cir_->setOccToGate(occ, g);
    }

    // create PO
    for (size_t i = 0; i < design->getTop()->nModTerms(); ++i) {
        ModTerm *term = design->getTop()->getModTerm(i);
        if (term->getType() != ModTerm::OUTPUT)
            continue;
        Gate *g = new PoGate;
        g->setOcc(design->getOcc());
        cir_->addPo(g);
    }

    // create PPO
    for (size_t i = 0; i < design->getOcc()->nChildren(); ++i) {
        Occ *occ = design->getOcc()->getChild(i);
        string modName(occ->getModInst()->getModName());
        if (modName.size() < 4 || modName.substr(0,4) != "SDFF")
            continue;
        Gate *g = new PpoGate;
        g->setOcc(occ);
        cir_->addPpo(g);
        FFMap[occ->getModInst()->getName()]->addFi(g);
    }

    // connect gates
    for (size_t i = cir_->nPis() + cir_->nSeqs(); i < cir_->nGates(); ++i) {
        Gate *g = cir_->getGate(i);
        Occ *occ = g->getOcc();
        size_t nTerm = 0;
        if (g->getType() == Gate::PO || g->getType() == Gate::PPO)
            nTerm = 1;
        else
            nTerm = occ->getModInst()->nModInstTerms() - 1;
        for (size_t j = 0; j < nTerm; ++j) {
            ModTerm *term = NULL;
            ModInstTerm *instTerm = NULL;
            ModNet *net = NULL;
            if (g->getType() == Gate::PO) {
                // because we ignore 3 inputs(CK,test_si,test_so)
                // we have to add 3 in idx to match id in ModTerm
                size_t id = i - cir_->nCombs() - cir_->nSeqs() + 3;
                term = design->getTop()->getModTerm(id);
                net = term->getModNet();
            }
            else if (g->getType() == Gate::PPO) {
                instTerm = occ->getModInst()->getModInstTerm("D");
                net = instTerm->getModNet();
            }
            else {
                instTerm = occ->getModInst()->getModInstTerm(j);
                net = instTerm->getModNet();
            }

            // find fanin
            Gate *fi = NULL;
            for (size_t k = 0; k < net->nModTerms(); ++k) {
                if (net->getModTerm(k) == term
                    || net->getModTerm(k)->getType() == ModTerm::OUTPUT)
                    continue;
                // because we ignore 3 inputs(CK,test_si,test_so)
                // we have to minus 3 in idx to match id in ModTerm
                size_t id = net->getModTerm(k)->getPos()-3;
                fi = cir_->getGate(id);
                break;
            }
            if (!fi) {
                for (size_t k = 0; k < net->nModInstTerms(); ++k) {
                    ModInst *inst = net->getModInstTerm(k)->getModInst();
                    if (net->getModInstTerm(k) == instTerm
                        || inst->getModule()->getModTerm(net->getModInstTerm(k)->getName())->getType() == ModTerm::INPUT)
                        continue;
                    const char *name = net->getModInstTerm(k)->getModInst()->getName();
                    fi = cir_->getGate(design->getOcc()->getChild(name));
                    break;
                }
            }
            // connect gates
            g->addFi(fi);
            fi->addFo(g);
        }
    }


    levelize();
    setTimeFrame(f);

}

Gate *CircuitBuilder::createGate(Occ *occ) {
    Gate *g = NULL;
    ModInst *inst = occ->getChild((size_t)0)->getModInst();
    switch (((Pmt *)inst->getModule())->getType()) {
        case Pmt::AND:
            g = new AndGate;
            break;
        case Pmt::NAND:
            g = new NandGate;
            break;
        case Pmt::OR:
            g = new OrGate;
            break;
        case Pmt::NOR:
            g = new NorGate;
            break;
        case Pmt::INV:
            g = new InvGate;
            break;
        case Pmt::BUF:
            g = new BufGate;
            break;
        case Pmt::XOR:
            g = new XorGate;
            break;
        case Pmt::XNOR:
            g = new XnorGate;
            break;
        default:
            break;
    }
    return g;
}

void CircuitBuilder::levelize() {
    bool processed[cir_->nGates()];
    bool levelized[cir_->nGates()];
    memset(processed, false, sizeof(bool) * cir_->nGates());
    memset(levelized, false, sizeof(bool) * cir_->nGates());
    for (size_t i = 0; i < cir_->nGates(); ++i)
        cir_->getGate(i)->setId(i);

    queue<Gate *> que;
    for (size_t i = 0; i < cir_->nPis() + cir_->nSeqs(); ++i)
        que.push(cir_->getGate(i));

    while (!que.empty()) {
        Gate *g = que.front();
        que.pop();

        int maxlvl = -1;
        bool ready = true;

        // determine level only if all fanins are levelized
        // 1. PPI is set to level zero 
        // 2. PPI has input PPO
        // 3. Skip PPI directly
        if(g->getType() != Gate::PPI){
            for (size_t i = 0; i < g->nFis(); ++i) {
                Gate *fi = g->getFi(i);
                if (!levelized[fi->getId()]) {
                    ready = false;
                    break;
                }
                if (fi->getLvl() > maxlvl)
                    maxlvl = fi->getLvl();
            }
        }
        // put back to queue if not ready
        if (!ready) {
            que.push(g);
            continue;
        }

        // set level
        g->setLvl(maxlvl + 1);
        levelized[g->getId()] = true;

        // determine circuit level
        if ((g->getType() == Gate::PO || g->getType() == Gate::PPO)
            && g->getLvl() > cir_->getLvl())
            cir_->setLvl(g->getLvl());

        // put fanouts into queue
        for (size_t i = 0; i < g->nFos(); ++i) {
            Gate *fo = g->getFo(i);
            if (processed[fo->getId()])
                continue;
            processed[fo->getId()] = true;
            que.push(fo);
        }
    }

    // set all POs to highest level
    for (size_t i = 0; i < cir_->nPos(); ++i)
        cir_->getPo(i)->setLvl(cir_->getLvl());
    for (size_t i = 0; i < cir_->nSeqs(); ++i)
        cir_->getPpo(i)->setLvl(cir_->getLvl());
    cir_->setLvl(cir_->getLvl() + 1);

    // sort gates by their level
    stable_sort(cir_->getGates()->begin()
        , cir_->getGates()->end()
        , cmpGateLvl);

    // set gate id
    for (size_t i = 0; i < cir_->nGates(); ++i)
        cir_->getGate(i)->setId(i);
}

void CircuitBuilder::setTimeFrame(const size_t &f) {
    for (size_t i = 0; i < cir_->nGates(); ++i)
        cir_->getGate(i)->setFrame(f);
}

