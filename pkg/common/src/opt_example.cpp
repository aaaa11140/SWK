// **************************************************************************
// File       [ opt_example.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ an option manager example binary ]
// History    [ Version 1.0 2014/01/01 ]
// **************************************************************************

#include <memory>
#include <iostream>

#include "opt_mgr.h"
#include "opt_basic_parser_factory.h"
#include "opt_basic_printer_factory.h"

using namespace std;
using namespace CommonNs;

void init(OptMgr& mgr);

int main(int argc, char **argv) {
    OptMgr mgr;

    init(mgr);

    if (!mgr.parser()->parse(argc, argv)) {
        cout << "**ERROR parsing error" << endl;
        exit(0);
    }

    if (mgr.parser()->getParsedOpt("h")) {
        mgr.printer()->print();
        exit(0);
    }

    // print parsed results
    for (size_t i = 0; i < mgr.parser()->nParsedArgs(); ++i)
        cout << "Arg `" << mgr.parser()->getParsedArg(i) << "'" << endl;

    for (size_t i = 0; i < mgr.nOpts(); ++i) {
        cout << "Opt `" << mgr.getOpt(i)->getFlag(0) << "' ";
        if (mgr.getOpt(i)->nFlags() > 0) {
            string flag = mgr.getOpt(i)->getFlag(0);
            if (mgr.parser()->getParsedOpt(flag)) {
                cout << "yes ";
                cout << "`" << mgr.parser()->getParsedValue(flag) << "'";
            }
            else
                cout << "no";
        }
        else
            cout << "no";
        cout << endl;
    }

    return 0;
}

void init(OptMgr& mgr) {
    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    mgr.createParser(parserFac.get());
    mgr.createPrinter(printerFac.get());

    mgr.name = "fan";
    mgr.brief = "A FAN algorithm based ATPG tool";
    string des = "fan takes an input verilog gate-level netlist and";
    des += " performs test generation or fault simulation. Currently";
    des += " supports stuck-at fault model and transition delay fault";
    des += " model. Additional functions include test relaxation and";
    des += " SAT-based test generation.";
    mgr.des = des;

    des = "Input circuit netlist.";
    mgr.regArg(Arg::REQ, des, "circuit_netlist");

    des = "Test mode selection ('a' for stuck-at fault, 's' for";
    des += " launch-off-shift transition fault and 'c' for";
    des += " launch-off-capture.)";
    mgr.regOpt(Opt::STRREQ, des, "<a|s|c>", "m,mode");

    des = "Enable random simulation and the random_limit specifies the";
    des += " iteration of simulation times.";
    mgr.regOpt(Opt::STRREQ, des, "random_limit", "r,random");

    des = "Limitation of dynamic compaction. It specifies the maximum";
    des += " number of failing times. Default = 300. If specified '-1' then";
    des += " dynamic compaciton will be turned off. The deterministic test";
    des += " genration will be disabled if '-2' is specified. Note that";
    des += " random simulation '-r' option should be turned on or this";
    des += " option will be ignored.";
    mgr.regOpt(Opt::STRREQ, des, "dynamic_fail_limit", "d");

    des = "Limitation of dynamic compaction. It specifies the maximum";
    des += " number of compaction fault in one pattern.";
    mgr.regOpt(Opt::STRREQ, des, "dynamic_fault_num", "D");

    des = "Backtrack limit of the FAN algorithm.";
    mgr.regOpt(Opt::STRREQ, des, "backtrack_limit", "b");

    des = "Output patterns to pattern_file.";
    mgr.regOpt(Opt::STRREQ, des, "pattern_file", "f");

    des = "Output undetected faults to undetected_file.";
    mgr.regOpt(Opt::STRREQ, des, "undetected_file", "u");

    des = "N-detect mode with n_num detection.";
    mgr.regOpt(Opt::STRREQ, des, "n_num", "N");

    des = "Enable MT-fill, an optional limit specifies the limit of fill";
    des += " ratio, range from 0.0 ~ 1.0.";
    mgr.regOpt(Opt::STRREQ, des, "mt_fill_num", "a");

    des = "Do not fill don't care bits during test generation.";
    mgr.regOpt(Opt::BOOL, des, "", "x");

    des = "Fault simulation for the sim_file. Note that if '-f' option is";
    des += " applied, the fault dictionary will be dumped.";
    mgr.regOpt(Opt::STRREQ, des, "sim_file", "y");

    des = "Perform test relaxation on patterns in relax_file.";
    mgr.regOpt(Opt::STRREQ, des, "relax_file", "X,relax-file");

    des = "At-speed delay test mode. Note that this only works for";
    des += " launch-off-capture transition fault test.";
    mgr.regOpt(Opt::BOOL, des, "", "i");

    des = "Enable SAT-based test pattern generation.";
    mgr.regOpt(Opt::BOOL, des, "", "s");

    des = "Mask PO or PPO in the mask_file. If it is not specified, all POs";
    des += " and PPOs will be masked.";
    mgr.regOpt(Opt::STROPT, des, "mask_file", "M");

    des = "Constraint PI or PPI value in the constraint_file.";
    mgr.regOpt(Opt::STRREQ, des, "constraint_file", "c");

    des = "Extract fault list from fault_list_file.";
    mgr.regOpt(Opt::STRREQ, des, "fault_list_file", "l");

    des = "Output a verilog test bench to vlog_test_file.";
    mgr.regOpt(Opt::STRREQ, des, "vlog_test_file", "v");

    des = "Print this usage.";
    mgr.regOpt(Opt::BOOL, des, "", "h,help");

}

