// **************************************************************************
// File       [ main.cpp ]
// Author     [ littleshamoo, fxturtle ]
// Synopsis   [ GPU SWK main function ]
// Date       [ 2010/11/16 created ]
// **************************************************************************

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <memory>

#include "common/src/opt_mgr.h"

#include "interface/src/vlog_mod_builder.h"
#include "interface/src/mdt_mod_builder.h"
#include "common/src/opt_basic_parser_factory.h"
#include "common/src/opt_basic_printer_factory.h"

#include "circuit.h"
#include "circuit_builder.h"
#include "sdf_builder.h"
#include "timing_analyzer.h"
#include "memory_allocator.h"
#include "swk_gpu_atpg.h"
#include "SddCudaSim.h"
#include "ArgSim.h"


using namespace std;
using namespace CoreNs;
using namespace IntfNs;
//using namespace UtilNs;
using namespace CommonNs;

void init(OptMgr& mgr);
int main(int argc, char **argv) {
    OptMgr mgr;

    init(mgr);

    if (!mgr.parser()->parse(argc, argv)) {
        cout << "**ERROR parsing error" << endl;
        exit(0);
    }

    if (mgr.parser()->nParsedArgs() < 3) {
        cout << "**ERROR need netlist and MDT file" << endl;
        exit(0);
    }

    // parse netlist
    VlogModBuilder vlog;
    if (!vlog.read(mgr.parser()->getParsedArg(1).c_str(), false)) {
        cout << "**ERROR Verilog builder failed" << endl;
        exit(0);
    }
    cout << " [Correct] Verilog builder finished" << endl;

    // parse MDT
    MdtModBuilder mdt;
    if (!mdt.read(mgr.parser()->getParsedArg(2).c_str(), false)) {
        cout << "**ERROR MDT builder failed" << endl;
        exit(0);
    }
    cout << " [Correct] Mdt builder finished" << endl;

    // build design
    Design design;
    design.setModules(vlog.getModules());
    design.setModels(mdt.getModels());
    design.setPmts(mdt.getPmts());
    design.linkModules();
    design.buildOcc();
    cout << " [Correct] Design builder finished" << endl;

    // build circuit
    CircuitBuilder cirBuild;
    cirBuild.build(&design, 2);
    Circuit *cir = cirBuild.getCircuit();
    cout << " [Correct] Circuit builder finished" << endl;
	
	GateVec *test_ = cir->getGates();
	for( unsigned i=0;i<test_->size();i++ ){
		cout << (*test_)[i]->getId() << " " << (*test_)[i]->getLvl() << " " << (*test_)[i]->getType() << " " << endl;
		for( unsigned j=0;j<(*test_)[i]->nFis();j++ ){
			cout << (*test_)[i]->getFi(j)->getId() << " " ;
		}
		cout << endl;
		for( unsigned j=0;j<(*test_)[i]->nFos();j++ ){
			cout << (*test_)[i]->getFo(j)->getId() << " " ;
		}
		cout << endl;
		cout << "--------------------------------------------------------------------------------------------" << endl;
	}
	
	cout << "test good !" << endl;
	getchar();
    // read SDF if in timing-aware
    bool taMode = mgr.parser()->getParsedOpt("ta");
    if (taMode) {
        SdfBuilder sdfBuild(cir, SdfBuilder::WC);
        string sdfFileName = mgr.parser()->getParsedValue("ta");
        if (!sdfBuild.read(sdfFileName.c_str(), false)) {
            fprintf(stderr, " [Error] SDF builder failed\n");
            exit(0);
        }
        cout << " [Correct] SDF builder finished" << endl;
        class TimingAnalyzer* sta = new TimingAnalyzer{cir};
        sta->calculateArrivalTime();
        cout << " [Correct] Arrival time calculated" << endl;
    }

    // fault list extraction
    FaultColl fColl;
    fColl.setType(FaultColl::TDF);
    fColl.extract(cir);

    // GPU memory allocation
    size_t nBlocks  = 64;
    if (mgr.parser()->getParsedOpt("blocks"))
        nBlocks = (size_t)atoi(mgr.parser()->getParsedValue("blocks").c_str());

    size_t nThreads = 128;
    if (mgr.parser()->getParsedOpt("threads"))
        nThreads = (size_t)atoi(mgr.parser()->getParsedValue("threads").c_str());

    // memory allocator
    MemoryAllocator memAlloc(cir, taMode, nBlocks, nThreads);
    memAlloc.alloc(fColl.getFaults()->size());

    // set atpg options
    SwkGpuAtpg atpg(cir, &memAlloc);
    size_t nDetect = 8;
    if (mgr.parser()->getParsedOpt("N"))
        nDetect = (size_t)atoi(mgr.parser()->getParsedValue("N").c_str());
    size_t abLimit = 10;
    if (mgr.parser()->getParsedOpt("ablimit"))
        abLimit = (size_t)atoi(mgr.parser()->getParsedValue("ablimit").c_str());
    size_t bkLimit = 10;
    if (mgr.parser()->getParsedOpt("bklimit"))
        bkLimit = (size_t)atoi(mgr.parser()->getParsedValue("bklimit").c_str());
    atpg.nDetect_ = nDetect;
    atpg.abLimit_ = abLimit;
    atpg.bkLimit_ = bkLimit;
    atpg.nBlocks_ = nBlocks;
    atpg.nThreads_ = nThreads;

    PatternColl pColl;
    for(size_t i = 0; i < cir->nPis()+3; ++i){//+3 due to CK test_si test_se
        pColl.addPi(cir->getPi(i));
        string temp(cir->getModRoot()->getModTerm(i)->getName());
        pColl.addPiStr(temp);
    }
    for(size_t i = 0; i < cir->nPos(); ++i){
        pColl.addPo(cir->getPo(i));
        string temp(cir->getModRoot()->getModTerm(i+cir->nPis()+3)->getName());//+3 due to CK test_si test_se
        pColl.addPoStr(temp);
    }
    for(size_t i = 0; i < cir->nSeqs(); ++i){
        pColl.addScan(cir->getPpi(i));
        string temp(cir->getPpi(i)->getOcc()->getModInst()->getName());
        pColl.addScanStr(temp);
    }

    ArgSim* arg = new ArgSim();
    arg->delta = 1.0;
    arg->UFS_thNum = 32;
    arg->APD_bkNum = 64;
    arg->APD_thNum = 32;
    atpg.sddcudaSim = new SddCudaSim(&design, cir, &pColl, arg);

    // generate test patterns for all faults
    atpg.gen(&pColl, &fColl);
    if (mgr.parser()->getParsedOpt("pat")){
        ofstream FOUT(mgr.parser()->getParsedValue("pat"),ios::out);
        pColl.print(FOUT);
    }
    else{
        ofstream FOUT("temp.pat",ios::out);
        pColl.print(FOUT);
    }
}


void init(OptMgr& mgr) {
    unique_ptr<OptParserFactory> parserFac(new OptBasicParserFactory);
    unique_ptr<OptPrinterFactory> printerFac(new OptBasicPrinterFactory);
    mgr.createParser(parserFac.get());
    mgr.createPrinter(printerFac.get());

    mgr.name = "swk";
    mgr.brief = "A GPU-based ATPG tool based on SWK algorithm";
    string des = "SWK generates N-detect test patterns for transition delay";
    des += " faults. SWK requires netlist and technology file as inputs.";
    des += " If option '--ta' and standard delay file (SDF) are given, SWK";
    des += " generates timing-aware test patterns. If option '--get' ";
    des += " is given, SWK generates gate exhaustive transition test";
    des += " patterns. If both '--ta' and '--get' are given, SWK generates";
    des += " Timing-AwaRe Gate Exhaustive Transition (TARGET) test patterns.";
    mgr.des = des;

    des = "Input circuit netlist.";
    mgr.regArg(Arg::REQ, des, "circuit_netlist");

    des = "Input mdt technology file.";
    mgr.regArg(Arg::REQ, des, "mdt_file");

    des = "Backtrack limit.";
    mgr.regOpt(Opt::STRREQ, des, "backtrack_limit", "bklimit");

    des = "Dynamic compaction limit.";
    mgr.regOpt(Opt::STRREQ, des, "dynamic_compaction_limit", "ablimit");

    des = "N-detect.";
    mgr.regOpt(Opt::STRREQ, des, "n_det", "N");

    des = "Generate timing-aware test patterns.";
    mgr.regOpt(Opt::STRREQ, des, "sdf_file", "ta");

    des = "Generate gate exhaustive transition test patterns.";
    mgr.regOpt(Opt::BOOL, des, "", "get");

    des = "Number of blocks.";
    mgr.regOpt(Opt::STRREQ, des, "num_blocks", "blocks");

    des = "Number of threads.";
    mgr.regOpt(Opt::STRREQ, des, "num_threads", "threads");

    des = "Output pattern.";
    mgr.regOpt(Opt::STRREQ, des, "output_pattern", "pat");

    des = "Print this usage.";
    mgr.regOpt(Opt::BOOL, des, "", "h,help");

}

