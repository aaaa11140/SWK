// **************************************************************************
// File       [ cmd_redir_handler.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/01 ]
// **************************************************************************

#ifndef __COMMON_CMD_REDIR_HANDLER_H__
#define __COMMON_CMD_REDIR_HANDLER_H__

#include <vector>
#include <string>

namespace CommonNs {

class CmdRedirHandler {
public:
    CmdRedirHandler() : fd_{0}, fpos_{0} {};
    ~CmdRedirHandler() {};

    bool redirect(std::vector<std::string>& args);
    void reset();

private:
    int    fd_;
    fpos_t fpos_;

    bool set(const std::string fname, const std::string mode);
};

};

#endif


