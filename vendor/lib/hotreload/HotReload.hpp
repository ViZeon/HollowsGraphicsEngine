#pragma once

#include <optional>
#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <filesystem>
#include <efsw/efsw.hpp>

#if defined(_WIN32)
    #include <windows.h>
    #include <io.h>
    #define stat _stat
    #include <cstdio>
#else
    #include <unistd.h>
    #include <sys/stat.h>
    #include <sys/wait.h>
#endif

namespace hotreload {

struct JitSession {
    std::string clang_repl_path;

    JitSession();
    bool execute(const std::string& code, const std::string& path) const;

private:
    bool file_exists(const std::string& path) const;
};

using Callback = std::function<void(const std::string& fullPath)>;

class FileWatcher;

class Session {
public:
    Session() = default;
    ~Session();

    void watch_folder(const std::string& folder_path, Callback cb = nullptr);
    void reload_script(const std::string& path);
    static Session& get();
    bool is_available() const { return static_cast<bool>(m_session); }

private:
    friend struct AutoInit;
    Session(const Session&) = delete;
    Session& operator=(const Session&) = delete;

    std::optional<JitSession> m_session;
    std::vector<std::unique_ptr<FileWatcher>> m_watchers;
};

class FileWatcher : public efsw::FileWatchListener {
public:
    FileWatcher(const std::string& path, Callback cb);
    ~FileWatcher() override;

    void handleFileAction(efsw::WatchID watchid,
                          const std::string& dir,
                          const std::string& filename,
                          efsw::Action action,
                          std::string oldFilename = "") override;

    [[nodiscard]] const std::string& get_path() const noexcept { return m_path; }

private:
    std::string m_path;
    Callback m_callback;
    efsw::FileWatcher* m_watcher = nullptr;
    efsw::WatchID m_watch_id = -1;
};

struct AutoInit {
    AutoInit();
};

inline const AutoInit& init() {
    static const AutoInit instance;
    return instance;
}

} // namespace hotreload