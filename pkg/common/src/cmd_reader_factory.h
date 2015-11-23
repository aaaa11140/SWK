// **************************************************************************
// File       [ cmd_reader_factory.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/03/19 ]
// **************************************************************************

#ifndef __COMMON_CMD_READER_FACTORY_H__
#define __COMMON_CMD_READER_FACTORY_H__

#include <memory>

#include "cmd_reader.h"

namespace CommonNs {

class CmdMgr;
class CmdReaderFactory {
public:
    virtual ~CmdReaderFactory() {};

    virtual std::unique_ptr<CmdReader> create(CmdMgr* mgr) const = 0;

protected:
    CmdReaderFactory() {};
};

};

#endif


