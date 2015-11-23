// **************************************************************************
// File       [ sdf_builder.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/11 created ]
// **************************************************************************

#ifndef __SDF_BUILDER_H__
#define __SDF_BUILDER_H__

#include "interface/src/sdf_file.h"
#include "circuit.h"

namespace CoreNs {

class SdfBuilder : public SdfFile {
public:
    enum Cond { BC = 0, AC, WC };

            SdfBuilder(Circuit *cir, const Cond &cond);
    virtual ~SdfBuilder();

    virtual bool addCell(const char * const type, const char * const name);
    virtual bool addIoDelay(const SdfDelayType &type
        , const SdfPortSpec &spec
        , const char * const port
        , const SdfDelayValueList &v);

protected:
    char *cname_;
    Circuit *cir_;
    Cond cond_;
};

inline SdfBuilder::SdfBuilder(Circuit *cir, const Cond &cond)
    : cname_(NULL)
    , cir_(cir)
    , cond_(cond) {}

inline SdfBuilder::~SdfBuilder() {}


};

#endif


