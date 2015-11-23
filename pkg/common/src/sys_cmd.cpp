// **************************************************************************
// File       [ sys_cmd.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ some system and misc commands ]
// Date       [ Ver. 2.0 started 2010/07/01 ]
// **************************************************************************

#include <unistd.h>
#include <string>
#include <cstdlib>
#include <fstream>

#include "sys_cmd.h"
#include "opt_basic_parser_factory.h"
#include "opt_basic_printer_factory.h"

using namespace std;
using namespace CommonNs;

//{{{ class SysBashCmd   method
SysBashCmd::SysBashCmd(const string& name) : Cmd{name} {
    optmgr.brief = "opens a new bash shell environment";
    optmgr.des = "opens a new bash shell environment";
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysBashCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    int res = system("bash --login");
    if (res != 0)
        return Cmd::FAIL;
    return Cmd::SUCCESS;
}
//}}}
//{{{ class SysListCmd   method
SysListCmd::SysListCmd(const string& name) : Cmd{name} {
    optmgr.brief = "list diectory contents";
    optmgr.des = "lists contents in DIRECTORY. If not specified, list current directory content.";
    optmgr.regArg(Arg::OPT, "target diectories", "DIRECTORY");
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysListCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    string input;
    for (size_t i = 0; i < args.size(); ++i)
        input += args[i] + " ";
    input += " --color=always -F 2> /dev/null";

    if (system(input.c_str()) != 0) {
        fprintf(stderr, "**ERROR SysListCmd::exec(): list failed\n");
        return Cmd::FAIL;
    }
    return Cmd::SUCCESS;
}
//}}}
//{{{ class SysCatCmd    method
SysCatCmd::SysCatCmd(const string& name) : Cmd{name} {
    optmgr.brief = "concatenate files and print on the standard output";
    optmgr.des = "Concatenate FILE(s), or standard input, to standard output";
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");
    optmgr.regArg(Arg::REQINF, "files to be printed", "FILE");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysCatCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    if (args.size() < 2) {
        fprintf(stderr, "**ERROR SysCatCmd::exec(): file needed\n");
        return Cmd::FAIL;
    }

    string input;
    for (size_t i = 0; i < args.size(); ++i)
        input += args[i] + " ";
    input += " 2> /dev/null";

    if (system(input.c_str()) != 0) {
        fprintf(stderr, "**ERROR SysCatCmd::exec(): cat files failed\n");
        return Cmd::FAIL;
    }
    return Cmd::SUCCESS;
}
//}}}
//{{{class SysCdCmd     method
SysCdCmd::SysCdCmd(const string& name) : Cmd{name} {
    optmgr.brief = "change directory";
    optmgr.des = "changes working directory to DIRECTORY. If not specified, changes to home directory.";
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");
    optmgr.regArg(Arg::OPT, "target directories", "DIRECTORY");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysCdCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    if (args.size() == 1) {
        char *home = getenv("HOME");
        if (chdir(home) != 0) {
            fprintf(stderr, "**ERROR SysCdCmd::exec(): ");
            fprintf(stderr, "cannot change to target directory\n");
            return Cmd::FAIL;
        }
        return Cmd::SUCCESS;
    }
    if (args.size() > 1) {
        if (chdir(args[1].c_str()) != 0) {
            fprintf(stderr, "**ERROR SysCdCmd::exec(): ");
            fprintf(stderr, "cannot change to target directory\n");
            return Cmd::FAIL;
        }
    }
    return Cmd::SUCCESS;
}
//}}}
//{{{ class SysPwdCmd    method
SysPwdCmd::SysPwdCmd(const string& name) : Cmd{name} {
    optmgr.brief = "print name of current directory";
    optmgr.des = "prints the full filename of the current working directory";
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysPwdCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    int res = system("pwd");
    if (res != 0)
        return Cmd::FAIL;
    return Cmd::SUCCESS;
}
//}}}
//{{{ class SysExitCmd   method
SysExitCmd::SysExitCmd(const string& name) : Cmd{name} {
    optmgr.brief = "exit the program";
    optmgr.des = "exits the program";
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysExitCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    return Cmd::EXIT;
}
//}}}
//{{{ class SysSetCmd    method
SysSetCmd::SysSetCmd(const string& name, CmdMgr *mgr) : Cmd{name}
    , cmdmgr_{mgr}
{
    optmgr.brief = "set variables";
    optmgr.des = "set VAR to VALUE";
    optmgr.regArg(Arg::OPT, "variable name", "VAR");
    optmgr.regArg(Arg::OPT, "value of the variable", "VALUE");
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());
}

Cmd::Result SysSetCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    CmdVarHandler* handler = cmdmgr_->cmdVarHandler();
    if (args.size() == 1) {
        for (auto it = handler->varBegin(); it != handler->varEnd(); ++it) {
            cout << cmdmgr_->comment() << "    ";
            cout << it->first          << " = ";
            cout << it->second         << endl;
        }
        return Cmd::SUCCESS;
    }

    if (args.size() < 3) {
        fprintf(stderr, "**ERROR SysSetCmd::exec(): ");
        fprintf(stderr, "variable and value needed\n");
        return Cmd::FAIL;
    }

    if (!handler->regVar(args[1], args[2])) {
        fprintf(stderr, "**ERROR SysSetCmd::exec(): set failed\n");
        return Cmd::FAIL;
    }

    return Cmd::SUCCESS;
}
//}}}
//{{{ class SysSourceCmd method
SysSourceCmd::SysSourceCmd(const string& name, CmdMgr *mgr) : Cmd{name}
    , cmdmgr_{mgr}
{
    optmgr.brief = "run commands from file";
    optmgr.des = "runs commands from FILE";
    optmgr.regArg(Arg::REQ, "target file with commands", "FILE");
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());

}

Cmd::Result SysSourceCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    if (args.size() < 2) {
        fprintf(stderr, "**ERROR SysSourceCmd::exec(): ");
        fprintf(stderr, "please specify source file\n");
        return Cmd::FAIL;
    }

    ifstream ifs;
    ifs.open(args[1], ifstream::in);
    if (!ifs.good()) {
        fprintf(stderr, "**ERROR SysSourceCmd::exec(): ");
        fprintf(stderr, "file cannot be opened\n");
        return Cmd::FAIL;
    }

    string expr;
    int count = 0;
    Cmd::Result res = Cmd::SUCCESS;
    while (ifs.good() && res != Cmd::EXIT) {
        getline(ifs, expr);
        count++;
        cout << args[1] << " " << count << "> " << expr << endl;
        if (!cmdmgr_->exec(expr))
            fprintf(stderr, "**ERROR command does not exist\n");
        res = cmdmgr_->result();
    }

    FILE *fin = fopen(args[1].c_str(), "r");
    if (!fin) {
        fprintf(stderr, "**ERROR SysSourceCmd::exec(): ");
        fprintf(stderr, "file cannot be opened\n");
        return Cmd::FAIL;
    }

    return res;
}
//}}}
//{{{ class SysHelpCmd   method
SysHelpCmd::SysHelpCmd(const string& name, CmdMgr *mgr) : Cmd(name) {
    optmgr.brief = "print help messages";
    optmgr.des = "prints help for COMMAND. If not specified, prints the usage of the command manager.";
    optmgr.regArg(Arg::OPT, "target command", "COMMAND");
    optmgr.regOpt(Opt::BOOL, "print usage", "", "h,help");

    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    optmgr.createParser(parserFac.get());
    optmgr.createPrinter(printerFac.get());

}

Cmd::Result SysHelpCmd::exec(const vector<string>& args) {
    optmgr.parser()->parse(args);
    if (optmgr.parser()->getParsedOpt("h")) {
        optmgr.printer()->print();
        return Cmd::SUCCESS;
    }

    if (args.size() == 1) {
        cmdmgr_->printer()->print();
        return Cmd::SUCCESS;
    }
    if (args.size() > 1) {
        Cmd *cmd = cmdmgr_->getCmd(args[1]);
        if (!cmd) {
            fprintf(stderr, "**ERROR SysHelpCmd::exec(): ");
            fprintf(stderr, "command does not exist\n");
            return Cmd::FAIL;
        }
        else
            cmd->optmgr.printer()->print();
    }
    return Cmd::SUCCESS;
}
//}}}


