// **************************************************************************
// File       [ cmd_printer.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/06/30 created ]
// **************************************************************************

#ifndef __COMMON_CMD_PRINTER_H__
#define __COMMON_CMD_PRINTER_H__


namespace CommonNs {

class CmdMgr;
class CmdPrinter {
public:
    virtual ~CmdPrinter() {};

    virtual void print(std::ostream& out=std::cout) const = 0;

protected:
    CmdMgr* mgr_;
    CmdPrinter(CmdMgr* mgr) : mgr_{mgr} {};
};

};

#endif


