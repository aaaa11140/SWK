// **************************************************************************
// File       [ cmd_mgr.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/05/18 created ]
// **************************************************************************

#ifndef __COMMON_CMD_MGR_H__
#define __COMMON_CMD_MGR_H__

#include <cctype>
#include <map>

#include "cmd.h"
#include "cmd_reader_factory.h"
#include "cmd_printer_factory.h"
#include "cmd_var_handler.h"
#include "cmd_redir_handler.h"

namespace CommonNs {

class CmdMgr {
public:
    typedef std::map<std::string, std::unique_ptr<Cmd> > CmdMap;
    typedef CmdMap::const_iterator CmdIter;

public:
    CmdMgr() : result_{Cmd::FAIL}, comment_{"//"} {};
    ~CmdMgr() {};

    // register commands
    bool regCmd(Cmd* cmd);
    Cmd* getCmd(const std::string& name) const;
    CmdIter cmdBegin() const { return cmds_.begin(); }
    CmdIter cmdEnd() const { return cmds_.end(); }

    // variable
    CmdVarHandler* cmdVarHandler() { return &cmdVarHandler_; };

    // command history
    size_t nCmdHis() const { return cmdHis_.size(); }
    const std::string& cmdHis(const size_t& i) const { return cmdHis_[i]; }

    // execution
    bool exec(const std::string& input);
    Cmd::Result result() const { return result_; }
    void comment(const std::string& comment) { comment_ = comment; }
    const std::string& comment() const { return comment_; }

    // parser and printer
    void createReader(CmdReaderFactory* fac);
    void createPrinter(CmdPrinterFactory* fac);
    CmdReader* reader() const { return reader_.get(); }
    CmdPrinter* printer() const { return printer_.get(); }

protected:
    // command information
    Cmd::Result              result_;
    std::string              comment_;
    CmdMap                   cmds_;
    CmdVarHandler            cmdVarHandler_;
    CmdRedirHandler          cmdRedirHandler_;
    std::vector<std::string> cmdHis_;
    std::vector<std::string> parse(const std::string& input);

    // reader and printer
    std::unique_ptr<CmdReader>  reader_;
    std::unique_ptr<CmdPrinter> printer_;
};

inline void CmdMgr::createReader(CmdReaderFactory* fac) {
    reader_ = fac->create(this);
}

inline void CmdMgr::createPrinter(CmdPrinterFactory* fac) {
    printer_ = fac->create(this);
}

};

#endif


