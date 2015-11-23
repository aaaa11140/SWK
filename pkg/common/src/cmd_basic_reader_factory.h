// **************************************************************************
// File       [ cmd_basic_reader_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/18 ]
// **************************************************************************

#ifndef __COMMON_CMD_BASIC_READER_FACTORY_H__
#define __COMMON_CMD_BASIC_READER_FACTORY_H__

#include "cmd_basic_reader.h"
#include "cmd_reader_factory.h"

namespace CommonNs {

class CmdBasicReaderFactory : public CmdReaderFactory {
public:
    CmdBasicReaderFactory() {};
    ~CmdBasicReaderFactory() {};

    std::unique_ptr<CmdReader> create(CmdMgr* mgr) const override {
        return std::unique_ptr<CmdReader> (new CmdBasicReader(mgr));
    }
};

};

#endif


