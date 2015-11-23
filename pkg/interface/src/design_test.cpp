// **************************************************************************
// File       [ design_test.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/08/17 created ]
// **************************************************************************

#include <cstdlib>
#include <cstdio>
#include "vlog_mod_builder.h"
#include "mdt_mod_builder.h"
#include "design.h"
using namespace std;
using namespace IntfNs;

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("Usage: design_test <design> <tech lib>\n");
        exit(0);
    }

    VlogModBuilder vlog;
    if (!vlog.read(argv[1], true)) {
        fprintf(stderr, "**ERROR verilog builder failed\n");
        exit(0);
    }

    MdtModBuilder mdt;
    if (!mdt.read(argv[2], true)) {
        fprintf(stderr, "**ERROR verilog builder failed\n");
        exit(0);
    }

    Design design;
    design.setModules(vlog.getModules());
    design.setModels(mdt.getModels());
    design.setPmts(mdt.getPmts());
    design.linkModules();
    design.buildOcc();

    Module *module = design.getTop();
    printf("Top module: %s\n", module->getName());
    
    for (size_t i=0; i<module->nModInsts(); ++i) {
        ModInst *inst = module->getModInst(i);
        if (strncmp(inst->getModName(), "SDFF", 4))
            continue;
        printf("module: %s, inst: %s\n", inst->getModName(), inst->getName());
        for (size_t j=0; j<inst->nModInstTerms(); ++j) {
            ModInstTerm *term = inst->getModInstTerm(j);
            printf("  - instTerm: %s ", term->getName());
            if (term->getModNet())
                printf("-> %s\n", term->getModNet()->getName());
            else
                printf("\n");
        }
    }
    return 0;
}

