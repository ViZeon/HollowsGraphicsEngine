#include "HotReload.hpp"
#include <iostream>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <cstring>

// === JSON: nlohmann/json.hpp ===
#include <nlohmann/json.hpp>
using json = nlohmann::json;

// === Cross-platform popen ===
#if defined(_WIN32)
    #define popen _popen
    #define pclose _pclose
#endif

namespace hotreload {

static std::string read_file(const std::string& path) {
    std::ifstream f(path);
    if (!f) return "";
    std::stringstream buf;
    buf << f.rdbuf();
    return buf.str();
}

// === JitSession ===
JitSession::JitSession() {
    const std::vector<std::string> candidates = {
        "clang-repl",
        "C:/Program Files/LLVM/bin/clang-repl.exe",
        "C:/Program Files (x86)/LLVM/bin/clang-repl.exe",
        "/usr/bin/clang-repl",
        "/usr/local/bin/clang-repl",
        "/opt/homebrew/bin/clang-repl",
        "/usr/local/opt/llvm/bin/clang-repl"
    };

    for (const auto& path : candidates) {
        if (file_exists(path)) {
            clang_repl_path = path;
            std::cout << "[HotReload] Using clang-repl: " << clang_repl_path << "\n";
            return;
        }
    }
    std::cout << "[HotReload] clang-repl not found — JIT disabled\n";
}

bool JitSession::file_exists(const std::string& path) const {
    struct stat buffer;
    return stat(path.c_str(), &buffer) == 0;
}

// === Get CMake compile flags ===
static std::string get_compile_flags(const std::string& src_path) {
    std::ifstream f("build/compile_commands.json");
    if (!f) {
        std::cout << "[JIT] compile_commands.json not found\n";
        return "";
    }

    json j;
    try {
        f >> j;
    } catch (...) {
        std::cout << "[JIT] Failed to parse JSON\n";
        return "";
    }

    for (const auto& entry : j) {
        std::string file = entry["file"].get<std::string>();
        if (file == src_path || file.ends_with(src_path)) {
            std::string cmd = entry["command"].get<std::string>();

            size_t clang_pos = cmd.find("clang++");
            if (clang_pos == std::string::npos) continue;

            size_t c_pos = cmd.find(" -c ");
            if (c_pos == std::string::npos) continue;

            size_t flags_start = clang_pos + 7;
            size_t flags_end = c_pos;

            return cmd.substr(flags_start, flags_end - flags_start);
        }
    }

    std::cout << "[JIT] No entry for: " << src_path << "\n";
    return "";
}

// === JIT with CMake flags ===
bool JitSession::execute(const std::string& code, const std::string& path) const {
    if (clang_repl_path.empty()) return false;

    std::string flags = get_compile_flags(path);
    if (flags.empty()) return false;

    std::string cmd = "clang++" + flags + " -x c++ - -c -o - | ";
    cmd += "\"" + clang_repl_path + "\" --jit";

    FILE* pipe = popen(cmd.c_str(), "w");
    if (!pipe) {
        std::cout << "[JIT] Failed to open pipe\n";
        return false;
    }

    fwrite(code.c_str(), 1, code.size(), pipe);
    fwrite("\n", 1, 1, pipe);
    fflush(pipe);

    int status = pclose(pipe);
#if !defined(_WIN32)
    if (WIFEXITED(status)) status = WEXITSTATUS(status);
#endif

    return status == 0;
}

// === Session ===
Session& Session::get() {
    static Session instance;
    return instance;
}

Session::~Session() = default;

void Session::reload_script(const std::string& path) {
    if (!m_session) return;

    auto code = read_file(path);
    if (code.empty()) {
        std::cout << "[HotReload] Failed to read: " << path << "\n";
        return;
    }

    std::string full_code = "#line 1 \"" + path + "\"\n" + code;
    if (m_session->execute(full_code, path)) {
        std::cout << "[JIT] Executed: " << path << "\n";
    } else {
        std::cout << "[JIT] Failed: " << path << "\n";
    }
}

void Session::watch_folder(const std::string& folder_path, Callback cb) {
    auto full_path = std::filesystem::absolute(folder_path).string();
    if (!std::filesystem::exists(full_path)) {
        std::filesystem::create_directories(full_path);
        std::cout << "[HotReload] Created folder: " << full_path << "\n";
    }

    if (!cb) {
        cb = [this](const std::string& p) { reload_script(p); };
    }

    auto it = std::find_if(m_watchers.begin(), m_watchers.end(),
        [&full_path](const auto& w) { return w && w->get_path() == full_path; });
    if (it != m_watchers.end()) {
        std::cout << "[HotReload] Already watching: " << full_path << "\n";
        return;
    }

    m_watchers.emplace_back(std::make_unique<FileWatcher>(full_path, std::move(cb)));
    std::cout << "[HotReload] Now watching: " << full_path << "\n";
}

// === FileWatcher ===
FileWatcher::FileWatcher(const std::string& path, Callback cb)
    : m_path(path), m_callback(std::move(cb)), m_watcher(new efsw::FileWatcher) {
    m_watch_id = m_watcher->addWatch(m_path, this, true);
    m_watcher->watch();
}

FileWatcher::~FileWatcher() {
    if (m_watcher) {
        m_watcher->removeWatch(m_watch_id);
        delete m_watcher;
    }
}

void FileWatcher::handleFileAction(efsw::WatchID, const std::string& dir,
                                   const std::string& filename, efsw::Action action,
                                   std::string) {
    if (action == efsw::Actions::Add || action == efsw::Actions::Modified) {
        if (filename.ends_with(".cpp") || filename.ends_with(".h")) {
            if (m_callback) m_callback(dir + filename);
        }
    }
}

// === AutoInit ===
AutoInit::AutoInit() {
    auto& s = Session::get();
    s.m_session.emplace();
    std::cout << "[HotReload] JIT ready (CMake-aware)\n";
}

} // namespace hotreload