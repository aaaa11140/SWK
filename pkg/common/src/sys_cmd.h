// **************************************************************************
// File       [ sys_cmd.h ]
// Author     [ littleshamoo ]
// Synopsis   [ some system and misc commands ]
// Date       [ Ver. 2.0 started 2010/04/09 ]
// **************************************************************************

#ifndef __COMMON_SYS_CMD_H__
#define __COMMON_SYS_CMD_H__

#include "cmd_mgr.h"
#include "cmd.h"

namespace CommonNs {

class SysBashCmd : public Cmd {
public:
    SysBashCmd(const std::string& name);
    ~SysBashCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysListCmd : public Cmd {
public:
    SysListCmd(const std::string& name);
    ~SysListCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysCatCmd : public Cmd {
public:
    SysCatCmd(const std::string& name);
    ~SysCatCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysCdCmd : public Cmd {
public:
    SysCdCmd(const std::string& name);
    ~SysCdCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysPwdCmd : public Cmd {
public:
    SysPwdCmd(const std::string& name);
    ~SysPwdCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysExitCmd : public Cmd {
public:
    SysExitCmd(const std::string& name);
    ~SysExitCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);
};

class SysSetCmd : public Cmd {
public:
    SysSetCmd(const std::string& name, CmdMgr* mgr);
    ~SysSetCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);

private:
    CmdMgr *cmdmgr_;
};

class SysSourceCmd : public Cmd {
public:
    SysSourceCmd(const std::string& name, CmdMgr* mgr);
    ~SysSourceCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);

private:
    CmdMgr *cmdmgr_;
};

class SysHelpCmd : public Cmd {
public:
    SysHelpCmd(const std::string& name, CmdMgr* mgr);
    ~SysHelpCmd() {};

    Cmd::Result exec(const std::vector<std::string>& args);

private:
    CmdMgr *cmdmgr_;
};

};

#endif

