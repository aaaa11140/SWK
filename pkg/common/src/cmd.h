// **************************************************************************
// File       [ cmd.h ]
// Author     [ littleshamoo ]
// Synopsis   [ header file for commands ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_CMD_H__
#define __COMMON_CMD_H__

#include <iostream>
#include <memory>

#include "opt_mgr.h"

namespace CommonNs {

class Cmd {
public:
    enum    Result { EXIT = -1, SUCCESS, FAIL };

    virtual ~Cmd() {};
    virtual Result exec(const std::vector<std::string>& args) = 0;

    OptMgr  optmgr;

protected:
    Cmd(const std::string& name) { optmgr.name = name; };
};

};

#endif


