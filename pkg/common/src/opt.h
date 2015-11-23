// **************************************************************************
// File       [ opt.h ]
// Author     [ littleshamoo ]
// Synopsis   [ ]
// History    [ Version 2.0 2014/01/01 ]
// **************************************************************************

#ifndef __COMMON_OPT_H__
#define __COMMON_OPT_H__

#include <cstdlib> // for character checking
#include <string>
#include <vector>

namespace CommonNs {

class OptMgr;

class Opt {
public:
    enum Type { BOOL = 0, STRREQ, STROPT };

    Opt(Opt&& opt);
    ~Opt();

    // access members
    Type type() const { return type_; }
    const std::string& des() const { return des_; }
    const std::string& meta() const { return meta_; }
    size_t nFlags() const { return flags_.size(); }
    const std::string& getFlag(const size_t& i) const { return flags_[i]; }

    // creation. Option manager is responsible for destruction
    static Opt create(OptMgr* mgr
        , const Type& type
        , const std::string& des
        , const std::string& meta
        , const std::string& flags
    );

private:
    Opt(OptMgr* mgr
        , const Type& type
        , const std::string& des
        , const std::string& meta
        , const std::string& flags
    );

    // members
    OptMgr*                  mgr_;
    Type                     type_;
    std::string              des_;
    std::string              meta_;
    std::vector<std::string> flags_;

    // flag handling
    bool addFlags(const std::string& flags);
    bool isLegalFlagName(const std::string& flag);
    bool hasFlag(const std::string& flag);

};

inline Opt::Opt(Opt&& opt)
    : mgr_   {std::move(opt.mgr_)}
    , type_  {std::move(opt.type_)}
    , des_   {std::move(opt.des_)}
    , meta_  {std::move(opt.meta_)}
    , flags_ {std::move(opt.flags_)} {}

inline Opt::~Opt() {}

inline Opt Opt::create(OptMgr* mgr
        , const Opt::Type& type
        , const std::string& des
        , const std::string& meta
        , const std::string& flags
) {
    return std::move(Opt{mgr, type, des, meta, flags});
}

inline Opt::Opt(OptMgr* mgr
    , const Opt::Type& type
    , const std::string& des
    , const std::string& meta
    , const std::string& flags)
    : mgr_  {mgr}
    , type_ {type}
    , des_  {des}
    , meta_ {meta}
{
    addFlags(flags);
}

inline bool Opt::addFlags(const std::string& flags) {
    std::vector<std::string> legalFlags;

    // split flags into tokens seperated by comma or white space
    size_t begin = 0;
    size_t end = std::string::npos;
    do {
        end = flags.find_first_of(", ", begin);
        if (begin != end) {
            std::string flag = flags.substr(begin, end - begin);
            if (isLegalFlagName(flag) && !hasFlag(flag))
                legalFlags.push_back(flag);
            else
                return false;
        }
        begin = end + 1;
    } while (begin < flags.size() && end != std::string::npos);

    flags_.insert(flags_.end(), legalFlags.begin(), legalFlags.end());
    return true;
}

inline bool Opt::isLegalFlagName(const std::string& flag) {
    if (flag.size() == 0)
        return false;

    bool firstChar = true;
    for (auto iter = flag.begin(); iter != flag.end(); ++iter) {
        if (firstChar) {
            if (!isalpha(*iter))
                return false;
            firstChar = false;
        }
        else {
            if (!isalnum(*iter) && (*iter) != '_' && (*iter) != '-')
                return false;
        }
    }
    return true;
}

inline bool Opt::hasFlag(const std::string& flag) {
    for (auto iter = flags_.begin(); iter != flags_.end(); ++iter)
        if (*iter == flag)
            return true;
    return false;
}

};

#endif


