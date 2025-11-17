#pragma once

#include <string>
#include <functional>
#include <efsw/efsw.hpp>

/// Callback invoked when a file is added or modified
using Callback = std::function<void(const std::string& fullPath)>;

/**
 * @brief Watches a single directory (recursively) and calls a user callback
 *        when a file changes.
 */
class FileWatcher : public efsw::FileWatchListener
{
public:
    /**
     * @param path Directory to watch (recursive)
     * @param cb   Callback receiving the full path of the changed file
     */
    FileWatcher(const std::string& path, Callback cb);
    ~FileWatcher() override;

    /// Exact override of the base class virtual
    void handleFileAction(efsw::WatchID watchid,
                          const std::string& dir,
                          const std::string& filename,
                          efsw::Action action,
                          std::string oldFilename = "") override;

    /// Helper used by Session to avoid duplicate watches
    [[nodiscard]] const std::string& getPath() const noexcept { return m_path; }

private:
    std::string          m_path;     // watched directory
    Callback             m_callback;
    efsw::FileWatcher*   m_watcher = nullptr;
    efsw::WatchID        m_watchId = -1;
};