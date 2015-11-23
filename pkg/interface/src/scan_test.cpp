// **************************************************************************
// File       [ scan_test.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2011/12/22 created ]
// **************************************************************************


#include <cstdlib>
#include <iostream>

#include "scan_file.h"

using namespace std;
using namespace IntfNs;


int main(int argc, char **argv) {
    if (argc < 2) {
        cerr << "**ERROR main(): please provide scan file" << endl;
        exit(0);
    }

    ScanFile *scan = new ScanFile;
    if (!scan->read(argv[1], true)) {
        cerr << "**ERROR main(): scan parser failed" << endl;
        exit(0);
    }

    delete scan;

    return 0;
}

