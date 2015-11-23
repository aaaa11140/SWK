// **************************************************************************
// File       [ opt_mgr.h ]
// Author     [ littleshamoo ]
// Synopsis   [ parse options and arguments ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************


#ifndef __COMMON_OPT_MGR_H__
#define __COMMON_OPT_MGR_H__

#include <memory>

#include "opt.h"
#include "arg.h"
#include "opt_parser_factory.h"
#include "opt_printer_factory.h"

namespace CommonNs {

class OptMgr {
public:
    OptMgr() : name{""}
        , des{""}
        , brief{""}
        , parser_{nullptr}
        , printer_{nullptr} {};
    ~OptMgr() {};

    // program information
    std::string name;
    std::string des;
    std::string brief;

    // arguments
    bool regArg(const Arg::Type& type
        , const std::string& des
        , const std::string& meta
    );
    size_t nArgs() const { return args_.size(); }
    const Arg* const getArg(const size_t &i) { return &args_[i]; }

    // options
    bool regOpt(const Opt::Type& type
        , const std::string& des
        , const std::string& meta
        , const std::string& flags
    );
    size_t nOpts() const { return opts_.size(); }
    const Opt* const getOpt(const size_t &i) { return &opts_[i]; }

    // parser and printer
    void createParser(OptParserFactory* fac);
    void createPrinter(OptPrinterFactory* fac);
    OptParser* parser() const { return parser_.get(); }
    OptPrinter* printer() const { return printer_.get(); }

private:
    // registered information
    std::vector<Arg> args_;
    std::vector<Opt> opts_;

    // parser and printer
    std::unique_ptr<OptParser>  parser_;
    std::unique_ptr<OptPrinter> printer_;
};


// inline methods
inline bool OptMgr::regArg(const Arg::Type& type
    , const std::string& des
    , const std::string& meta
) {
    args_.push_back(std::move(Arg::create(this, type, des, meta)));
    return true;
}

inline bool OptMgr::regOpt(const Opt::Type& type
    , const std::string& des
    , const std::string& meta
    , const std::string& flags
) {
    Opt opt = Opt::create(this, type, des, meta, flags);
    // check flags
    for (size_t i = 0; i < opts_.size(); ++i)
        for (size_t j = 0; j < opts_[i].nFlags(); ++j)
            for (size_t k = 0; k < opt.nFlags(); ++k)
                if (opts_[i].getFlag(j) == opt.getFlag(k))
                    return false;
    opts_.push_back(std::move(opt));
    return true;
}

inline void OptMgr::createParser(OptParserFactory* fac) {
    parser_ = fac->create(this);
}

inline void OptMgr::createPrinter(OptPrinterFactory* fac) {
    printer_ = fac->create(this);
}

};

#endif

