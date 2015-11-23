// **************************************************************************
// File       [ cmd_auto_completor.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/03/26 ]
// **************************************************************************

#ifndef __CMD_AUTO_COMPLETOR_H__
#define __CMD_AUTO_COMPLETOR_H__

#include "cmd_mgr.h"

namespace CommonNs {

class CmdAutoCompletor {

public:
    CmdAutoCompletor() : mgr_{nullptr}
        , nTokens_{0}
        , head_{""}
        , tail_{""}
        , prefix_{""}
        , isdelim_{false}
        , iscmd_{false}
        , isopt_{false}
        , isvar_{false}
        , isfile_{false} {};
    ~CmdAutoCompletor() {};

    std::vector<std::string> complete(CmdMgr* mgr
        , std::string& input
        , size_t& csrpos);

private:
    CmdMgr*     mgr_;

    // parsed results
    int         nTokens_;
    std::string head_;
    std::string tail_;
    std::string prefix_;
    bool        isdelim_;
    bool        iscmd_;
    bool        isopt_;
    bool        isvar_;
    bool        isfile_;

    void parse(const std::string& input, const size_t& csrpos);

    // find possible candidates
    std::vector<std::string> completeCmd();
    std::vector<std::string> completeOpt();
    std::vector<std::string> completeVar();
    std::vector<std::string> completeFile();

    size_t commonPos(const std::string& s1, const std::string& s2);

};

inline size_t CmdAutoCompletor::commonPos(const std::string& s1
    , const std::string& s2)
{
    size_t i = 0;
    for ( ; i < s1.size() && i < s2.size(); ++i)
        if (s1[i] != s2[i])
            return i;
    return i;
}


};

#endif


