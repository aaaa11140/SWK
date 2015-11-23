// **************************************************************************
// File       [ cmd_example.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 1.0 2014/05/01 ]
// **************************************************************************

#include "cmd_mgr.h"
#include "cmd_basic_reader_factory.h"
#include "cmd_basic_printer_factory.h"
#include "sys_cmd.h"

using namespace std;
using namespace CommonNs;

int main(int argc, char **argv) {
    CmdMgr mgr;
    unique_ptr<CmdReaderFactory> readerFac(new CmdBasicReaderFactory);
    unique_ptr<CmdPrinterFactory> printerFac(new CmdBasicPrinterFactory);
    mgr.createReader(readerFac.get());
    mgr.createPrinter(printerFac.get());


    Cmd *bashCmd   = new SysBashCmd("bash");
    Cmd *listCmd   = new SysListCmd("ls");
    Cmd *cdCmd     = new SysCdCmd("cd");
    Cmd *catCmd    = new SysCatCmd("cat");
    Cmd *pwdCmd    = new SysPwdCmd("pwd");
    Cmd *exitCmd   = new SysExitCmd("exit");
    Cmd *quitCmd   = new SysExitCmd("quit");
    Cmd *setCmd    = new SysSetCmd("set", &mgr);
    Cmd *sourceCmd = new SysSourceCmd("source", &mgr);
    Cmd *helpCmd   = new SysHelpCmd("help", &mgr);
    mgr.regCmd(bashCmd);
    mgr.regCmd(listCmd);
    mgr.regCmd(cdCmd);
    mgr.regCmd(catCmd);
    mgr.regCmd(pwdCmd);
    mgr.regCmd(exitCmd);
    mgr.regCmd(quitCmd);
    mgr.regCmd(setCmd);
    mgr.regCmd(sourceCmd);
    mgr.regCmd(helpCmd);

    Cmd::Result res = Cmd::SUCCESS;
    while (res != Cmd::EXIT) {
        mgr.exec(mgr.reader()->read());
        res = mgr.result();
    }

    return 0;
}

