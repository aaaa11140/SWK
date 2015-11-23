// **************************************************************************
// File       [ pat_test.cpp ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// Date       [ 2012/09/10 created ]
// **************************************************************************

#include <cstdlib>
#include <iostream>

#include "pat_file.h"

using namespace std;
//using namespace IntfNs;


int main(int argc, char **argv) {
    if (argc < 2) {
        cerr << "**ERROR main(): please provide pattern" << endl;
        exit(0);
    }

    PatFile *pat = new PatFile;
    if (!pat->read(argv[1], true)) {
        cerr << "**ERROR main(): pattern parse failed" << endl;
        exit(0);
    }

    delete pat;

    return 0;
}

