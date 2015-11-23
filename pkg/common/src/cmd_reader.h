// **************************************************************************
// File       [ cmd_reader.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/06/27 created ]
// **************************************************************************

#ifndef __COMMON_CMD_READER_H__
#define __COMMON_CMD_READER_H__

#include <string>

namespace CommonNs {

class CmdMgr;
class CmdReader {
public:
    virtual ~CmdReader() {};

    virtual std::string read() = 0;

protected:
    CmdMgr* mgr_;
    CmdReader(CmdMgr* const mgr) : mgr_{mgr} {};
};

};

#endif


