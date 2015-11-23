// **************************************************************************
// File       [ arg.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_ARG_H__
#define __COMMON_ARG_H__

#include <string>

namespace CommonNs {

class OptMgr;

class Arg {  // class Argument
public:
    // Types: required, optional, required infinite, optional infinite
    enum Type { REQ = 0, OPT, REQINF, OPTINF };

    Arg(Arg&& arg);
    ~Arg();

    // access members
    Type type() const { return type_; };
    const std::string& des()  const { return des_; };
    const std::string& meta() const { return meta_; };

    // creation. Option manager is responsible for destruction
    static Arg create(OptMgr* mgr
        , const Type& type
        , const std::string& des
        , const std::string& meta
    );

private:
    Arg(OptMgr* mgr
        , const Type& type
        , const std::string& des
        , const std::string& meta
    );

    OptMgr*     mgr_;
    Type        type_;
    std::string des_;
    std::string meta_;
};

inline Arg::Arg(Arg&& arg)
    : mgr_   {std::move(arg.mgr_)}
    , type_  {std::move(arg.type_)}
    , des_   {std::move(arg.des_)}
    , meta_  {std::move(arg.meta_)} {}

inline Arg::~Arg() {}

inline Arg Arg::create(OptMgr* mgr
        , const Arg::Type& type
        , const std::string& des
        , const std::string& meta
) {
    return std::move(Arg{mgr, type, des, meta});
}

inline Arg::Arg(OptMgr* mgr
    , const Arg::Type& type
    , const std::string& des
    , const std::string& meta)
    : mgr_  {mgr}
    , type_ {type}
    , des_  {des}
    , meta_ {meta} {}

};

#endif

