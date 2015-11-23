// **************************************************************************
// File       [ sdf_builder.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/11 created ]
// **************************************************************************

#include "sdf_builder.h"

using namespace std;
using namespace IntfNs;
using namespace CoreNs;

bool SdfBuilder::addCell(const char * const type
    , const char * const name)
{
    delete [] cname_;
    cname_ = strdup(name);
    return true;
}

bool SdfBuilder::addIoDelay(const SdfDelayType &type
    , const SdfPortSpec &spec
    , const char * const port
    , const SdfDelayValueList &v)
{
    Occ *occ = cir_->getOccRoot()->getChild(cname_);
    Gate *g = cir_->getGate(occ);
    ModInst *modInst = occ->getModInst();
    
    size_t idx = 0;
    if (g->getType() == Gate::PPI && strcmp(port, "Q") == 0) {
        g->setDelay(idx, Gate::RISE, v.v[Gate::RISE].v[0].v[cond_]);
        g->setDelay(idx, Gate::FALL, v.v[Gate::FALL].v[0].v[cond_]);
        return true;
    }
    for (size_t i = 0; i < modInst->nModInstTerms(); ++i, ++idx)
        if (strcmp(spec.port, modInst->getModInstTerm(i)->getName()) == 0)
            break;
    g->setDelay(idx, Gate::RISE, v.v[Gate::RISE].v[0].v[cond_]);
    g->setDelay(idx, Gate::FALL, v.v[Gate::FALL].v[0].v[cond_]);
    return true;
}

